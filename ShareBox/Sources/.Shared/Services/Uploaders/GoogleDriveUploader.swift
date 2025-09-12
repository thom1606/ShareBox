//
//  DriveUploader.swift
//  ShareBox
//
//  Created by Thom van den Broek on 06/09/2025.
//

import SwiftUI

// swiftlint:disable:next type_body_length
class GoogleDriveUploader: FileUploader {
    private let apiService = ApiService()
    private var activeProvider: CloudDrive?
    private var pendingFiles: [FilePath] = []
    private var accessToken: String?

    override func getId() -> UploaderId {
        .googleDrive
    }

    override func confirmDrop(paths: [FilePath], metadata: FileUploaderMetaData? = nil) {
        if let meta = metadata {
            if activeProvider != nil { return }
            if let provider = User.shared?.drivesData.first(where: { $0.id == meta.providerId && $0.provider == "GOOGLE" }) {
                activeProvider = provider
            } else {
                return
            }
        }
        Task {
           await self.appendFiles(paths)
        }
    }

    override func confirmDrop(providers: [NSItemProvider], metadata: FileUploaderMetaData? = nil) -> Bool {
        var hasItemWithURL = false
        var finalPaths: [FilePath] = []
        let group = DispatchGroup()

        if let meta = metadata {
            if activeProvider != nil { return false }
            if let provider = User.shared?.drivesData.first(where: { $0.id == meta.providerId && $0.provider == "GOOGLE" }) {
                activeProvider = provider
            } else {
                return false
            }
        }

        for provider in providers where provider.hasItemConformingToTypeIdentifier("public.file-url") {
            hasItemWithURL = true
            group.enter()

            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (item, _) in
                defer { group.leave() }

                var path: FilePath?
                if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    path = url.toFilePath()
                } else if let url = item as? URL {
                    path = url.toFilePath()
                }

                if path == nil { return }
                finalPaths.append(path!)
            }
        }

        group.notify(queue: .main) {
            Task {
               await self.appendFiles(finalPaths)
            }
        }
        return hasItemWithURL
    }

    override func reset() {
        activeProvider = nil
        accessToken = nil
        uploadProgress.removeAll()
        droppedFiles.removeAll()
        state = .idle
    }

    /// Filter out duplicates before appending anything
    private func appendFiles(_ paths: [FilePath]) async {
        // Filter out all the duplicates
        let nonDuplicatePaths = paths.filter { path in !self.droppedFiles.contains(where: { $0.absolute == path.absolute }) }
        self.droppedFiles.append(contentsOf: nonDuplicatePaths)
        try? await self.processBatch(paths)
    }

    /// Start processing the given batch with the drive's server
    private func processBatch(_ files: [FilePath]) async throws {
        guard !files.isEmpty else { return }

        // If drive is already authenticated → upload immediately
        if let token = accessToken {
            return await startUpload(files, token: token)
        }

        // If access_token is being generated → stash the files
        if state == .preparingGroup {
            pendingFiles.append(contentsOf: files)
            return
        }

        // Otherwise, create access_token first
        guard let token = try? await ensureToken() else {
            for path in files {
                self.uploadProgress[path.absolute] = .init(status: .failed, uploadProgress: 100, errors: [.driveUnauthorized])
            }
            return
        }
        await startUpload(files, token: token)
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
        var onlyFiles: [FilePath] = []
        paths.forEach {
            guard let itemURL = URL(string: $0.absolute) else {
                self.uploadProgress[$0.absolute] = .init(status: .failed, uploadProgress: 100, errors: [.fileNotFound])
                return
            }
            if itemURL.hasDirectoryPath {
                let parentURL = itemURL.deletingLastPathComponent()
                let basePath = parentURL.path
                // For all folders, it should go in and fetch all those children until there are no folders left
                let files = self.getFilesInFolder(
                    basePath: "file://\(basePath)/",
                    url: itemURL
                )
                onlyFiles.append(contentsOf: files)
            } else {
                onlyFiles.append($0)
            }
        }

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
            if details.size <= 5 * 1024 * 1024 { // Files <= 5MB -> Simple multipart upload
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

            // Create metadata JSON
            let metadata: [String: Any] = [
                "name": fileDetails.fileName,
                "mimeType": fileDetails.type
            ]
            let metadataData = try JSONSerialization.data(withJSONObject: metadata, options: [])

            let boundary = "----WebKitFormBoundary\(UUID().uuidString)"
            var body = Data()
            body.appendString("--\(boundary)\r\n")
            body.appendString("Content-Type: application/json; charset=UTF-8\r\n\r\n")
            body.append(metadataData)
            body.appendString("\r\n")
            body.appendString("--\(boundary)\r\n")
            body.appendString("Content-Type: \(fileDetails.type)\r\n\r\n")
            body.append(fileData)
            body.appendString("\r\n")
            body.appendString("--\(boundary)--\r\n")

            var request = URLRequest(url: URL(string: "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart")!)
            request.httpMethod = "POST"
            request.httpBody = body
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            request.setValue("multipart/related; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
             request.setValue("\(body.count)", forHTTPHeaderField: "Content-Length")

            // Mark as uploading (no progress tracking)
            self.uploadProgress[path.absolute] = .init(status: .uploading)

            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                self.uploadProgress[path.absolute] = .init(status: .completed, uploadProgress: 100)
                checkForCompleteState()
            } else {
                #if DEBUG
                print("Google Drive multipart error:", (response as? HTTPURLResponse)?.statusCode ?? -1,
                      String(data: data, encoding: .utf8) ?? "No data")
                #endif
                self.uploadProgress[path.absolute] = .init(status: .failed, uploadProgress: 100, errors: [.unknown])
                checkForCompleteState()
            }
        } catch {
            self.uploadProgress[path.absolute] = .init(status: .failed, uploadProgress: 100, errors: [.unknown])
            checkForCompleteState()
        }
    }

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    private func uploadResumableFile(_ path: FilePath, token: String, chunkSize: Int = 10 * 1024 * 1014) async {
        do {
            let details = path.details()

            // Initiate session
            let metadata: [String: Any] = [
                "name": details.fileName,
                "mimeType": details.type
            ]
            let metadataData = try JSONSerialization.data(withJSONObject: metadata, options: [])
            var initReq = URLRequest(url: URL(string: "https://www.googleapis.com/upload/drive/v3/files?uploadType=resumable")!)
            initReq.httpMethod = "POST"
            initReq.httpBody = metadataData
            initReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            initReq.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
            initReq.setValue(details.type, forHTTPHeaderField: "X-Upload-Content-Type")
            initReq.setValue("\(details.size)", forHTTPHeaderField: "X-Upload-Content-Length")

            let (_, initResp) = try await URLSession.shared.data(for: initReq)
            guard let httpInit = initResp as? HTTPURLResponse,
                  (200...299).contains(httpInit.statusCode),
                  let location = httpInit.allHeaderFields["Location"] as? String,
                  let sessionURL = URL(string: location) else {
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

            let align = 256 * 1024
            var offset = 0

            // Helper to recover server offset after timeout/network hiccup
            func queryServerOffset() async throws -> Int? {
                var statusReq = URLRequest(url: sessionURL)
                statusReq.httpMethod = "PUT"
                statusReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                statusReq.setValue("bytes */\(details.size)", forHTTPHeaderField: "Content-Range")
                statusReq.setValue("0", forHTTPHeaderField: "Content-Length")
                statusReq.timeoutInterval = 30

                let (_, resp) = try await URLSession.shared.data(for: statusReq)
                guard let http = resp as? HTTPURLResponse else { return nil }
                if http.statusCode == 308 {
                    if let range = http.allHeaderFields["Range"] as? String,
                       let last = range.split(separator: "=").last?.split(separator: "-").last,
                       let lastByte = Int(last) {
                        return lastByte + 1
                    }
                    return 0
                } else if (200...299).contains(http.statusCode) {
                    self.uploadProgress[path.absolute] = .init(status: .completed, uploadProgress: 100)
                    return nil
                }
                return nil
            }

            while offset < Int(details.size) {
                let bytesLeft = Int(details.size) - offset

                // Align non-final chunks to 256 KiB multiples
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
                putReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                putReq.setValue(details.type, forHTTPHeaderField: "Content-Type")
                putReq.setValue("\(data.count)", forHTTPHeaderField: "Content-Length")
                putReq.setValue("bytes \(start)-\(end)/\(details.size)", forHTTPHeaderField: "Content-Range")

                do {
                    let (_, putResp) = try await URLSession.shared.data(for: putReq)
                    guard let httpPut = putResp as? HTTPURLResponse else {
                        throw URLError(.badServerResponse)
                    }

                    if httpPut.statusCode == 308 {
                        let progress = Double(end + 1) / Double(details.size)
                        self.uploadProgress[path.absolute] = .init(status: .uploading, uploadProgress: progress * 100)
                        offset = end + 1
                    } else if (200...299).contains(httpPut.statusCode) {
                        self.uploadProgress[path.absolute] = .init(status: .completed, uploadProgress: 100)
                        break
                    } else {
                        #if DEBUG
                        print("Resumable upload chunk failed with status:", httpPut.statusCode)
                        #endif
                        throw URLError(.badServerResponse)
                    }
                } catch {
                    // Attempt to recover current offset from server and continue
                    if let nextOffset = try? await queryServerOffset() {
                        offset = nextOffset
                        continue
                    }
                    throw error
                }
            }
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

    private func checkForCompleteState() {
        Task {
            try? await Task.sleep(for: .seconds(0.2))
            var hasPendingFiles = false
            if self.uploadProgress.values.contains(where: { $0.status != .completed && $0.status != .failed }) {
                hasPendingFiles = true
            }
            if !hasPendingFiles {
                self.state = .completed
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
                let res: GoogleSessionResponse = try await apiService.post(endpoint: "/api/drives/\(provider.id)/create-session")
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
                                "type": "google"
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
}

private struct GoogleSessionResponse: Codable {
    var accessToken: String
}
// swiftlint:disable:this file_length
