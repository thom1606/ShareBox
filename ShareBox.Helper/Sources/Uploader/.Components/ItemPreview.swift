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
    var path: String
    var completed: Bool
    var error: String?
    
    // Local properties
    private var icon: NSImage?
    private var name: String
    private var isImage: Bool
    private var imagePreview: NSImage?
    
    @State private var showErrorPopover: Bool = false

    init(path: String, completed: Bool = false, error: String? = nil) {
        self.path = path
        self.completed = completed
        self.error = error

        // Use URL to properly decode percent-encoded file paths
        let fileURL: URL
        if let url = URL(string: path), url.isFileURL {
            fileURL = url
        } else {
            fileURL = URL(fileURLWithPath: path)
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
            .opacity(completed && error == nil ? 1 : 0.4)
            
            // Failed overlay
            if error != nil {
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
                            Text("Your item named \"\(name)\" has failed to upload and gave the following error:")
                                .multilineTextAlignment(.leading)
                                .font(.body)
                                .padding(.top, 3)
                                .padding(.bottom, 5)
                                .foregroundStyle(.primary)
                            Text(error!)
                                .font(.body)
                                .foregroundStyle(.tertiary)
                        }
                        .frame(minWidth: 200, idealWidth: 200, maxWidth: 200)
                        .padding(10)
                }
                .onHover { isOver in
                    showErrorPopover = isOver
                }
                .frame(maxWidth: .infinity)
                .frame(height: 40)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ItemPreview(path: "file:///Users/thomvandenbroek/Projects/TryOut/SwiftyXPC/Example%20App/")
}
