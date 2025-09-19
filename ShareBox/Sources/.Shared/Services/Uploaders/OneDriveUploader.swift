//
//  OneDriveUploader.swift
//  ShareBox
//
//  Created by Thom van den Broek on 14/09/2025.
//

import SwiftUI

class OneDriveUploader: FileUploader {
    private let apiService = ApiService()
    private var activeProvider: CloudDrive?
    private var pendingFiles: [FilePath] = []
    private var accessToken: String?

    override func getId() -> UploaderId {
        .oneDrive
    }

    /// Check newly received metadata and check if that if all values are valid before continueing the file drop
    override func receivedMetadata(metadata: FileUploaderMetaData) -> Bool {
        if activeProvider != nil { return false }
        if let provider = User.shared?.drivesData.first(where: { $0.id == metadata.providerId && $0.provider == .ONEDRIVE }) {
            activeProvider = provider
            return true
        }
        return false
    }

    override func reset() {
        activeProvider = nil
        accessToken = nil
        super.reset()
    }

    /// Start processing the given batch with the drive's server
    override func processBatch(paths: [FilePath]) async {
        guard !paths.isEmpty else { return }

        // If drive is already authenticated → upload immediately
        if let token = accessToken {
            return await startUpload(paths, token: token)
        }

        // If access_token is being generated → stash the files
        if state == .preparingGroup {
            pendingFiles.append(contentsOf: paths)
            return
        }

        // Otherwise, create access_token first
        guard let token = try? await ensureToken() else {
            for path in paths {
                self.uploadProgress[path.absolute] = .init(status: .failed, uploadProgress: 100, errors: [.driveUnauthorized])
            }
            return
        }
        await startUpload(paths, token: token)
        // Also flush any files dropped while creating
        if !pendingFiles.isEmpty {
            let extra = pendingFiles
            pendingFiles.removeAll()
            await startUpload(extra, token: token)
        }
    }

    private func startUpload(_ paths: [FilePath], token: String) async {
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

        for file in onlyFiles {
            let details = file.details()
           if details.size <= 4 * 1024 * 1024 { // Files <= 5MB -> Simple multipart upload
               await self.uploadSimpleFile(file, token: token)
           } else {
               await self.uploadResumableFile(file, token: token)
           }
        }
    }

    private func uploadSimpleFile(_ path: FilePath, token: String) async {
        do {
            let fileData = try Data(contentsOf: URL(string: path.absolute)!)
            let fileDetails = path.details()
            let encodedName = fileDetails.fileName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? fileDetails.fileName

            var request = URLRequest(url: URL(string: "https://graph.microsoft.com/v1.0/me/drive/root:/\(encodedName):/content")!)
            request.httpMethod = "PUT"
            request.httpBody = fileData
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue(fileDetails.type, forHTTPHeaderField: "Content-Type")
            request.setValue("\(fileDetails.size)", forHTTPHeaderField: "Content-Length")

            self.uploadProgress[path.absolute] = .init(status: .uploading)

            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                self.uploadProgress[path.absolute] = .init(status: .completed, uploadProgress: 100)
            } else {
                #if DEBUG
                print("OneDrive simple upload error:", (response as? HTTPURLResponse)?.statusCode ?? -1,
                      String(data: data, encoding: .utf8) ?? "No data")
                #endif
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                let mapped = self.mapOneDriveError(data: data, status: status)
                self.uploadProgress[path.absolute] = .init(status: .failed, uploadProgress: 100, errors: [mapped])
            }
        } catch {
            self.uploadProgress[path.absolute] = .init(status: .failed, uploadProgress: 100, errors: [.unknown])
        }
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    private func uploadResumableFile(_ path: FilePath, token: String, chunkSize: Int = 10 * 1024 * 1024) async {
        do {
            let details = path.details()
            let encodedName = details.fileName.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? details.fileName

            // Create upload session
            var initReq = URLRequest(url: URL(string: "https://graph.microsoft.com/v1.0/me/drive/root:/\(encodedName):/createUploadSession")!)
            initReq.httpMethod = "POST"
            initReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            initReq.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
            let initBody: [String: Any] = [
                "item": [
                    "@microsoft.graph.conflictBehavior": "rename",
                    "name": details.fileName
                ]
            ]
            initReq.httpBody = try JSONSerialization.data(withJSONObject: initBody, options: [])

            let (initData, initResp) = try await URLSession.shared.data(for: initReq)
            guard let httpInit = initResp as? HTTPURLResponse, (200...299).contains(httpInit.statusCode) else {
                let mapped = self.mapOneDriveError(data: initData, status: (initResp as? HTTPURLResponse)?.statusCode ?? -1)
                self.uploadProgress[path.absolute] = .init(status: .failed, uploadProgress: 100, errors: [mapped])
                return
            }
            let session = try JSONDecoder().decode(OneDriveUploadSessionResponse.self, from: initData)
            guard let sessionURL = URL(string: session.uploadUrl) else {
                self.uploadProgress[path.absolute] = .init(status: .failed, uploadProgress: 100, errors: [.unknown])
                return
            }

            // Upload chunks
            self.uploadProgress[path.absolute] = .init(status: .uploading, uploadProgress: 0)
            guard let fileURL = URL(string: path.absolute) else {
                self.uploadProgress[path.absolute] = .init(status: .failed, uploadProgress: 100, errors: [.fileNotFound])
                return
            }
            let handle = try FileHandle(forReadingFrom: fileURL)
            defer { try? handle.close() }

            // Align to 320 KiB for Graph
            let align = 320 * 1024
            var offset = 0

            while offset < Int(details.size) {
                let bytesLeft = Int(details.size) - offset
                let maxChunk = min(chunkSize, bytesLeft)
                let length = (bytesLeft <= chunkSize) ? maxChunk : max((maxChunk / align) * align, align)
                if length <= 0 { break }

                try handle.seek(toOffset: UInt64(offset))
                let data = try handle.read(upToCount: length) ?? Data()
                if data.isEmpty {
                    self.uploadProgress[path.absolute] = .init(status: .completed, uploadProgress: 100)
                    break
                }

                let start = offset
                let end = offset + data.count - 1

                var putReq = URLRequest(url: sessionURL)
                putReq.httpMethod = "PUT"
                putReq.httpBody = data
                putReq.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
                putReq.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")
                putReq.setValue("bytes \(start)-\(end)/\(details.size)", forHTTPHeaderField: "Content-Range")

                do {
                    let (respData, putResp) = try await URLSession.shared.data(for: putReq)
                    guard let httpPut = putResp as? HTTPURLResponse else {
                        throw URLError(.badServerResponse)
                    }

                    if httpPut.statusCode == 202 {
                        // In-progress
                        if let chunkAck = try? JSONDecoder().decode(OneDriveChunkAcceptedResponse.self, from: respData),
                           let next = chunkAck.nextExpectedRanges?.first,
                           let nextStartStr = next.split(separator: "-").first,
                           let nextStart = Int(nextStartStr) {
                            offset = nextStart
                        } else {
                            offset = end + 1
                        }
                        let progress = Double(offset) / Double(details.size)
                        self.uploadProgress[path.absolute] = .init(status: .uploading, uploadProgress: progress * 100)
                    } else if (200...299).contains(httpPut.statusCode) {
                        // Completed (200/201)
                        self.uploadProgress[path.absolute] = .init(status: .completed, uploadProgress: 100)
                        break
                    } else {
                        #if DEBUG
                        print("OneDrive resumable chunk failed with status:", httpPut.statusCode,
                              String(data: respData, encoding: .utf8) ?? "No data")
                        #endif
                        let mapped = self.mapOneDriveError(data: respData, status: httpPut.statusCode)
                        if mapped == .fileToBig {
                            self.uploadProgress[path.absolute] = .init(status: .failed, uploadProgress: 100, errors: [mapped])
                            return
                        }
                        throw URLError(.badServerResponse)
                    }
                } catch {
                    // No offset recovery API here; fail and let user retry
                    throw error
                }
            }
        } catch {
            self.uploadProgress[path.absolute] = .init(status: .failed, uploadProgress: 100, errors: [.unknown])
        }
    }

