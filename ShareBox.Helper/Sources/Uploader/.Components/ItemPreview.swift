//
//  ItemPreview.swift
//  ShareBox.Helper
//
//  Created by Thom van den Broek on 11/08/2025.
//

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ItemPreview: View {
    var state: UploadViewModel
    var item: FilePath
    var completed: Bool

    // Local properties
    private var icon: NSImage?
    private var name: String
    private var isImage: Bool
    private var imagePreview: NSImage?

    @State private var showErrorPopover: Bool = false

    init(state: UploadViewModel, item: FilePath, completed: Bool = false) {
        self.state = state
        self.item = item
        self.completed = completed

        // Use URL to properly decode percent-encoded file paths
        let fileURL: URL
        if let url = URL(string: item.absolute), url.isFileURL {
            fileURL = url
        } else {
            fileURL = URL(fileURLWithPath: item.absolute)
        }
        name = fileURL.lastPathComponent

        // Determine if the file is an image
        let fileExtension = fileURL.pathExtension.lowercased()
        let imageTypes: Set<String> = ["png", "jpg", "jpeg", "gif", "bmp", "tiff", "heic", "webp", "ico", "icns", "svg"]
        isImage = imageTypes.contains(fileExtension)

        if isImage, let img = NSImage(contentsOf: fileURL) {
            imagePreview = img
            icon = nil
        } else {
            imagePreview = nil
            icon = NSWorkspace.shared.icon(forFile: fileURL.path)
        }
    }

    private var errors: [String: String] {
        if let itemError = state.failedPaths[item.absolute] {
            return [item.absolute: itemError]
        } else if item.isFolder {
            var res: [String: String] = [:]
            for key in state.failedPaths.keys where key.hasPrefix(item.absolute) {
                res[URL(fileURLWithPath: key).lastPathComponent] = state.failedPaths[key]!
            }
            return res
        }
        return [:]
    }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(alignment: .center, spacing: 3) {
                if let imagePreview = imagePreview {
                    Image(nsImage: imagePreview)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                } else if let icon = icon {
                    Image(nsImage: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                } else {
                    Image(systemName: "questionmark.folder")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 40, height: 40)
                }
                Text(name)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 3)
            }
            .opacity(completed && errors.isEmpty ? 1 : 0.4)

            // Failed overlay
            if !errors.isEmpty {
                ZStack(alignment: .center) {
                    Image(systemName: "exclamationmark.triangle")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(.yellow)
                        .frame(width: 30, height: 30)
                    }
                    .popover(isPresented: $showErrorPopover) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Upload failed")
                                .font(.headline)
                            Group {
                                if item.isFolder {
                                    Text("One or more files in your folder named \"\(name)\" has failed to upload and gave the following errors:")
                                } else {
                                    Text("Your item named \"\(name)\" has failed to upload and gave the following error:")
                                }
                            }
                            .multilineTextAlignment(.leading)
                            .font(.body)
                            .padding(.top, 3)
                            .padding(.bottom, 8)
                            .foregroundStyle(.secondary)
                            VStack(alignment: .leading) {
                                ForEach(Array(errors.keys), id: \.self) { key in
                                    if item.isFolder {
                                        VStack(alignment: .leading, spacing: 0) {
                                            Text(key)
                                                .foregroundStyle(.primary)
                                            Text(errors[key]!)
                                        }
                                    } else {
                                        Text(errors[key]!)
                                    }
                                }
                            }
                            .font(.body)
                            .foregroundStyle(.tertiary)
                        }
                        .frame(minWidth: 200, idealWidth: 200, maxWidth: 200)
                        .padding(10)
                }
                .onHover { isOver in
                    showErrorPopover = isOver
                }
                .frame(width: 67, height: 40)
            }
        }
        .frame(width: 67)
    }
}

#Preview {
    ItemPreview(state: .init(), item: .init(relative: "Example App", absolute: "file:///Users/thomvandenbroek/Projects/TryOut/SwiftyXPC/Example%20App/", isFolder: true))
}
