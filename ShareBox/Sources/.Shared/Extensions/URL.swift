//
//  Url.swift
//  ShareBox
//
//  Created by Thom van den Broek on 06/09/2025.
//

import Foundation

extension URL {
    func toFilePath() -> FilePath {
        .init(
            relative: self.lastPathComponent,
            absolute: self.absoluteString,
            isFolder: self.hasDirectoryPath
        )
    }
}
