//
//  UploaderViewModel.swift
//  ShareBox
//
//  Created by Thom van den Broek on 14/08/2025.
//

import SwiftUI
import Combine

@Observable class UploaderViewModel {
    var mouseListener = MouseListener()
    // If any interactions are available at the moment
    var canInteract: Bool = true {
        didSet {
            toggleMouseListener()
        }
    }
    // Indicates if the whole UI is currently off screen or not
    var offScreen: Bool = true {
        didSet {
            toggleMouseListener()
        }
    }
    // Active Drag & Drop state indicator
    var isDropTarget: Bool = false
    var didDropFiles: Bool = false
    // How far the notch should be pulled out from the sidebar, value should either be 0 or 1
    var pulloutPercentage: CGFloat = 0
    var overlayImage: String?
    var presentingOverlay: Bool = false
    // To keep track of whether or not to close the file upload, we check for drag & drop what the last state was
    var fileCountBeforeDrop: Int = 0
    // The file which the user picked from their finder, not the actual list of ALL files (this includes the base folders as paths)
    var selectedItems: [FilePath] = []
    // The current group we will be trying to upload towards
    private let apiService = ApiService()
    private var overlayCloseTimer: DispatchWorkItem?

    // Uploading props
    private var waitingContinuations: [CheckedContinuation<BoxDetails, Error>] = []
    private var isCreatingGroup: Bool = false
    private var groupDetails: BoxDetails?
    // Track each file their status, progress and possible error
    var uploadProgress: [String: FilePathProgress] = [:]

    init() {
        Keychain.shared.saveToken("eyJhbGciOiJIUzI1NiJ9.eyJ1c2VySWQiOiIwMDA4MzYuOWNlMzBjODAzNDFkNDY2NGE1ODZhMzIyYWY0ZGEzZjkuMTM0MCIsImV4cCI6MTc1NTI2NjExOX0.5jZwimDvMMnhSc1RW8_vVX4H2pBkZM7Et-wXRO9hXH8", key: "AccessToken")
        Keychain.shared.saveToken("eyJhbGciOiJIUzI1NiJ9.eyJ1c2VySWQiOiIwMDA4MzYuOWNlMzBjODAzNDFkNDY2NGE1ODZhMzIyYWY0ZGEzZjkuMTM0MCIsImV4cCI6MTc4NjgyMjgxOX0.pDmx8Oy4HTrw_WoplLLBsHSIgaFv_ZRZwqZzdZ8T-D4", key: "RefreshToken")
    }

    func startClosingUI() {
        self.offScreen = true
        self.pulloutPercentage = 0
    }

    func onItemsDrop(providers: [NSItemProvider]) -> Bool {
        if !self.canInteract { return false }
        didDropFiles = true

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
                // Don't add duplicates
                if self.selectedItems.contains(where: { $0.absolute == path!.absolute }) { return }
                finalPaths.append(path!)
            }
        }

        // Called after all loadItem calls finish
        group.notify(queue: .main) {
            for path in finalPaths {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.addNewFiles(paths: [path])
                }
            }
            // TODO: add back
//            self.addNewFiles(paths: finalPaths)
        }

        return hasItemWithURL
    }

    func showOverlay(systemName: String, timed: Bool = true) {
        overlayCloseTimer?.cancel()
        overlayImage = systemName
        presentingOverlay = true

        if timed {
            overlayCloseTimer = DispatchWorkItem {
                self.closeOverlay()
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: overlayCloseTimer!)
        }
    }

    func closeOverlay() {
        presentingOverlay = false
    }

    func closeWidget() {
        overlayCloseTimer?.cancel()
        self.groupDetails = nil
        self.fileCountBeforeDrop = 0
        self.pulloutPercentage = 0
        self.offScreen = true
        self.selectedItems.removeAll()
        self.uploadProgress.removeAll()
        self.isCreatingGroup = false
        self.presentingOverlay = false
        self.canInteract = true
        self.didDropFiles = false
    }

    private func toggleMouseListener() {
        if offScreen && canInteract {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if self.offScreen && self.canInteract {
                    self.mouseListener.paused = false
                }
            }
        } else {
            self.mouseListener.paused = true
        }
    }
    
    private func addNewFiles(paths: [FilePath]) {
        self.selectedItems.append(contentsOf: paths)
        Task {
            await uploadNewFiles(paths: paths)
        }
    }

    // Ensure a group is created before any file batcher are to be uploaded
    func ensureGroup() async throws -> BoxDetails {
        if let details = groupDetails {
            return details
        }
        return try await withCheckedThrowingContinuation { continuation in
            waitingContinuations.append(continuation)
            // Make sure only one instance can create a group
            guard !isCreatingGroup else { return }
            isCreatingGroup = true
            // Disable interactions until the group is created
            self.canInteract = false
            self.pulloutPercentage = 1
            self.offScreen = false
            self.closeOverlay()

            Task {
                try? await Task.sleep(for: .seconds(1))
                await UploadBatch.createGroup { result in
                    switch result {
                    case .success(let details):
                        self.groupDetails = details
                        self.isCreatingGroup = false
                        // Resume all waiting tasks
                        self.waitingContinuations.forEach { $0.resume(returning: details) }
                        self.waitingContinuations.removeAll()
                    case .failure(let error):
                        // If the group could not be created, everything should fail, complete lockdown
                        self.isCreatingGroup = false
                        self.waitingContinuations.forEach { $0.resume(throwing: ShareBoxError.noGroupCreated) }
                        self.waitingContinuations.removeAll()

                        dataLogger.error("Group creation failed: \(error.localizedDescription)")
                        // Show alerts to the user which best depict the current failure
                        Task {
                            // Toggle the error overlay
                            self.showOverlay(systemName: "xmark.seal", timed: false)
                            self.pulloutPercentage = 1
                            try? await Task.sleep(for: .seconds(1))
                            await MainActor.run {
                                if let apiError = error as? APIError, case .unauthorized = apiError {
//                                    self.showUnauthorizedDialog()
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

    private func uploadNewFiles(paths: [FilePath]) async {
        if selectedItems.isEmpty { return }
        // Start of by notarizing the current batch so we don't lose track of what is already being handled.
        for path in paths {
            await MainActor.run {
                uploadProgress[path.absolute] = .init(status: .notirized)
            }
        }

        // Wait for the group to be created
        guard let group = try? await ensureGroup() else {
            return
        }
        let batch = UploadBatch(groupId: group.groupId, files: paths, onProgress: { path, fileProgress in
            self.uploadProgress[path] = fileProgress
        })
        // Start the file upload
        await batch.start()
    }

    private func showUnknownErrorDialog() {
        let alert = NSAlert()
        alert.messageText = String(localized: "Upload Failed")
        alert.informativeText = String(localized: "An unknown error occurred while uploading your files. Please try again later.")
        alert.alertStyle = .warning
        alert.window.center()
        alert.window.level = .floating
        alert.window.makeKeyAndOrderFront(nil)
        alert.runModal()
        self.closeWidget()
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
        self.closeWidget()
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
        self.closeWidget()
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
        self.closeWidget()
        // TODO: open login web page
    }
}
