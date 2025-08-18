//
//  UploaderViewModel.swift
//  ShareBox
//
//  Created by Thom van den Broek on 14/08/2025.
//

import SwiftUI
import Combine
import UserNotifications

@Observable class UploaderViewModel {
    enum UIState {
        case hidden
        case peeking
        case visible
    }
    var mouseListener = MouseListener()
    var messageListener: MachMessageListener?
    // Active Drag & Drop state indicator
    var isLiveDropTarget: Bool = false {
        didSet {
            if self.isLiveDropTarget { self.isDropTarget = self.isLiveDropTarget } else {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: { self.isDropTarget = false })
            }
        }
    }
    var isDropTarget: Bool = false
    var isDropzoneHovered: Bool = false
    var isContentHovered: Bool = false
    var showErrorOverlay: Bool = false
    var droppedItems: [FilePath] = []
    var isCreatingGroup: Bool = false
    var forcePeek: Bool = false
    var groupDetails: BoxDetails?
    var showLoadingOverlay: Bool = false
    var openSettingsAction: OpenSettingsAction?

    // Uploading props
    private var waitingContinuations: [CheckedContinuation<BoxDetails, Error>] = []
    // Track each file their status, progress and possible error
    var uploadProgress: [String: FilePathProgress] = [:] {
        didSet {
            if groupDetails == nil || uploadProgress.isEmpty { return }
            // After the batch is done, we check if there are any other open files, if not, the upload is complete and we show the success notification
            var hasOpenStandingProgress = false
            for item in uploadProgress.values where item.status != .completed && item.status != .failed {
                hasOpenStandingProgress = true
            }
            if !hasOpenStandingProgress {
                let boolString = UserDefaults.standard.string(forKey: Constants.Settings.uploadNotificationsPrefKey)
                if boolString == "1" || boolString == nil {
                    Utilities.showNotification(title: String(localized: "ShareBox Uploaded"), body: String(localized: "All your files have been uploaded. Close this Box to copy the link to your clipboard."))
                }
            }
        }
    }

    // Computed Values
    var uiState: UIState {
        if isDropTarget { return .visible }
        if isDropzoneHovered || isContentHovered { return .visible }
        if groupDetails == nil {
            if !droppedItems.isEmpty { return .visible }
        }
        if isCreatingGroup { return .visible }
        if showErrorOverlay { return .visible }
        if !droppedItems.isEmpty { return .peeking }
        if forcePeek { return .peeking }
        return .hidden
    }

    var uiMovable: Bool {
        var result = true
        if uiState == .visible || uiState == .peeking {
            result = false
        }
        if !canInteract { result = false }
        return result
    }

    var hasOngoingUpload: Bool {
        var hasOpenStandingProgress = false
        for item in uploadProgress.values where item.status != .completed && item.status != .failed {
            hasOpenStandingProgress = true
        }
        return hasOpenStandingProgress
    }

    var hasActiveOverlay: Bool {
        isLiveDropTarget || showErrorOverlay || showLoadingOverlay
    }

    var canInteract: Bool {
        var interactable = true
        if isCreatingGroup { interactable = false }
        return interactable
    }

    init() {
        setup()
    }

    /// Setup some additional listeners / values
    private func setup() {
        self.messageListener = MachMessageListener(state: self)
    }

    func onAppear(openSettings: OpenSettingsAction) {
        self.openSettingsAction = openSettings
    }

    /// Support for dropping file items into the app
    func onItemsDrop(providers: [NSItemProvider]) -> Bool {
        if !self.canInteract { return false }
        if self.groupDetails == nil { self.showLoadingOverlay = true }
        // Make sure the UI stays open for the time we check if the files are valid
        var hasItemWithURL = false
        var finalPaths: [FilePath] = []

        let group = DispatchGroup()

        for provider in providers where provider.hasItemConformingToTypeIdentifier("public.file-url") {
            // If even one of the drops works, we will return true for the drag & drop result
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

        // Called after all loadItem calls finish
        group.notify(queue: .main) {
            self.addNewFiles(paths: finalPaths)
            self.isDropTarget = self.isLiveDropTarget
        }
        return hasItemWithURL
    }

    /// Add new files to the uploader
    func addNewFiles(paths: [FilePath]) {
        if paths.isEmpty { return }
        // Filter out all the duplicates
        let nonDuplicatePaths = paths.filter { path in !self.droppedItems.contains(where: { $0.absolute == path.absolute }) }
        if self.groupDetails == nil { self.showLoadingOverlay = true }
        // Append the new files to the array
        self.droppedItems.append(contentsOf: nonDuplicatePaths)
        Task { @MainActor in
            // Start of by notarizing the current batch so we don't lose track of what is already being handled.
            for path in nonDuplicatePaths where !path.isFolder {
                self.uploadProgress[path.absolute] = .init(status: .notarized)
            }

            // Wait for the group to be created
            guard let group = try? await ensureGroup() else {
                // Group creation failed, we will remove these files from the known upload
                self.droppedItems.removeAll(where: nonDuplicatePaths.contains)
                for path in nonDuplicatePaths {
                    self.uploadProgress.removeValue(forKey: path.absolute)
                }
                return
            }
            self.showLoadingOverlay = false
            let batch = UploadBatch(groupId: group.groupId, paths: nonDuplicatePaths, onProgress: { path, fileProgress in
                self.uploadProgress[path] = fileProgress
            })
            // Start the file upload
            await batch.start()
        }
    }

    /// Ensure a group is created before any file batcher are to be uploaded
    func ensureGroup() async throws -> BoxDetails {
        if let details = groupDetails {
            return details
        }
        return try await withCheckedThrowingContinuation { continuation in
            waitingContinuations.append(continuation)
            // Make sure only one instance can create a group
            guard !self.isCreatingGroup else { return }
            self.isCreatingGroup = true
            self.showLoadingOverlay = true

            Task {
                try? await Task.sleep(for: .seconds(1))
                await UploadBatch.createGroup { result in
                    switch result {
                    case .success(let details):
                        self.groupDetails = details
                        self.isCreatingGroup = false
                        self.showLoadingOverlay = false
                        // Resume all waiting tasks
                        self.waitingContinuations.forEach { $0.resume(returning: details) }
                        self.waitingContinuations.removeAll()
                    case .failure(let error):
                        // If the group could not be created, we should show errors regarding the issue and make sure the rest of the file upload progress is cancelled for the batches currently in cirulation
                        self.isCreatingGroup = false
                        self.showErrorOverlay = true
                        self.showLoadingOverlay = false
                        self.waitingContinuations.forEach { $0.resume(throwing: ShareBoxError.noGroupCreated) }
                        self.waitingContinuations.removeAll()

                        dataLogger.error("Group creation failed: \(error.localizedDescription)")
                        // Show alerts to the user which best depict the current failure
                        Task {
                            // Toggle the error overlay
                            try? await Task.sleep(for: .seconds(1))
                            await MainActor.run {
                                if let apiError = error as? APIError, case .unauthorized = apiError {
                                    self.showUnauthorizedDialog()
                                } else if let error = error as? APIError, case .serverError(_, let errorResponse) = error {
                                    if errorResponse.error == "GROUP_LIMIT_REACHED" {
                                        self.showGroupLimiDialog()
                                    } else if errorResponse.error == "SUBSCRIPTION_NOT_FOUND" {
                                        self.showMissingSubscriptionDialog()
                                    } else {
                                        self.showUnknownErrorDialog()
                                    }
                                } else {
                                    self.showUnknownErrorDialog()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    /// Close out the notch and group upload progress
    func closeNotch(reset: Bool = false, notify: Bool = false) {
        // Toggle off options which could be witholding the UI without any user interaction
        self.showErrorOverlay = false
        self.showLoadingOverlay = false
        if reset {
            if notify {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(String(localized: "Hey! I want to share some files with you. You can download them from my ShareBox: \(groupDetails!.url)", comment: "Clipboard message"), forType: .string)

                Utilities.showNotification(title: String(localized: "Link Copied!"), body: String(localized: "The ShareBox link is copied to your clipboard!"))
            }

            self.droppedItems.removeAll()
            self.uploadProgress.removeAll()
            self.groupDetails = nil
        }
    }

    // MARK: - Overlays
    private func showUnknownErrorDialog() {
        let alert = NSAlert()
        alert.messageText = String(localized: "Upload Failed")
        alert.informativeText = String(localized: "An unknown error occurred while uploading your files. Please try again later.")
        alert.alertStyle = .warning
        alert.window.center()
        alert.window.level = .floating
        alert.window.makeKeyAndOrderFront(nil)
        alert.runModal()
        self.closeNotch()
    }
    private func showGroupLimiDialog() {
        let alert = NSAlert()
        alert.messageText = String(localized: "Upload Failed")
        alert.informativeText = String(localized: "You have reached the maximum number of boxes you can create at this time. Please wait for some boxes to expire before creating more.")
        alert.alertStyle = .warning
        alert.window.center()
        alert.window.level = .floating
        alert.window.makeKeyAndOrderFront(nil)
        alert.runModal()
        self.closeNotch()
    }
    private func showMissingSubscriptionDialog() {
        let alert = NSAlert()
        alert.messageText = String(localized: "Upload Failed")
        alert.informativeText = String(localized: "You do not have an active subscription. Please upgrade to upload your files.")
        alert.alertStyle = .warning
        alert.window.center()
        alert.window.level = .floating
        alert.window.makeKeyAndOrderFront(nil)
        alert.runModal()
        self.closeNotch()
        self.openSettingsAction?()
    }
    private func showUnauthorizedDialog() {
        let alert = NSAlert()
        alert.messageText = String(localized: "Unauthorized")
        alert.informativeText = String(localized: "You are not signed in. Please open ShareBox and sign in to upload files.")
        alert.alertStyle = .warning
        alert.window.center()
        alert.window.level = .floating
        alert.window.makeKeyAndOrderFront(nil)
        alert.runModal()
        self.closeNotch()
        // open web url to sign in
        if let domainString = (Bundle.main.object(forInfoDictionaryKey: "BASE_URL") as? String) {
            NSWorkspace.shared.open(URL(string: "\(domainString)/auth/sign-in")!)
        }
    }
}
