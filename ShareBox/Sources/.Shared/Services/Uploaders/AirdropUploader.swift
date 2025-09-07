//
//  AirdropUploader.swift
//  ShareBox
//
//  Created by Thom van den Broek on 06/09/2025.
//

import Foundation
import AppKit

class AirdropUploader: FileUploader {
    override func getId() -> UploaderId {
        .airdrop
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
                    path = .init(relative: url.lastPathComponent, absolute: url.absoluteString, isFolder: url.hasDirectoryPath)
                } else if let url = item as? URL {
                    path = .init(relative: url.lastPathComponent, absolute: url.absoluteString, isFolder: url.hasDirectoryPath)
                }

                if path == nil { return }
                finalPaths.append(path!)
            }
        }

        group.notify(queue: .main) {
            // Get the AirDrop sharing service
            if let airDropService = NSSharingService(named: .sendViaAirDrop) {
                airDropService.perform(withItems: finalPaths.map { URL(string: $0.absolute)! })
            } else {
                print("AirDrop service not available")
            }
        }

        return hasItemWithURL
    }
}