    /// Make sure we always have a token created before continueing
    private func ensureToken() async throws -> String {
        self.state = .preparingGroup
        return try await withCheckedThrowingContinuation { continuation in
            createToken { result in
                switch result {
                case .success(let token):
                    self.accessToken = token
                    self.state = .uploading
                    continuation.resume(returning: token)
                case .failure(let error):
                    self.state = .error(error)
                    self.pendingFiles.removeAll()
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    /// Create a new access token with which the user can upload files
    private func createToken(completion: @escaping (Result<String, PlatformError>) -> Void) {
        Task {
            let startTime = DispatchTime.now()

            do {
                guard let provider = self.activeProvider else {
                    throw PlatformError.driveUnauthorized
                }
                let res: OneDriveSessionResponse = try await apiService.post(endpoint: "/api/drives/\(provider.id)/create-session")
                let accessToken = res.accessToken

                // Ensure minimum 2 seconds have elapsed (Better for UI)
                let elapsedTime = DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds
                let elapsedSeconds = Double(elapsedTime) / 1_000_000_000
                let remainingTime = max(0, 2.0 - elapsedSeconds)

                if remainingTime > 0 {
                    try await Task.sleep(for: .seconds(remainingTime))
                }

                completion(.success(accessToken))
            } catch {
                // Ensure minimum 2 seconds have elapsed even for errors (Better for UI)
                let elapsedTime = DispatchTime.now().uptimeNanoseconds - startTime.uptimeNanoseconds
                let elapsedSeconds = Double(elapsedTime) / 1_000_000_000
                let remainingTime = max(0, 2.0 - elapsedSeconds)

                if remainingTime > 0 {
                    try? await Task.sleep(for: .seconds(remainingTime))
                }

                if case let APIError.serverError(status, _) = error, status == 400 {
                    do {
                        if let provider = self.activeProvider {
                            let res: ApiService.BasicRedirectResponse = try await self.apiService.post(endpoint: "/api/drives/\(provider.id)/reconnect", parameters: [
                                "type": "ONEDRIVE"
                            ])
                            NSWorkspace.shared.open(URL(string: res.redirectUrl)!)
                        }
                    } catch {}
                    completion(.failure(.driveUnauthorized))
                } else {
                    completion(.failure(.unknown))
                }
            }
        }
    }

    private func mapOneDriveError(data: Data, status: Int) -> PlatformError {
        if let decoded = try? JSONDecoder().decode(GraphAPIError.self, from: data) {
            if decoded.error.code == "quotaLimitReached" {
                return .fileToBig
            }
        }
        if status == 507 || status == 413 { return .fileToBig } // Insufficient Storage / Payload Too Large
        return .unknown
    }
}

private struct OneDriveSessionResponse: Codable {
    var accessToken: String
}

private struct GraphAPIError: Codable {
    struct ErrorObj: Codable { var code: String?; var message: String? }
    var error: ErrorObj
}

private struct OneDriveUploadSessionResponse: Codable {
    var uploadUrl: String
}

private struct OneDriveChunkAcceptedResponse: Codable {
    var nextExpectedRanges: [String]?
}
