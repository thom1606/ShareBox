//
//  Types.swift
//  ShareBox
//
//  Created by Thom van den Broek on 09/08/2025.
//

import Foundation
import UniformTypeIdentifiers

struct MachMessage : Codable {
    var type: MessageType
    var data: Data?
    
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



