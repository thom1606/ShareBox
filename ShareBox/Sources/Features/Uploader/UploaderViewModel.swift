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
    public static var shared: UploaderViewModel?
    private var machListener: MachMessageListener?

    enum UIState: Equatable {
        case hidden
        case peeking
        case visible
    }

    // Files
    private(set) var droppedItems: [FilePath] = []
    private(set) var uploadProgress: [String: FilePathProgress] = [:]

    // Preferences
    var mouseListener = MouseListener()
    var keepNotchOpen: Bool = false
    var userInteractable: Bool = false
    var forceVisible: Bool = false
    var forcePreviewVisible: Bool = false

    // Computed
    var isDropTarget: Bool = false
    public var uiState: UIState {
        // User activated states
        if forcePreviewVisible { return .visible }
        if forceVisible { return .visible }
        if isDropTarget { return .visible }
        if isUserHovering && userInteractable { return .visible }

        // Progress based states
        if case .preparingGroup = uploadState { return .visible }
        if case .error = uploadState { return .visible }
        if case .completed = uploadState { return .visible }

        var canFullyClose = true
        if case .uploading = uploadState { canFullyClose = false }
        return canFullyClose ? .hidden : (keepNotchOpen ? .visible : .peeking)
    }
    private(set) var uploadState: UploadState = .idle
    public var uiMovable: Bool {
        var result = true
        if uiState == .visible || uiState == .peeking {
            result = false
        }
        if !userInteractable { result = false }
        return result
    }
    public var hasActiveOverlay: Bool {
        if case .error = uploadState { return true }
        if isDropTarget { return true }
        if case .preparingGroup = uploadState { return true }
        return false
    }

    // Internal
    private var closeOverlayWorkItem: DispatchWorkItem?
    private var isUserHovering: Bool = false
    private let uploader = UploadService()

    // MARK: - Public Methods
    init() {
        UploaderViewModel.shared = self
        self.machListener = MachMessageListener(state: self)

        Task {
            for await newState in await uploader.stateStream() {
                await MainActor.run {
                    self.uploadState = newState
                    if case .error(let error) = newState {
                        // Wait a second for the UI to change to the error state
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
                            guard let self = self else { return }
                            switch error {
                            case .unauthorized:
                                self.showUnauthorizedDialog()
                            case .groupLimitReached:
                                self.showGroupLimiDialog()
                            case .noSubscription:
                                self.showMissingSubscriptionDialog()
                            default:
                                self.showUnknownErrorDialog()
                            }
                        }
                    }
                    if case .completed = newState {
                        let boolString = UserDefaults.standard.string(forKey: Constants.Settings.uploadNotificationsPrefKey)
                        if boolString == "1" || boolString == nil {
                            Utilities.showNotification(title: String(localized: "ShareBox Uploaded"), body: String(localized: "All your files have been uploaded. Close this Box to copy the link to your clipboard."))
                        }
                    }
                }
            }
        }

        Task {
            for await newProgress in await uploader.progressStream() {
                await MainActor.run {
                    self.uploadProgress = newProgress
                }
            }
        }
    }

    public func onAppear() {
        // Wait for the whole UI to settle in before any user interactions are available
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.userInteractable = true
        }
    }

    public func onItemsDrop(providers: [NSItemProvider]) -> Bool {
        if self.uploadState == .preparingGroup { return false }
        if !self.userInteractable { return false }
        var hasItemWithURL = false
        var finalPaths: [FilePath] = []

        let group = DispatchGroup()

        // Keep the UI forced open for the small split second it takes to proces these url's, after that the normal uploader progress will take over.
        self.forceVisible = true

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
            Task {
                // Everything is done processing, let the uploader take over the UI again
                self.forceVisible = false
                await self.appendFiles(finalPaths)
            }
        }
        return hasItemWithURL
    }

    /// Handle user hover interactions
    public func onHover(isOver: Bool) {
        if isOver {
            // If the UI is currently not user interactable, we won't listen
            if !self.userInteractable {
                return
            }
            // Cancel any pending close
            closeOverlayWorkItem?.cancel()
            closeOverlayWorkItem = nil
            // Show overlay immediately
            self.isUserHovering = true
        } else {
            self.forcePreviewVisible = false
            // Schedule closing after 0.5 seconds
            let workItem = DispatchWorkItem { [weak self] in
                self?.isUserHovering = false
            }
            closeOverlayWorkItem = workItem
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1, execute: workItem)
        }
    }

    public func appendFiles(_ paths: [FilePath]) async {
        // Filter out all the duplicates
        let nonDuplicatePaths = paths.filter { path in !self.droppedItems.contains(where: { $0.absolute == path.absolute }) }
        self.droppedItems.append(contentsOf: nonDuplicatePaths)
        try? await self.uploader.append(paths)
    }

    /// Notify the user that the group is being closed and the details are copied to the clipboard
    public func gracefullyClose() {
        Task {
            guard let groupUrlString = await uploader.groupDetails?.url else {
                return
            }
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(String(localized: "Hey! I want to share some files with you. You can download them from my ShareBox: \(groupUrlString)", comment: "Clipboard message"), forType: .string)

            Utilities.showNotification(title: String(localized: "Link Copied!"), body: String(localized: "The ShareBox link is copied to your clipboard!"))
        }
        self.reset()
    }

    // MARK: - Private Methods
    private func reset() {
        self.droppedItems.removeAll()
        self.forceVisible = false
        Task {
            await self.uploader.reset()
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
        self.reset()
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
        self.reset()
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
        self.reset()
//        self.openSettingsAction?()
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
        self.reset()
        // open web url to sign in
        if let domainString = (Bundle.main.object(forInfoDictionaryKey: "BASE_URL") as? String) {
            NSWorkspace.shared.open(URL(string: "\(domainString)/auth/sign-in")!)
        }
    }
}
