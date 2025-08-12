//
//  UploadViewModel.swift
//  ShareBox.Helper
//
//  Created by Thom van den Broek on 11/08/2025.
//

import SwiftUI

@MainActor
@Observable class UploadViewModel {
    private let apiService = ApiService()

    var items: [FilePath] = []
    // If the whole window should be off screen
    var hidden: Bool = true
    // How far out the notch should be visible, number between 0 and 1
    var notchPercentage: CGFloat = 0
    // The percentage of items/progress made in the upload, number between 0 and 100
    var uploadProgress: CGFloat = 0
    var showCompleteOverlay: Bool = false
    var showFailedOverlay: Bool = false
    var showProgressbar: Bool = true
    var showClose: Bool = false
    
    var completedPaths: [String] = []
    var failedPaths: [String: String] = [:]
    
    public func handleAppear(_ items: [FilePath]) async {
        self.items = items
        SharedValues.isProcessing = true

        do {
            withAnimation(.spring(duration: 0.3)) {
                self.hidden = false
                // TODO: check if we want to fully extend the notch at the start or not (user setting)
                self.notchPercentage = 1
            }
            
            dataLogger.debug("Starting upload...")

            let password = userDefaults.string(forKey: Constants.Settings.passwordPrefKey)
            let storageDuration = userDefaults.string(forKey: Constants.Settings.storagePrefKey) ?? "3_days"

            // Start creating the group
            let createdGroupResponse: CreateGroupResponse = try await self.apiService.post(endpoint: "/api/groups", parameters: [
                "password": password,
                "expires_in": storageDuration
            ])

            dataLogger.debug("Created group with id '\(createdGroupResponse.groupId)' with url '\(createdGroupResponse.url)'")
            uploadProgress = 5
            
            var folderPaths: [String: [FilePath]] = [:]
            
            // Start finding all the files which should be uploaded, so deep search folders for child items
            var fileItems: [FilePath] = []
            for item in items {
                let url = URL(filePath: item.absolute)

                // Treat .app and .appex bundles as files, not folders
                let isDir = Files.isDirectory(path: url)
                

                if isDir {
                    // Remove the last folder from the absolutePath
                    let parentUrl = url.deletingLastPathComponent()
                    let basePath = parentUrl.path
                    

                    // For all folders, it should go in and fetch all those children until there are no folders left
                    let files = getFiles(basePath: "file://\(basePath)/", url: URL(string: item.absolute)!)
                    folderPaths[item.absolute] = files
                    fileItems.append(contentsOf: files)
                } else {
                    // Files are added directly to the queue
                    fileItems.append(item)
                }
            }

            dataLogger.debug("Mapped all files to local paths and ready for upload...")

            let addFilesResponse: AddFilesResponse = try await self.apiService.post(endpoint: "/api/groups/files/add", parameters: [
                "groupId": createdGroupResponse.groupId,
                "files": fileItems.map { item in
                    let details = item.details()
                    return [
                        "path": details.paths.relative,
                        "type": details.type,
                        "size": details.size
                    ]
                }
            ])
            
            dataLogger.debug("Registered current selection of files to the group...")
            uploadProgress = 9
                        
            // Update the last 90% of the uploadProgress based on the amount of files failed with the totalCount (keep 1% left for finishing)
            let totalCount = CGFloat(fileItems.count)
            let perFileProgress: CGFloat = 90 / totalCount
            var finalFailed: [String: String] = addFilesResponse.failed

            for key in addFilesResponse.files.keys {
                try? await Task.sleep(for: .milliseconds(300))
                do {
                    guard let currentItem = fileItems.first(where: { $0.relative == key }) else {
                        throw ShareBoxError.fileNotFound
                    }
                    
                    let shouldPutOnS3String: String = (Bundle.main.object(forInfoDictionaryKey: "UPLOAD_S3") as? String ?? "true")
                    if let shouldPutOnS3 = Bool(shouldPutOnS3String), !shouldPutOnS3 {
                        dataLogger.debug("Skipping upload to S3 as it is disabled by environment.")
                        uploadProgress += perFileProgress
                        completedPaths.append(currentItem.absolute)
                        
                        // If the file is part of a folder, we want to make sure to keep updating the parent folder progress
                        for key in folderPaths.keys {
                            folderPaths[key] = folderPaths[key]?.filter { $0.absolute != currentItem.absolute }
                            if folderPaths[key]!.isEmpty {
                                completedPaths.append(key)
                            }
                        }
                        continue
                    }
                    
                    let fileData = try Data(contentsOf: URL(string: currentItem.absolute)!)
                    var request = URLRequest(url: URL(string: addFilesResponse.files[key]!)!)
                    request.httpMethod = "PUT"
                    request.httpBody = fileData
                    let fileDetails = currentItem.details()
                    // Set Content-Type header to the file's MIME type
                    request.setValue(fileDetails.type, forHTTPHeaderField: "Content-Type")
                    // Set Content-Length header
                    request.setValue("\(fileDetails.size)", forHTTPHeaderField: "Content-Length")

                    let (_, response) = try await URLSession.shared.data(for: request)
                    if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                        throw ShareBoxError.fileNotUploaded
                    } else {
                        dataLogger.debug("File \(currentItem.relative) uploaded to ShareBox")
                    }
                    completedPaths.append(currentItem.absolute)
                    uploadProgress += perFileProgress
                    
                    // If the file is part of a folder, we want to make sure to keep updating the parent folder progress
                    for key in folderPaths.keys {
                        folderPaths[key] = folderPaths[key]?.filter { $0.absolute != currentItem.absolute }
                        if folderPaths[key]!.isEmpty {
                            completedPaths.append(key)
                        }
                    }
                } catch {
                    if let error = error as? ShareBoxError, case .fileNotFound = error {
                        dataLogger.error("tried to upload file \(key) but it doesn't exist.")
                    // TODO: catch some more errors for better support cases
                    } else {
                        let currentItem = fileItems.first(where: { $0.relative == key })!
                        finalFailed[currentItem.relative] = "UPLOAD_S3_FAILED"
                    }
                }
            }

            if !finalFailed.isEmpty {
                dataLogger.debug("Handled all the valid files, now handling failed ones...")
                for key in finalFailed.keys {
                    let apiError = finalFailed[key]!
                    let absolutePath = fileItems.first(where: { $0.relative == key })?.absolute ?? "/"
    
                    switch apiError {
                    case "FILE_SIZE_ZERO":
                        failedPaths[absolutePath] = "Error 1002: File size is zero"
                        break
                    case "FILE_SIZE_TOO_LARGE":
                        failedPaths[absolutePath] = "Error 1003: File size is to big"
                        break
                    case "NO_PRESIGNED_URL":
                        failedPaths[absolutePath] = "Error 1004: No pre-signed url available"
                        break
                    case "UPLOAD_S3_FAILED":
                        failedPaths[absolutePath] = "Error 1005: Uploading to S3 failed"
                        break
                    default:
                        failedPaths[absolutePath] = "Error 1001: Unknown API error"
                        break
                    }
                    completedPaths.append(absolutePath)
                    uploadProgress += perFileProgress
                }
            }

            // Complete the upload by changing UI
            uploadProgress = 100
            withAnimation(.spring(duration: 0.3)) {
                // Extend the UI for completion
                self.notchPercentage = 1
            }

            try? await Task.sleep(for: .milliseconds(200))
            
            // Show overlay to transition UI and notify user that the upload is done
            self.showCompleteOverlay = true
            
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(NSLocalizedString("Hey! I want to share some files with you. You can download them from my ShareBox: \(createdGroupResponse.url)", comment: "Clipboard message"), forType: .string)

            Notifications.show(
                title: "ShareBox Created",
                body: "Your files have been uploaded and the link is copied to your clipboard!"
            )
            
            try? await Task.sleep(for: .milliseconds(3000))
            
            // Show the end UI with final upload result
            self.showProgressbar = false
            self.showClose = true
            self.showCompleteOverlay = false
        } catch {
            dataLogger.error("Upload failed: \(error.localizedDescription)")
            // Check if error is APIError and matches unauthorized case
            if let apiError = error as? APIError, case .unauthorized = apiError {
                self.showFailedOverlay = true
                let alert = NSAlert()
                alert.messageText = "Unauthorized"
                alert.informativeText = "You are currently not signed in, please open ShareBox and sign in to upload files."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Open")
                alert.addButton(withTitle: "Cancel")
                alert.window.center()
                alert.window.level = .floating
                alert.window.makeKeyAndOrderFront(nil)
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    self.openMainApp()
                }
                // After opening the window, we will stop this upload attempt
                self.hideWindow()
            // TODO: catch some different kind of errors if possible/needed
            } else {
                self.showFailedOverlay = true
                let alert = NSAlert()
                alert.messageText = "Upload Failed"
                alert.informativeText = "An unknown error occured whist uploading your files. Please try again later."
                alert.alertStyle = .informational
                alert.addButton(withTitle: "Ok")
                alert.window.center()
                alert.window.level = .floating
                alert.window.makeKeyAndOrderFront(nil)
                alert.runModal()
                self.hideWindow()
            }
        }
    }
    
    public func hideWindow() {
        withAnimation(.spring(duration: 0.3)) {
            self.hidden = true
            self.notchPercentage = 0
        }
        Task {
            try? await Task.sleep(for: .milliseconds(200))
            self.resetState()
        }
    }
    
    /// Open the main ShareBox Application for the user to handle stuff on there
    public func openMainApp() {
        let helperBundleURL = Bundle.main.bundleURL
        let helperPath = helperBundleURL.path

        let mainAppURL: URL
        if helperPath.contains("/Resources/ShareBox.Helper.app") {
            mainAppURL = helperBundleURL
                .deletingLastPathComponent() // Resources
                .deletingLastPathComponent() // Contents
                .deletingLastPathComponent() // ShareBox.app
        } else {
            mainAppURL = helperBundleURL
                .deletingLastPathComponent()
                .appendingPathComponent("ShareBox.app", conformingTo: .application)
        }
        NSWorkspace.shared.open(mainAppURL)
    }

    /// Reset everything back to the initial state ready for new file uploads
    private func resetState() {
        self.hidden = true
        self.notchPercentage = 0
        self.uploadProgress = 0
        self.showCompleteOverlay = false
        self.showFailedOverlay = false
        self.showProgressbar = true
        // TODO: later always show to cancel upload in V2
        self.showClose = false
        self.items = []
        self.completedPaths = []
        self.failedPaths = [:]
        // An upload is done once the window has been closed, until then the user is still busy with the current one
        // This is also for future support of adding files to a box
        SharedValues.isProcessing = false
    }
    
    // Fetch files and folders from a folder
    private func getFiles(basePath: String, url: URL) -> [FilePath] {
        var files: [FilePath] = []
        let fileManager = FileManager.default
        var options: FileManager.DirectoryEnumerationOptions = []
        if !userDefaults.bool(forKey: Constants.Settings.hiddenFilesPrefKey) {
            options = [.skipsHiddenFiles]
        }
        let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: options)
        for content in contents ?? [] {
            let lowercasedPath = content.path.lowercased()
            let isBundleFile = lowercasedPath.hasSuffix(".app") || lowercasedPath.hasSuffix(".appex") || lowercasedPath.hasSuffix(".xpc")
            if content.hasDirectoryPath && !isBundleFile {
                let childFiles = getFiles(basePath: basePath, url: content)
                files.append(contentsOf: childFiles)
            } else {
                files.append(.init(
                    relative: content.absoluteString.replacingOccurrences(of: basePath, with: ""),
                    absolute: content.absoluteString,
                    isFolder: false
                ))
            }
        }
        return files
    }
}

private struct CreateGroupResponse: Codable {
    var groupId: String
    var url: String
}

private struct AddFilesResponse: Codable {
    var files: [String: String]
    var failed: [String: String]
}
