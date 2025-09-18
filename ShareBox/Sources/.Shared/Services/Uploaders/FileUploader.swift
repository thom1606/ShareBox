//
//  FileUploader.swift
//  ShareBox
//
//  Created by Thom van den Broek on 06/09/2025.
//

import Foundation
import Combine

class FileUploader {
    var state: UploadState = .idle {
        didSet {
            stateContinuation?.yield(state)
        }
    }
    var uploadProgress: [String: FilePathProgress] = [:] {
        didSet {
            progressContinuation?.yield(uploadProgress)
        }
    }

    var droppedFiles: [FilePath] = [] {
        didSet {
            filesContinuation?.yield(droppedFiles)
        }
    }

    private var stateContinuation: AsyncStream<UploadState>.Continuation?
    private var progressContinuation: AsyncStream<[String: FilePathProgress]>.Continuation?
    private var filesContinuation: AsyncStream<[FilePath]>.Continuation?
    var progressCancellables: [String: AnyCancellable] = [:]

    // Required initializer for generic construction
    required init() {}

    // Update publisher for upload state changes
    public final func stateStream() -> AsyncStream<UploadState> {
        AsyncStream { continuation in
            self.stateContinuation = continuation
            continuation.yield(state)
        }
    }

    /// Update publisher for progress updates
    public final func progressStream() -> AsyncStream<[String: FilePathProgress]> {
        AsyncStream { continuation in
            self.progressContinuation = continuation
            continuation.yield(uploadProgress)
        }
    }

    /// Update publisher for dropped and registered files
    public final func filesStream() -> AsyncStream<[FilePath]> {
        AsyncStream { continuation in
            self.filesContinuation = continuation
            continuation.yield(droppedFiles)
        }
    }

    /// Get files within the given folder path and convert them to FilePath's
    private func getFilesInFolder(basePath: String, url: URL) -> [FilePath] {
        var files: [FilePath] = []
        let fileManager = FileManager.default
        var options: FileManager.DirectoryEnumerationOptions = []
        if !UserDefaults.standard.bool(forKey: Constants.Settings.hiddenFilesPrefKey) {
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

    /// Confirm item drops coming from NSOpenPanel or other internal linking methods
    public func confirmDrop(paths: [FilePath], metadata: FileUploaderMetaData? = nil) {
        if let meta = metadata, !receivedMetadata(metadata: meta) {
            return
        }
        self.filterFiles(paths: paths)
    }

    /// Confirm item drops  coming from file drops
    public func confirmDrop(providers: [NSItemProvider], metadata: FileUploaderMetaData? = nil) -> Bool {
        if let meta = metadata, !receivedMetadata(metadata: meta) {
            return false
        }

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

                if path == nil { return }
                finalPaths.append(path!)
            }
        }

        group.notify(queue: .main) {
            Task {
               self.filterFiles(paths: finalPaths)
            }
        }

        return hasItemWithURL
    }

    /// Fetch all file paths (without folders) for the given paths
    public final func getFilesFromPaths(paths: [FilePath]) -> [FilePath] {
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
        return onlyFiles
    }

    /// Check with all files if there are any left, if not, we can continue to the complete state
    public final func checkForCompleteState() {
        Task {
            // Find any file left not in the completed or failed state
            var hasPendingFiles = false
            if self.uploadProgress.values.contains(where: { $0.status != .completed && $0.status != .failed }) {
                hasPendingFiles = true
            }
            if !hasPendingFiles && self.state == .uploading {
                self.state = .completed
            }
        }
    }

    // Overridable
    public func processBatch(paths _: [FilePath]) async {
        print("Proces batch not implemented...")
    }

    /// Fired after all uploadProgresses are set to either completed or failed
    public func complete() {}

    /// Reset all values and states connecting with the latest upload
    public func reset() {
        uploadProgress.removeAll()
        droppedFiles.removeAll()
        state = .idle
    }

    /// Check newly received metadata and check if that if all values are valid before continueing the file drop
    public func receivedMetadata(metadata _: FileUploaderMetaData) -> Bool {
        return true
    }

    /// Quickly get the type of uploader this is
    public func getId() -> UploaderId {
        return .sharebox
    }

    private func filterFiles(paths: [FilePath]) {
        // Filter out all the duplicates
        let nonDuplicatePaths = paths.filter { path in !self.droppedFiles.contains(where: { $0.relative == path.relative }) }
        self.droppedFiles.append(contentsOf: nonDuplicatePaths)
        if nonDuplicatePaths.isEmpty { return }
        Task {
            await processBatch(paths: nonDuplicatePaths)
            checkForCompleteState()
        }
    }
}

enum UploaderId: Int {
    case sharebox = 0
    case airdrop = 1
    case iCloud = 2
    case googleDrive = 3
    case dropBox = 4
    case oneDrive = 5
}

enum UploadState: Equatable {
    case idle
    case preparingGroup
    case uploading
    case error(PlatformError)
    case completed
}

struct FilePathProgress: Equatable {
    var status: Status
    var uploadProgress: CGFloat = 0
    var errors: [PlatformError] = []

    enum Status {
        case unknown
        case notarized
        case failed
        case completed
        case uploading
    }
}

struct FileUploaderMetaData: Equatable {
    var providerId: String?
}
