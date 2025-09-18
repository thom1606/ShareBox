//
//  ShareBoxUploader.swift
//  ShareBox
//
//  Created by Thom van den Broek on 06/09/2025.
//

import SwiftUI

// swiftlint:disable:next type_body_length
class ShareBoxUploader: FileUploader {
    private(set) var groupDetails: BoxDetails?
    private let apiService = ApiService()
    private var pendingFiles: [FilePath] = []

    override func getId() -> UploaderId {
        .sharebox
    }

    override func complete() {
        // Only show notification + group clipboard if there are actually succesfully uploaded files
        if self.uploadProgress.values.contains(where: { $0.status == .completed }) {
            guard let groupUrlString = self.groupDetails?.url else {
                return
            }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(String(localized: "Hey! I want to share some files with you. You can download them from my ShareBox: \(groupUrlString)", comment: "Clipboard message"), forType: .string)

            Utilities.showNotification(title: String(localized: "Link Copied!"), body: String(localized: "The ShareBox link is copied to your clipboard!"))
        }
    }

    override func reset() {
        groupDetails = nil
        super.reset()
    }

    override func processBatch(paths: [FilePath]) async {
        // If group is already created → upload immediately
        if let group = groupDetails {
            return await startUpload(paths, in: group)
        }

        // If group is being created → stash the files
        if state == .preparingGroup {
            pendingFiles.append(contentsOf: paths)
            return
        }

        // Otherwise, create group first
        guard let group = try? await ensureGroup() else {
            for path in paths {
                self.uploadProgress[path.absolute] = .init(status: .failed, uploadProgress: 100, errors: [.groupNotFound])
            }
            return
        }
        await startUpload(paths, in: group)
        // Also flush any files dropped while creating
        if !pendingFiles.isEmpty {
            let extra = pendingFiles
            pendingFiles.removeAll()
            await startUpload(extra, in: group)
        }
    }

