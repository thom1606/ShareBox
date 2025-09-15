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

    override func confirmDrop(paths: [FilePath], metadata _: FileUploaderMetaData? = nil) {
        Task { await self.appendFiles(paths) }
    }

    override func confirmDrop(providers: [NSItemProvider], metadata _: FileUploaderMetaData? = nil) -> Bool {
        var hasItemWithURL = false
        var finalPaths: [FilePath] = []
        let group = DispatchGroup()

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
                if let legitPath = path { finalPaths.append(legitPath) }
            }
        }

        group.notify(queue: .main) {
            Task { await self.appendFiles(finalPaths) }
        }
        return hasItemWithURL
    }

    override func reset() {
        uploadProgress.removeAll()
        droppedFiles.removeAll()
        state = .idle
    }

    private func appendFiles(_ paths: [FilePath]) async {
        let nonDuplicatePaths = paths.filter { path in !self.droppedFiles.contains(where: { $0.absolute == path.absolute }) }
        self.droppedFiles.append(contentsOf: nonDuplicatePaths)
        if state == .idle {
            state = .preparingGroup
            try? await Task.sleep(for: .seconds(1))
        }
        await self.startUpload(paths)
    }

    private func startUpload(_ paths: [FilePath]) async {
        self.state = .uploading

        // Expand folders to files
        var onlyFiles: [FilePath] = []
        paths.forEach {
            guard let itemURL = URL(string: $0.absolute) else {
                self.uploadProgress[$0.absolute] = .init(status: .failed, uploadProgress: 100, errors: [.fileNotFound])
                return
            }
            if itemURL.hasDirectoryPath {
                let parentURL = itemURL.deletingLastPathComponent()
                let basePath = parentURL.path
                let files = self.getFilesInFolder(
                    basePath: "file://\(basePath)/",
                    url: itemURL
                )
                onlyFiles.append(contentsOf: files)
            } else {
                onlyFiles.append($0)
            }
        }

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
        checkForCompleteState()
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

    // swiftlint:disable:next function_body_length cyclomatic_complexity
    private func copyToICloud(_ path: FilePath) async {
        guard let docsRoot = await containerDocumentsURL() else {
            self.uploadProgress[path.absolute] = .init(status: .failed, uploadProgress: 100, errors: [.driveUnauthorized])
            checkForCompleteState()
            return
        }

        let fileManager = FileManager.default

        // Destination base: iCloud Container / Documents /
        let baseDir = docsRoot
        do {
            try fileManager.createDirectory(at: baseDir, withIntermediateDirectories: true, attributes: nil)
        } catch {
            self.uploadProgress[path.absolute] = .init(status: .failed, uploadProgress: 100, errors: [.unknown])
            checkForCompleteState()
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
            checkForCompleteState()
            return
        }

        // Avoid name collisions
        destURL = uniqueDestination(base: destURL)

        // Chunked copy with progress
        guard let srcURL = URL(string: path.absolute) else {
            self.uploadProgress[path.absolute] = .init(status: .failed, uploadProgress: 100, errors: [.fileNotFound])
            checkForCompleteState()
            return
        }

        let scoped = srcURL.startAccessingSecurityScopedResource()
        defer { if scoped { srcURL.stopAccessingSecurityScopedResource() } }

        let coordinator = NSFileCoordinator()
        var coordError: NSError?

        coordinator.coordinate(readingItemAt: srcURL, options: .withoutChanges, writingItemAt: destURL, options: [], error: &coordError) { readURL, writeURL in
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
                    try Task.checkCancellation()
                    let data = try read.read(upToCount: chunk) ?? Data()
                    print(data.count)
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

        if coordError != nil {
            self.uploadProgress[path.absolute] = .init(status: .failed, uploadProgress: 100, errors: [.unknown])
        }

        checkForCompleteState()
    }

    private func uniqueDestination(base: URL) -> URL {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: base.path) { return base }

        let name = base.deletingPathExtension().lastPathComponent
        let ext = base.pathExtension
        let dir = base.deletingLastPathComponent()

        var index = 1
        while true {
            let candidateName = "\(name) (\(index))"
            let candidate = dir.appendingPathComponent(ext.isEmpty ? candidateName : "\(candidateName).\(ext)")
            if !fileManager.fileExists(atPath: candidate.path) { return candidate }
            index += 1
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
}
