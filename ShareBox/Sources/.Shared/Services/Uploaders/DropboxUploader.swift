//
//  DropboxUploader.swift
//  ShareBox
//
//  Created by Thom van den Broek on 14/09/2025.
//

import SwiftUI

// swiftlint:disable:next type_body_length
class DropboxUploader: FileUploader {
    private let apiService = ApiService()
    private var activeProvider: CloudDrive?
    private var pendingFiles: [FilePath] = []
    private var accessToken: String?

    override func getId() -> UploaderId {
        .dropBox
    }

    /// Check newly received metadata and check if that if all values are valid before continueing the file drop
    override func receivedMetadata(metadata: FileUploaderMetaData) -> Bool {
        if activeProvider != nil { return false }
        if let provider = User.shared?.drivesData.first(where: { $0.id == metadata.providerId && $0.provider == .DROPBOX }) {
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
            checkForCompleteState()
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
            // Dropbox simple upload supports up to 150 MB; beyond that, use upload session
           if details.size <= 150 * 1024 * 1024 {
               await self.uploadSimpleFile(file, token: token)
           } else {
               await self.uploadResumableFile(file, token: token)
           }
        }
        checkForCompleteState()
    }

    private func uploadSimpleFile(_ path: FilePath, token: String) async {
        do {
            let fileData = try Data(contentsOf: URL(string: path.absolute)!)
            let fileDetails = path.details()
            let dropboxArg: [String: Any] = [
                "path": "/\(fileDetails.fileName)",
                "mode": "add",
                "autorename": true,
                "mute": false,
                "strict_conflict": false
            ]
            let argData = try JSONSerialization.data(withJSONObject: dropboxArg, options: [])
            guard let argHeader = String(data: argData, encoding: .utf8) else {
                throw URLError(.badURL)
            }

            var request = URLRequest(url: URL(string: "https://content.dropboxapi.com/2/files/upload")!)
            request.httpMethod = "POST"
            request.httpBody = fileData
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
            request.setValue(argHeader, forHTTPHeaderField: "Dropbox-API-Arg")

            self.uploadProgress[path.absolute] = .init(status: .uploading)

            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                self.uploadProgress[path.absolute] = .init(status: .completed, uploadProgress: 100)
                checkForCompleteState()
            } else {
                #if DEBUG
                print("Dropbox simple upload error:", (response as? HTTPURLResponse)?.statusCode ?? -1,
                      String(data: data, encoding: .utf8) ?? "No data")
                #endif
                let status = (response as? HTTPURLResponse)?.statusCode ?? -1
                let mapped = self.mapDropboxError(data: data, status: status)
                self.uploadProgress[path.absolute] = .init(status: .failed, uploadProgress: 100, errors: [mapped])
                checkForCompleteState()
            }
        } catch {
            self.uploadProgress[path.absolute] = .init(status: .failed, uploadProgress: 100, errors: [.unknown])
            checkForCompleteState()
        }
    }

    // swiftlint:disable:next function_body_length
    private func uploadResumableFile(_ path: FilePath, token: String, chunkSize: Int = 8 * 1024 * 1014) async {
        do {
            let details = path.details()
            guard let fileURL = URL(string: path.absolute) else {
                self.uploadProgress[path.absolute] = .init(status: .failed, uploadProgress: 100, errors: [.fileNotFound])
                checkForCompleteState()
                return
            }
            let handle = try FileHandle(forReadingFrom: fileURL)
            defer { try? handle.close() }

            // Helper to build Dropbox-API-Arg header string
            func jsonHeader(_ obj: [String: Any]) throws -> String {
                let data = try JSONSerialization.data(withJSONObject: obj, options: [])
                guard let str = String(data: data, encoding: .utf8) else {
                    throw URLError(.badURL)
                }
                return str
            }

            // Read first chunk
            try handle.seek(toOffset: 0)
            let first = try handle.read(upToCount: min(chunkSize, Int(details.size))) ?? Data()

            // Start session with first chunk
            var startReq = URLRequest(url: URL(string: "https://content.dropboxapi.com/2/files/upload_session/start")!)
            startReq.httpMethod = "POST"
            startReq.httpBody = first
            startReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            startReq.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
            startReq.setValue(try jsonHeader(["close": false]), forHTTPHeaderField: "Dropbox-API-Arg")

            let (startData, startResp) = try await URLSession.shared.data(for: startReq)
            guard let httpStart = startResp as? HTTPURLResponse, (200...299).contains(httpStart.statusCode) else {
                let mapped = self.mapDropboxError(data: startData, status: (startResp as? HTTPURLResponse)?.statusCode ?? -1)
                self.uploadProgress[path.absolute] = .init(status: .failed, uploadProgress: 100, errors: [mapped])
                checkForCompleteState()
                return
            }
            let session = try JSONDecoder().decode(DropboxSessionStartResponse.self, from: startData)
            var offset = first.count

            self.uploadProgress[path.absolute] = .init(status: .uploading, uploadProgress: (Double(offset) / Double(details.size)) * 100)

            // Append chunks (except final)
            while offset + chunkSize < Int(details.size) {
                try handle.seek(toOffset: UInt64(offset))
                let data = try handle.read(upToCount: chunkSize) ?? Data()
                if data.isEmpty { break }

                var appendReq = URLRequest(url: URL(string: "https://content.dropboxapi.com/2/files/upload_session/append_v2")!)
                appendReq.httpMethod = "POST"
                appendReq.httpBody = data
                appendReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                appendReq.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
                appendReq.setValue(try jsonHeader([
                    "cursor": ["session_id": session.sessionId, "offset": offset],
                    "close": false
                ]), forHTTPHeaderField: "Dropbox-API-Arg")

                let (respData, resp) = try await URLSession.shared.data(for: appendReq)
                guard let http = resp as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                    #if DEBUG
                    print("Dropbox append error:", (resp as? HTTPURLResponse)?.statusCode ?? -1,
                          String(data: respData, encoding: .utf8) ?? "No data")
                    #endif
                    let mapped = self.mapDropboxError(data: respData, status: (resp as? HTTPURLResponse)?.statusCode ?? -1)
                    if mapped == .fileToBig {
                        self.uploadProgress[path.absolute] = .init(status: .failed, uploadProgress: 100, errors: [mapped])
                        checkForCompleteState()
                        return
                    }
                    throw URLError(.badServerResponse)
                }

                offset += data.count
                let progress = Double(offset) / Double(details.size)
                self.uploadProgress[path.absolute] = .init(status: .uploading, uploadProgress: progress * 100)
            }

            // Final chunk + finish
            try handle.seek(toOffset: UInt64(offset))
            let finalChunk = try handle.read(upToCount: Int(details.size) - offset) ?? Data()

            var finishReq = URLRequest(url: URL(string: "https://content.dropboxapi.com/2/files/upload_session/finish")!)
            finishReq.httpMethod = "POST"
            finishReq.httpBody = finalChunk
            finishReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            finishReq.setValue("application/octet-stream", forHTTPHeaderField: "Content-Type")
            finishReq.setValue(try jsonHeader([
                "cursor": ["session_id": session.sessionId, "offset": offset],
                "commit": [
                    "path": "/\(details.fileName)",
                    "mode": "add",
                    "autorename": true,
                    "mute": false,
                    "strict_conflict": false
                ]
            ]), forHTTPHeaderField: "Dropbox-API-Arg")

            let (finishData, finishResp) = try await URLSession.shared.data(for: finishReq)
            guard let httpFinish = finishResp as? HTTPURLResponse, (200...299).contains(httpFinish.statusCode) else {
                #if DEBUG
                print("Dropbox finish error:", (finishResp as? HTTPURLResponse)?.statusCode ?? -1,
                      String(data: finishData, encoding: .utf8) ?? "No data")
                #endif
                let mapped = self.mapDropboxError(data: finishData, status: (finishResp as? HTTPURLResponse)?.statusCode ?? -1)
                self.uploadProgress[path.absolute] = .init(status: .failed, uploadProgress: 100, errors: [mapped])
                checkForCompleteState()
                return
            }

            self.uploadProgress[path.absolute] = .init(status: .completed, uploadProgress: 100)
            checkForCompleteState()
        } catch {
            self.uploadProgress[path.absolute] = .init(status: .failed, uploadProgress: 100, errors: [.unknown])
            checkForCompleteState()
        }
    }

    private func updateProgress(path: FilePath, progress: FilePathProgress) {
        Task {
            await MainActor.run {
                uploadProgress[path.absolute] = progress
            }
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
                let res: DropboxSessionResponse = try await apiService.post(endpoint: "/api/drives/\(provider.id)/create-session")
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
                                "type": "DROPBOX"
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

    private func mapDropboxError(data: Data, status: Int) -> PlatformError {
        if let decoded = try? JSONDecoder().decode(DropboxAPIError.self, from: data) {
            if decoded.errorSummary?.lowercased().contains("insufficient_space") == true {
                return .fileToBig
            }
        }
        if status == 413 { return .fileToBig } // Payload Too Large
        return .unknown
    }
}

private struct DropboxSessionResponse: Codable {
    var accessToken: String
}

private struct DropboxSessionStartResponse: Codable {
    var sessionId: String
    enum CodingKeys: String, CodingKey { case sessionId = "session_id" }
}

private struct DropboxAPIError: Codable {
    var errorSummary: String?
    enum CodingKeys: String, CodingKey { case errorSummary = "error_summary" }
}
