//
//  Types.swift
//  ShareBox
//
//  Created by Thom van den Broek on 09/08/2025.
//

import Foundation
import UniformTypeIdentifiers

class MachMessage: Codable {
    var type: MessageType
    var data: Data?

    let buildNumber: Int

    init(type: MessageType, data: Data? = nil) {
        self.type = type
        self.data = data
        let myBuildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        buildNumber = Int(myBuildNumber ?? "1") ?? 1
    }

    enum MessageType: String, Codable {
        case fileUploadRequest
        case requestNotifications
        case notify
    }
}

extension MachMessage {
    public func encode() -> CFData? {
        let encoder = JSONEncoder()
        guard let encodedMessage = try? encoder.encode(self) else {
            return nil
        }
        return encodedMessage as CFData
    }
}

protocol MachData: Codable {}

extension MachData {
    public func encode() -> Data? {
        let encoder = JSONEncoder()
        guard let encodedMessage = try? encoder.encode(self) else {
            return nil
        }
        return encodedMessage
    }
}

// MachMessage Body Types
struct NotificationBody: MachData {
    var title: String
    var message: String
}
struct FileUploadBody: MachData {
    var items: [FilePath]
}

struct FilePath: Codable, Hashable {
    var relative: String
    var absolute: String
    var isFolder: Bool
}

extension FilePath {
    public func details() -> DetailedFile {
        var fileSize: Int64 = 0
        let url = URL(string: self.absolute)!
        let fileAttributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        if let attrSize = fileAttributes?[.size] as? Int64 {
            fileSize = attrSize
        }

        var mimeType = "application/octet-stream"
        if let utType = UTType(filenameExtension: url.pathExtension) {
            if let preferredMIMEType = utType.preferredMIMEType {
                mimeType = preferredMIMEType
            }
        }
        return .init(type: mimeType, size: fileSize, paths: self)
    }
}

struct DetailedFile: Codable {
    var type: String
    var size: Int64
    var paths: FilePath
}
enum FileError: String, Error {
    case unknown = "Error 1001: Unknown error occurred"
    case unauthorized = "Error 1002: Unauthorized to upload files"
    case limitReached = "Error 1003: Reached monthly upload limit"
    case noSubscription = "Error 1004: No active subscription"
    case fileNotFound = "Error 1005: File was not found"
    case fileSizeZero = "Error 1006: File size is zero"
    case fileToBig = "Error 1007: File size too big"
    case noUrlProvided = "Error 1008: No pre-signed url available"
    case s3Failed = "Error 1009: Uploading to S3 failed"
}

struct SharedGroup: Codable, Identifiable {
    var id: String
    var downloadCount: Int
    var fileCount: Int
    var expiresAt: String
    var url: String
}
