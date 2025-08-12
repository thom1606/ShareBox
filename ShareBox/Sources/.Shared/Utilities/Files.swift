//
//  Files.swift
//  ShareBox
//
//  Created by Thom van den Broek on 12/08/2025.
//

import Foundation

class Files {
    static func isDirectory(path: URL) -> Bool {
        var isDir = path.hasDirectoryPath
        let lowercasedPath = path.absoluteString.lowercased()
        if lowercasedPath.hasSuffix(".app/") ||
            lowercasedPath.hasSuffix(".appex/") ||
            lowercasedPath.hasSuffix(".xcodeproj/") ||
            lowercasedPath.hasSuffix(".xcworkspace/") ||
            lowercasedPath.hasSuffix(".xpc/") ||
            lowercasedPath.hasSuffix(".icon/") {
            isDir = false
        }
        return isDir
    }
}
