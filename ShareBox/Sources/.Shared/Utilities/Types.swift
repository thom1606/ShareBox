//
//  Types.swift
//  ShareBox
//
//  Created by Thom van den Broek on 09/08/2025.
//

import Foundation
import UniformTypeIdentifiers

struct FilePath: Codable, Hashable {
    var relative: String
    var absolute: String
    var isFolder: Bool
}

extension FilePath {
    public func details() -> DetailedFile {
        var fileSize: Int64 = 0

        let url = URL(string: self.absolute)!
        let fileName = url.lastPathComponent
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
        return .init(type: mimeType, size: fileSize, fileName: fileName, paths: self)
    }
}

struct DetailedFile: Codable {
    var type: String
    var size: Int64
    var fileName: String
    var paths: FilePath
}

struct SharedGroup: Codable, Identifiable {
    var id: String
    var downloadCount: Int
    var fileCount: Int
    var expiresAt: String
    var url: String
}

struct BoxDetails: Codable {
    var groupId: String
    var url: String
}

enum DriveProvider: String, Codable, CaseIterable, Identifiable {
    case GOOGLE
    case ONEDRIVE
    case ICLOUD
    case DROPBOX

    var id: String {
        self.rawValue
    }

    var displayName: String {
        switch self {
        case .GOOGLE: return "Google Drive"
        case .ONEDRIVE: return "OneDrive"
        case .ICLOUD: return "iCloud"
        case .DROPBOX: return "Dropbox"
        }
    }
}
