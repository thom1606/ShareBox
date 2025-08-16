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
    var state: UploaderViewModel
    var item: FilePath

    // Local properties
    private var icon: NSImage?
    private var name: String
    private var isImage: Bool
    private var imagePreview: NSImage?
    private var couldBeFound: Bool = false

    @State private var showErrorPopover: Bool = false

    init(state: UploaderViewModel, item: FilePath) {
        self.state = state
        self.item = item

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

    // Errors mapped to [File name: [error list]]
    private var errors: [String: [FileError]] {
        if let itemError = state.uploadProgress[item.absolute], !itemError.errors.isEmpty {
            return [item.absolute: itemError.errors]
        } else if item.isFolder {
            var res: [String: [FileError]] = [:]
            for key in state.uploadProgress.keys where key.hasPrefix(item.absolute) && !state.uploadProgress[key]!.errors.isEmpty {
                res[URL(fileURLWithPath: key).lastPathComponent] = state.uploadProgress[key]!.errors
            }
            return res
        }
        return [:]
    }

    private var isCompleted: Bool {
        if item.isFolder {
            var hasIncomplete = false
            // Check for all files inside if they are completed
            for key in state.uploadProgress.keys where key.hasPrefix(item.absolute) {
                if key == item.absolute { continue }
                let status = state.uploadProgress[key]!.status
                if status != .completed && status != .failed {
                    hasIncomplete = true
                }
            }
            return !hasIncomplete
        }
        let status = state.uploadProgress[item.absolute]?.status ?? .unknown
        return status == .completed || status == .failed
    }

    private var uploadProgress: CGFloat {
        if item.isFolder {
            var itemCount = 0
            var totalCombinedProgress: CGFloat = 0
            for key in state.uploadProgress.keys where key.hasPrefix(item.absolute) {
                if key == item.absolute { continue }
                itemCount += 1
                totalCombinedProgress += state.uploadProgress[key]!.uploadProgress
            }
            if itemCount > 0 {
                var result = totalCombinedProgress / CGFloat(itemCount)
                if result == 0 { result = 0.01 }
                return result
            }
            if !isCompleted { return 0.01 }
            return 0
        }
        return state.uploadProgress[item.absolute]?.uploadProgress ?? 0
    }

    var body: some View {
        ZStack(alignment: .top) {
            VStack(alignment: .center, spacing: 3) {
                if let imagePreview = imagePreview {
                    Image(nsImage: imagePreview)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                } else if let icon = icon {
                    Image(nsImage: icon)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                } else {
                    Image(systemName: "questionmark.folder")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 50, height: 50)
                }
                Text(name)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 3)
            }
            .opacity(isCompleted && errors.isEmpty ? 1 : 0.4)

            // Progress overlay
            if !isCompleted && errors.isEmpty && uploadProgress > 0.001 {
                ZStack(alignment: .center) {
                    ProgressCircle(progress: uploadProgress)
                        .frame(width: 30, height: 30)
                }
                .frame(width: 50, height: 50)
            }

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
                                Text("One or more files in your folder named \"\(name)\" have failed to upload and gave the following errors:")
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
                            //                                ForEach(Array(errors.keys) as [String], id: \.self) { key in
                            //                                    if item.isFolder {
                            //                                        VStack(alignment: .leading, spacing: 0) {
                            //                                            Text(key)
                            //                                                .foregroundStyle(.primary)
                            ////                                            ForEach(errors[key]!, id: \.self) { error in
                            ////                                                Text(error.rawValue)
                            ////                                            }
                            //                                        }
                            //                                    } else {
                            //                                        Text(errors[key]!)
                            //                                    }
                            //                                }
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
                .frame(width: 50, height: 50)
            }
        }
        .frame(width: 80)
    }
}

#Preview {
    ItemPreview(state: .init(), item: .init(relative: "IMG_1777.JPG", absolute: "file:///Users/thomvandenbroek/Other/IMG_1777.JPG", isFolder: false))
        .padding()
}
