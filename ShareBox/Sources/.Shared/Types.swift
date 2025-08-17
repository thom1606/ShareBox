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

struct SharedGroup: Codable, Identifiable {
    var id: String
    var downloadCount: Int
    var fileCount: Int
    var expiresAt: String
    var url: String
}

extension String {
    subscript(offset: Int) -> Character {
        self[index(startIndex, offsetBy: offset)]
    }
}
