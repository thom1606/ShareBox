//
//  iCloudUploader.swift
//  ShareBox
//
//  Created by Thom van den Broek on 14/09/2025.
//

import SwiftUI

class iCloudUploader: FileUploader {
    private let containerId = "iCloud.ShareBox"

    override func getId() -> UploaderId {
        .iCloud
    }

    override func processBatch(paths: [FilePath]) async {
        self.state = .uploading
        // Get all files which are hidden inside folders
        let onlyFiles = self.getFilesFromPaths(paths: paths)

        // Mark notarized
        for file in onlyFiles {
            self.uploadProgress[file.absolute] = .init(status: .notarized)
        }

        // Mark empty folders as failed
        paths.forEach { path in
            if !onlyFiles.contains(where: { $0.absolute.hasPrefix(path.absolute) }) {
                self.uploadProgress[path.absolute] = .init(status: .failed, uploadProgress: 100, errors: [.fileNotFound])
            }
        }

        for file in onlyFiles {
            await self.copyToICloud(file)
        }
    }

    // Attempts to get the iCloud ubiquity container's Documents directory with a brief retry to allow iCloud to initialize.
    private func containerDocumentsURL() async -> URL? {
        let fileManager = FileManager.default
        for _ in 0..<10 {
            if let containerURL = fileManager.url(forUbiquityContainerIdentifier: containerId) {
                return containerURL.appendingPathComponent("Documents", isDirectory: true)
            }
            try? await Task.sleep(for: .milliseconds(300))
        }
        return nil
    }

    // swiftlint:disable:next cyclomatic_complexity function_body_length
    private func copyToICloud(_ path: FilePath) async {
        guard let docsRoot = await containerDocumentsURL() else {
            self.uploadProgress[path.absolute] = .init(status: .failed, uploadProgress: 100, errors: [.driveUnauthorized])
            return
        }

        let fileManager = FileManager.default

        // Destination base: iCloud Container / Documents /
        let baseDir = docsRoot
        do {
            try fileManager.createDirectory(at: baseDir, withIntermediateDirectories: true, attributes: nil)
        } catch {
            self.uploadProgress[path.absolute] = .init(status: .failed, uploadProgress: 100, errors: [.unknown])
            return
        }

        // Build destination path preserving relative folder structure
        let relativeSubpath = (path.relative.removingPercentEncoding ?? path.relative)
        let components = relativeSubpath.split(separator: "/").map(String.init)
        var destURL = baseDir
        for component in components {
            destURL.appendPathComponent(component)
        }

        // Ensure parent directories exist
        do {
            try fileManager.createDirectory(at: destURL.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
        } catch {
            self.uploadProgress[path.absolute] = .init(status: .failed, uploadProgress: 100, errors: [.unknown])
            return
        }

        // Chunked copy with progress
        guard let srcURL = URL(string: path.absolute) else {
            self.uploadProgress[path.absolute] = .init(status: .failed, uploadProgress: 100, errors: [.fileNotFound])
            return
        }

        let scoped = srcURL.startAccessingSecurityScopedResource()
        defer { if scoped { srcURL.stopAccessingSecurityScopedResource() } }

        var coordError: NSError?
        // Await the completion of file coordination work
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            let coordinator = NSFileCoordinator()
            coordinator.coordinate(readingItemAt: srcURL, options: .withoutChanges, writingItemAt: destURL, options: [], error: &coordError) { readURL, writeURL in
                defer {
                    continuation.resume()
                }

                do {
                    let attrs = try fileManager.attributesOfItem(atPath: readURL.path)
                    let size = (attrs[.size] as? NSNumber)?.intValue ?? 0
                    if size == 0 {
                        self.uploadProgress[path.absolute] = .init(status: .failed, uploadProgress: 100, errors: [.fileSizeZero])
                        return
                    }

                    fileManager.createFile(atPath: writeURL.path, contents: nil)
                    guard let read = try? FileHandle(forReadingFrom: readURL),
                          let write = try? FileHandle(forWritingTo: writeURL) else {
                        self.uploadProgress[path.absolute] = .init(status: .failed, uploadProgress: 100, errors: [.unknown])
                        return
                    }
                    defer { try? read.close(); try? write.close() }

                    let chunk = 4 * 1024 * 1024
                    var copied = 0
                    self.uploadProgress[path.absolute] = .init(status: .uploading, uploadProgress: 0)

                    while true {
                        do { try Task.checkCancellation() } catch {
                            // Best effort: mark as failed and stop copying
                            self.uploadProgress[path.absolute] = .init(status: .failed, uploadProgress: 100, errors: [.unknown])
                            return
                        }
                        let data = try read.read(upToCount: chunk) ?? Data()
                        if data.isEmpty { break }
                        try write.write(contentsOf: data)
                        copied += data.count
                        let progress = min(100, (Double(copied) / Double(size)) * 100)
                        self.uploadProgress[path.absolute] = .init(status: .uploading, uploadProgress: progress)
                    }
                    self.uploadProgress[path.absolute] = .init(status: .completed, uploadProgress: 100)
                } catch {
                    self.uploadProgress[path.absolute] = .init(status: .failed, uploadProgress: 100, errors: [.unknown])
                }
            }
        }
        if coordError != nil {
            self.uploadProgress[path.absolute] = .init(status: .failed, uploadProgress: 100, errors: [.unknown])
        }
    }

}
