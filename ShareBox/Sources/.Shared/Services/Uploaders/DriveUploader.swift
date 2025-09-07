//
//  DriveUploader.swift
//  ShareBox
//
//  Created by Thom van den Broek on 06/09/2025.
//

import Foundation

class DriveUploader: FileUploader {
    override func getId() -> UploaderId {
        .drive
    }

    override func confirmDrop(paths: [FilePath]) {
        self.droppedFiles.append(contentsOf: paths)
        // TODO: append to the upload queue and update state correctly
        self.state = .preparingGroup
    }

    override func confirmDrop(providers: [NSItemProvider]) -> Bool {
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
            self.droppedFiles.append(contentsOf: finalPaths)
            // TODO: append to the upload queue and update state correctly
            self.state = .preparingGroup
        }

        return hasItemWithURL
    }
}