    // MARK: - Private Methods
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func startUpload(_ paths: [FilePath], in group: BoxDetails) async {
        self.state = .uploading
        // Get all files which are hidden inside folders
        let onlyFiles = self.getFilesFromPaths(paths: paths)

        // Notarize each file to the upload progress
        for file in onlyFiles {
            self.uploadProgress[file.absolute] = .init(status: .notarized)
        }

        // for paths where no file could be found in, that folder is presumed to be empty, and won't be handled further
        paths.forEach { path in
            if !onlyFiles.contains(where: { $0.absolute.hasPrefix(path.absolute) }) {
                self.uploadProgress[path.absolute] = .init(status: .failed, uploadProgress: 100, errors: [.fileNotFound])
            }
        }
        do {
            let addFilesResponse: AddFilesResponse = try await self.apiService.post(endpoint: "/api/groups/\(group.groupId)/files/add", parameters: [
                "files": onlyFiles.map { item in
                    let details = item.details()
                    return [
                        "path": details.paths.relative,
                        "type": details.type,
                        "size": details.size
                    ]
                }
            ])

            // For the files which were registered correctly, we will start uploading those
            for key in addFilesResponse.files.keys {
                guard let currentFile = onlyFiles.first(where: { $0.relative == key }) else {
                    dataLogger.error("Created S3 url for file \"\(key)\" but it doesn't exist locally.")
                    continue
                }
                let item = addFilesResponse.files[key]!

                let shouldPutOnS3String: String = (Bundle.main.object(forInfoDictionaryKey: "UPLOAD_S3") as? String ?? "true")
                if let shouldPutOnS3 = Bool(shouldPutOnS3String), !shouldPutOnS3 {
                    await self.simulateFile(currentFile, in: group, item: item)
                    continue
                }

                if item.type == "multipart" {
                    await self.uploadMultiPartFile(currentFile, in: group, item: item)
                } else {
                    await self.uploadSinglePartFile(currentFile, in: group, item: item)
                }
            }
        } catch {
            dataLogger.error("Registering file batch failed: \(error.localizedDescription)")
            // Since the whole batch failed, we error on all the files in this batch at once
            var foundError: PlatformError = .unknown
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
                case "GROUP_NOT_FOUND":
                    foundError = .groupNotFound
                default:
                    break
                }
            }
            for file in onlyFiles {
                self.uploadProgress[file.absolute] = .init(status: .failed, uploadProgress: 100, errors: [foundError])
            }
        }
    }

    /// For single part uploads (less than 5GB)
    private func uploadSinglePartFile(_ path: FilePath, in group: BoxDetails, item: AddFilesResponse.Item, tryCount: Int = 0) async {
        do {
            let fileData = try Data(contentsOf: URL(string: path.absolute)!)
            let fileDetails = path.details()

            // Create the request for the file upload
            var request = URLRequest(url: URL(string: item.urls[0])!)
            request.httpMethod = "PUT"
            // Set Content-Type header to the file's MIME type
            request.setValue(fileDetails.type, forHTTPHeaderField: "Content-Type")
            // Set Content-Length header
            request.setValue("\(fileDetails.size)", forHTTPHeaderField: "Content-Length")

            // Start updating the progress
            self.uploadProgress[path.absolute] = .init(status: .uploading)

            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                let uploadTask = URLSession.shared.uploadTask(with: request, from: fileData) { [updateProgress, handleComplete, uploadSinglePartFile] _, response, error in
                    Task {
                        if let error = error {
                            dataLogger.error("Upload failed with some internal error: \(error.localizedDescription)")
                            if tryCount < 3 {
                                try? await Task.sleep(for: .seconds(1))
                                await uploadSinglePartFile(path, group, item, tryCount + 1)
                            } else {
                                try? await Task.sleep(for: .seconds(1))
                                await updateProgress(path, .init(status: .failed, uploadProgress: 100, errors: [.s3Failed]))
                            }
                        } else if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                            dataLogger.error("Upload failed, got an invalid status code back from S3: \(httpResponse.statusCode)")
                            if tryCount < 3 {
                                try? await Task.sleep(for: .seconds(1))
                                await uploadSinglePartFile(path, group, item, tryCount + 1)
                            } else {
                                try? await Task.sleep(for: .seconds(1))
                                await updateProgress(path, .init(status: .failed, uploadProgress: 100, errors: [.s3Failed]))
                            }
                        } else {
                            // Complete the upload
                            await handleComplete(group, .init(id: item.id, path: path))
                        }
                        continuation.resume()
                    }
                }
                progressCancellables[path.absolute]?.cancel()
                progressCancellables[path.absolute] = nil
                progressCancellables[path.absolute] = uploadTask.progress.publisher(for: \.fractionCompleted)
                    .receive(on: DispatchQueue.main).sink { [updateProgress] fraction in
                        Task {
                            await updateProgress(path, .init(status: .uploading, uploadProgress: fraction * 100))
                        }
                    }
                uploadTask.resume()
            }
        } catch {
            self.uploadProgress[path.absolute] = .init(status: .failed, uploadProgress: 100, errors: [.s3Failed])
        }
    }

    /// For multi part file uploads (bigger than 5GB)
    private func uploadMultiPartFile(_ path: FilePath, in group: BoxDetails, item: AddFilesResponse.Item) async {
        do {
            guard let partSize = item.partSize else {
                throw PlatformError.fileSizeZero
            }

            let fileDetails = path.details()
            guard let fileURL = URL(string: path.absolute) else {
                self.uploadProgress[path.absolute] = .init(status: .failed, uploadProgress: 100, errors: [.fileNotFound])
                return
            }
            let handle = try FileHandle(forReadingFrom: fileURL)
            defer { try? handle.close() }

            var etags: [String] = []
            for (index, urlString) in item.urls.enumerated() {
                guard let url = URL(string: urlString) else { continue }
                let offset = index * partSize
                let length = min(partSize, Int(fileDetails.size) - offset)
                if length <= 0 { break }

                try handle.seek(toOffset: UInt64(offset))
                let data = try handle.read(upToCount: length) ?? Data()

                var request = URLRequest(url: url)
                request.httpMethod = "PUT"
                request.httpBody = data

                // Give each part 3 tries to upload, otherwise the whole upload fails
                var tries = 0
                var newETag: String?
                while newETag == nil && tries < 3 {
                    do {
                        newETag = try await self.uploadPart(request: request)
                    } catch {
                        tries += 1
                    }
                }
                if newETag == nil {
                    throw URLError(.badServerResponse)
                }
                etags.append(newETag!)

                // Update the progress for the file
                let progress = Double(offset + length) / Double(fileDetails.size)
                self.uploadProgress[path.absolute] = .init(status: .uploading, uploadProgress: progress * 100)
            }

            // Complete the upload
            await self.handleComplete(in: group, item: .init(id: item.id, uploadId: item.uploadId, etags: etags, path: path))
        } catch {
            // Upload failed, show error on item
            generalLogger.error("Failed to upload multipart file: \(error.localizedDescription)")
            self.uploadProgress[path.absolute] = .init(status: .failed, uploadProgress: 100, errors: [.s3Failed])
        }
    }

    /// Simulate a file upload  with firing some uploading states with time intervals
    private func simulateFile(_ path: FilePath, in group: BoxDetails, item: AddFilesResponse.Item) async {
        dataLogger.debug("Skipping upload to S3 as it is disabled by environment, simulating it instead...")
        self.uploadProgress[path.absolute] = .init(status: .uploading, uploadProgress: 10)
        try? await Task.sleep(for: .seconds(3))
        self.uploadProgress[path.absolute] = .init(status: .uploading, uploadProgress: 50)
        try? await Task.sleep(for: .seconds(3))
        self.uploadProgress[path.absolute] = .init(status: .uploading, uploadProgress: 100)
        try? await Task.sleep(for: .seconds(1))
        // Mark the file as completed
        await self.handleComplete(in: group, item: .init(id: item.id, uploadId: item.uploadId, etags: ["\"dummy\""], path: path))
    }

    /// Mark the item as complete
    private func handleComplete(in group: BoxDetails, item: CompleteItem) async {
        _ = try? await apiService.post(endpoint: "/api/groups/\(group.groupId)/files/complete", parameters: [
            "id": item.id,
            "uploadId": item.uploadId,
            "etags": item.etags
        ]) as ApiService.BasicSuccessResponse
        await updateProgress(path: item.path, progress: .init(status: .completed, uploadProgress: 100))
    }

    /// Submit a request and read possible Etags
    private func uploadPart(request: URLRequest) async throws -> String {
        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200,
              let etag = httpResponse.allHeaderFields["Etag"] as? String else {
            throw URLError(.badServerResponse)
        }
        return etag
    }

    private func updateProgress(path: FilePath, progress: FilePathProgress) async {
        await MainActor.run {
            if let item = uploadProgress[path.absolute], item.status != .completed && item.status != .failed {
                uploadProgress[path.absolute] = progress
            }
        }
    }

    /// Wait for a group to be created, otherwise fail
    private func ensureGroup() async throws -> BoxDetails {
        self.state = .preparingGroup
        return try await withCheckedThrowingContinuation { continuation in
            createGroup { result in
                switch result {
                case .success(let details):
                    self.groupDetails = details
                    self.state = .uploading
                    continuation.resume(returning: details)
                case .failure(let error):
                    self.state = .error(error)
                    self.pendingFiles.removeAll()
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Create a new group if possible
    private func createGroup(completion: @escaping (Result<BoxDetails, PlatformError>) -> Void) {
        Task {
            let startTime = DispatchTime.now()

            do {
                let createdGroupResponse: BoxDetails = try await apiService.post(endpoint: "/api/groups")

                // Ensure minimum 2 seconds have elapsed (Better for UI)
                let elapsedTime = DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds
                let elapsedSeconds = Double(elapsedTime) / 1_000_000_000
                let remainingTime = max(0, 2.0 - elapsedSeconds)

                if remainingTime > 0 {
                    try await Task.sleep(for: .seconds(remainingTime))
                }

                completion(.success(createdGroupResponse))
            } catch {
                // Ensure minimum 2 seconds have elapsed even for errors (Better for UI)
                let elapsedTime = DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds
                let elapsedSeconds = Double(elapsedTime) / 1_000_000_000
                let remainingTime = max(0, 2.0 - elapsedSeconds)

                if remainingTime > 0 {
                    try? await Task.sleep(for: .seconds(remainingTime))
                }

                if let apiError = error as? APIError, case .unauthorized = apiError {
                    completion(.failure(.unauthorized))
                } else if let error = error as? APIError, case .serverError(_, let errorResponse) = error {
                    if errorResponse.error == "GROUP_LIMIT_REACHED" {
                        completion(.failure(.groupLimitReached))
                    } else if errorResponse.error == "SUBSCRIPTION_NOT_FOUND" {
                        completion(.failure(.noSubscription))
                    } else {
                        completion(.failure(.unknown))
                    }
                } else {
                    completion(.failure(.unknown))
                }
            }
        }
    }
}

private struct AddFilesResponse: Codable {
    var files: [String: Item]
    var failed: [String: String]

    struct Item: Codable {
        var urls: [String]
        var id: String
        var partSize: Int?
        var uploadId: String?
        var type: String
    }
}

private struct CompleteItem: Codable {
    var id: String
    var uploadId: String?
    var etags: [String]?
    var path: FilePath
}
