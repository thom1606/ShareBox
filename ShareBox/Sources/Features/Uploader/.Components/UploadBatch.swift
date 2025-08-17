//
//  UploadBatch.swift
//  ShareBox
//
//  Created by Thom van den Broek on 15/08/2025.
//

import Foundation
import Combine

class UploadBatch {
    private var groupId: String
    private var paths: [FilePath]
    private var progressCancellables: [String: AnyCancellable] = [:]
    private var onProgress: (String, FilePathProgress) -> Void

    let apiService = ApiService()

    init(groupId: String, paths: [FilePath], onProgress: @escaping (String, FilePathProgress) -> Void) {
        self.groupId = groupId
        self.paths = paths
        self.onProgress = onProgress
    }

    deinit {
        progressCancellables.values.forEach { $0.cancel() }
    }

    /// Start the upload of this batch to the correct bucket
    public func start() async {
        let finalPaths = self.createFinalPathList()

        // Make sure all files / folders are mapped, if not, no files could be found within folders
        updateEmptyFolders(finalPaths)

        do {
            // With all the actual files mapped out, we will start registering all the files
            let addFilesResponse = try await registerBatch(finalPaths)

            // For the files which were registered correctly, we will start uploading those
            for key in addFilesResponse.files.keys {
                guard let currentFile = finalPaths.first(where: { $0.relative == key }) else {
                    dataLogger.error("Created S3 url for file \"\(key)\" but it doesn't exist locally.")
                    continue
                }
                await self.uploadFile(currentFile, urlString: addFilesResponse.files[key]!)
            }

            // For the files failed to register, we will show an error
            handleFailedFiles(finalPaths, response: addFilesResponse)
        } catch {
            dataLogger.error("Registering file batch failed: \(error.localizedDescription)")
            // Since the whole batch failed, we error on all the files in this batch at once
            var foundError: FileError = .unknown
            if let apiError = error as? APIError, case .unauthorized = apiError {
                foundError = .unauthorized
            } else if let error = error as? APIError, case .serverError(_, let errorResponse) = error {
                switch errorResponse.error {
                case "NO_FILES":
                    foundError = .fileNotFound
                case "FILES_SIZE_TOO_LARGE":
                    foundError = .limitReached
                case "SUBSCRIPTION_NOT_FOUND":
                    foundError = .noSubscription
                default:
                    break
                }
            }
            for path in finalPaths {
                self.onProgress(path.absolute, .init(
                    status: .failed,
                    uploadProgress: 100,
                    errors: [foundError]
                ))
            }
        }
    }

    private func createFinalPathList() -> [FilePath] {
        var result: [FilePath] = []
        paths.forEach {
            let itemURL = URL(filePath: $0.absolute.replacingOccurrences(of: "file://", with: ""))
            if itemURL.hasDirectoryPath {
                let parentURL = itemURL.deletingLastPathComponent()
                let basePath = parentURL.path
                // For all folders, it should go in and fetch all those children until there are no folders left
                let files = self.getFilesInFolder(
                    basePath: "file://\(basePath)/",
                    url: itemURL
                )
                result.append(contentsOf: files)
            } else {
                result.append($0)
            }
        }
        return result
    }

    private func registerBatch(_ finalPaths: [FilePath]) async throws -> AddFilesResponse {
        return try await self.apiService.post(endpoint: "/api/groups/files/add", parameters: [
            "groupId": self.groupId,
            "files": finalPaths.map { item in
                let details = item.details()
                return [
                    "path": details.paths.relative,
                    "type": details.type,
                    "size": details.size
                ]
            }
        ])
    }

    private func updateEmptyFolders(_ finalPaths: [FilePath]) {
        paths.forEach { path in
            if !finalPaths.contains(where: { $0.absolute.hasPrefix(path.absolute) }) {
                self.onProgress(path.absolute, .init(status: .failed, uploadProgress: 100, errors: [.fileNotFound]))
            }
        }
    }

    private func handleFailedFiles(_ finalPaths: [FilePath], response: AddFilesResponse) {
        for key in response.failed.keys {
            guard let currentFile = finalPaths.first(where: { $0.relative == key }) else {
                dataLogger.error("Tried to log the failed file \"\(key)\" but it doesn't exist locally.")
                continue
            }
            var foundError: FileError = .unknown
            let errorMessage = response.failed[key]!

            switch errorMessage {
            case "FILE_SIZE_ZERO":
                foundError = .fileSizeZero
            case "FILE_SIZE_TOO_LARGE":
                foundError = .fileToBig
            case "NO_PRESIGNED_URL":
                foundError = .noUrlProvided
            default:
                break
            }
            self.onProgress(currentFile.absolute, .init(
                status: .failed,
                uploadProgress: 100,
                errors: [foundError]
            ))
        }
    }

