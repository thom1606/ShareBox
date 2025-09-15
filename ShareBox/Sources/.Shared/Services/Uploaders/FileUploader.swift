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

    public func stateStream() -> AsyncStream<UploadState> {
        AsyncStream { continuation in
            self.stateContinuation = continuation
            continuation.yield(state)
        }
    }

    public func progressStream() -> AsyncStream<[String: FilePathProgress]> {
        AsyncStream { continuation in
            self.progressContinuation = continuation
            continuation.yield(uploadProgress)
        }
    }

    public func filesStream() -> AsyncStream<[FilePath]> {
        AsyncStream { continuation in
            self.filesContinuation = continuation
            continuation.yield(droppedFiles)
        }
    }

    /// Get files within the given folder path and convert them to FilePath's
    public func getFilesInFolder(basePath: String, url: URL) -> [FilePath] {
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

    // Overridable
    public func confirmDrop(paths _: [FilePath], metadata _: FileUploaderMetaData? = nil) {
        print("Dropped files on generic FileUploader, not handled")
    }

    public func confirmDrop(providers _: [NSItemProvider], metadata _: FileUploaderMetaData? = nil) -> Bool {
        print("Dropped files on generic FileUploader, not handled")
        return false
    }

    public func complete() {
        self.reset()
    }

    public func reset() {
        uploadProgress.removeAll()
        droppedFiles.removeAll()
        state = .idle
    }

    public func getId() -> UploaderId {
        return .sharebox
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