    @MainActor
    private func uploadFile(_ path: FilePath, urlString: String) async {
        let shouldPutOnS3String: String = (Bundle.main.object(forInfoDictionaryKey: "UPLOAD_S3") as? String ?? "true")
        if let shouldPutOnS3 = Bool(shouldPutOnS3String), !shouldPutOnS3 {
            dataLogger.debug("Skipping upload to S3 as it is disabled by environment, simulating it instead...")
            self.onProgress(path.absolute, .init(status: .uploading, uploadProgress: 10))
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                self.onProgress(path.absolute, .init(status: .uploading, uploadProgress: 50))
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    self.onProgress(path.absolute, .init(status: .uploading, uploadProgress: 100))
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                        self.onProgress(path.absolute, .init(status: .completed, uploadProgress: 100))
                    }
                }
            }
            return
        }

        do {
            let fileData = try Data(contentsOf: URL(string: path.absolute)!)
            let fileDetails = path.details()
            // Create the request for the file upload
            var request = URLRequest(url: URL(string: urlString)!)
            request.httpMethod = "PUT"
            // Set Content-Type header to the file's MIME type
            request.setValue(fileDetails.type, forHTTPHeaderField: "Content-Type")
            // Set Content-Length header
            request.setValue("\(fileDetails.size)", forHTTPHeaderField: "Content-Length")

            // Start updating the progress
            onProgress(path.absolute, .init(status: .uploading))

            let uploadTask = URLSession.shared.uploadTask(with: request, from: fileData) { [onProgress] _, response, error in
                Task { @MainActor in
                    if let error = error {
                        dataLogger.error("Upload failed with some internal error: \(error.localizedDescription)")
                        onProgress(path.absolute, .init(status: .failed, uploadProgress: 100, errors: [.s3Failed]))
                    } else if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                        dataLogger.error("Upload failed, got an invalid status code back from S3: \(httpResponse.statusCode)")
                        onProgress(path.absolute, .init(status: .failed, uploadProgress: 100, errors: [.s3Failed]))
                    } else {
                        // Everything should have gone to plan and the file should have been uploaded
                        onProgress(path.absolute, .init(status: .completed, uploadProgress: 100))
                    }
                }
            }
            progressCancellables[path.absolute] = uploadTask.progress.publisher(for: \.fractionCompleted)
                .receive(on: DispatchQueue.main).sink { [onProgress] fraction in
                    DispatchQueue.main.async {
                        onProgress(path.absolute, .init(status: .uploading, uploadProgress: fraction * 100))
                    }
                }
            uploadTask.resume()
        } catch {
            onProgress(path.absolute, .init(status: .failed, uploadProgress: 100, errors: [.s3Failed]))
        }
    }

    /// Get files within the given folder path and convert them to FilePath's
    private func getFilesInFolder(basePath: String, url: URL) -> [FilePath] {
        var files: [FilePath] = []
        let fileManager = FileManager.default
        var options: FileManager.DirectoryEnumerationOptions = []
        if !userDefaults.bool(forKey: Constants.Settings.hiddenFilesPrefKey) {
            options = [.skipsHiddenFiles]
        }
        let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: options)
        for content in contents ?? [] {
            if content.hasDirectoryPath {
                let childFiles = getFilesInFolder(basePath: basePath, url: content)
                files.append(contentsOf: childFiles)
            } else {
                files.append(.init(
                    relative: content.absoluteString.replacingOccurrences(of: basePath, with: ""),
                    absolute: content.absoluteString,
                    isFolder: false
                ))
            }
        }
        return files
    }

    /// Create a new group based on the users preference
    public static func createGroup(completion: @escaping (Result<BoxDetails, Error>) -> Void) async {
        let apiService = ApiService()

        // Start creating the group
        do {
            let password = userDefaults.string(forKey: Constants.Settings.passwordPrefKey)
            let storageDuration = userDefaults.string(forKey: Constants.Settings.storagePrefKey) ?? "3_days"

            let createdGroupResponse: BoxDetails = try await apiService.post(endpoint: "/api/groups", parameters: [
                "password": password,
                "expires_in": storageDuration
            ])
            completion(.success(createdGroupResponse))
        } catch {
            completion(.failure(error))
        }
    }
}

struct FilePathProgress {
    var status: Status
    var uploadProgress: CGFloat = 0
    var errors: [FileError] = []

    enum Status {
        case unknown
        case notarized
        case failed
        case completed
        case uploading
    }
}

struct BoxDetails: Codable {
    var groupId: String
    var url: String
}

private struct AddFilesResponse: Codable {
    var files: [String: String]
    var failed: [String: String]
}
