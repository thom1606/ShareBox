//
//  UploaderViewModel.swift
//  ShareBox
//
//  Created by Thom van den Broek on 14/08/2025.
//

import SwiftUI
import Combine
import UserNotifications
import AppKit

@Observable class UploaderViewModel {
    public static var shared: UploaderViewModel?

    enum UIState: Equatable {
        case hidden
        case small
        case peeking
        case visible
    }

    // Files
    private(set) var droppedItems: [FilePath] = []
    private(set) var uploadProgress: [String: FilePathProgress] = [:]

    // Uploaders
    private let shareBoxUploader = ShareBoxUploader()
    private let airdropUploader = AirdropUploader()
    private let googleDriveUploader = GoogleDriveUploader()
    private let onedriveUploader = OneDriveUploader()
    private let dropboxUploader = DropboxUploader()
    private let icloudUploader = iCloudUploader()

    // Currently active uploader
    private(set) var activeUploader: FileUploader? {
        didSet {
            if let uploader = activeUploader {
                linkUploader(uploader)
            }
        }
    }

    // Preferences
    var mouseListener = MouseListener()
    var keepNotchOpen: Bool = false
    var userInteractable: Bool = false
    var forceVisible: Bool = false

    // Computed
    public var uiState: UIState {
        // Progress based states
        if case .preparingGroup = uploadState { return .visible }
        if case .error = uploadState { return .visible }
        if case .completed = uploadState { return .visible }

        // User activated states
        if (isUserHovering && userInteractable) || forceVisible || (globalContext?.forcePreviewUploader ?? false) {
            if droppedItems.isEmpty && uploadState == .idle { return .small }
            return .visible
        }

        var canFullyClose = true
        if case .uploading = uploadState { canFullyClose = false }
        return canFullyClose ? .hidden : (keepNotchOpen ? .visible : .peeking)
    }
    private(set) var uploadState: UploadState = .idle
    public var uiMovable: Bool {
        var result = true
        if uiState == .visible || uiState == .peeking || uiState == .small {
            result = false
        }
        if !userInteractable { result = false }
        return result
    }
    public var isUserHovering: Bool = false

    // Internal
    private var globalContext: GlobalContext?
    private var uploader: FileUploader?
    private var hasPlayedCompleteSound: Bool = false
    private var completionSound: NSSound? = NSSound(named: NSSound.Name("Glass"))

    // MARK: - Public Methods
    init() {
        UploaderViewModel.shared = self
    }

    public func onAppear(globalContext: GlobalContext) {
        self.globalContext = globalContext
        // Wait for the whole UI to settle in before any user interactions are available
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.userInteractable = true
        }
    }

    // Method to activate a specific uploader by index
    public func activateUploader(for index: UploaderId) {
        switch index {
        case .sharebox:
            activeUploader = shareBoxUploader
        case .airdrop:
            activeUploader = airdropUploader
        case .googleDrive:
            activeUploader = googleDriveUploader
        case .oneDrive:
            activeUploader = onedriveUploader
        case .dropBox:
            activeUploader = dropboxUploader
        case .iCloud:
            activeUploader = icloudUploader
        }
    }

    // Method to get uploader by index (for drop field validation)
    public func getUploader(for index: UploaderId) -> FileUploader {
        switch index {
        case .sharebox:
            return shareBoxUploader
        case .airdrop:
            return airdropUploader
        case .googleDrive:
            return googleDriveUploader
        case .oneDrive:
            return onedriveUploader
        case .dropBox:
            return dropboxUploader
        case .iCloud:
            return icloudUploader
        }
    }

    public func reset() {
        self.droppedItems.removeAll()
        self.forceVisible = false
        self.globalContext?.forcePreviewUploader = false
        self.activeUploader?.reset()
        self.activeUploader = nil
        self.isUserHovering = false
        self.hasPlayedCompleteSound = false
    }

    // MARK: - Private Methods
    private func linkUploader(_ target: FileUploader) {
        self.uploader = target
        Task {
            for await newState in uploader!.stateStream() {
                if newState == .completed {
                    await handleComplete()
                }
                await MainActor.run {
                    self.uploadState = newState
                    if case .error(let error) = newState {
                        // Wait a second for the UI to change to the error state
                        handleFailed(withError: error)
                    }
                }
            }
        }

        Task {
            for await newProgress in uploader!.progressStream() {
                await MainActor.run {
                    self.uploadProgress = newProgress
                }
            }
        }

        Task {
            for await newItems in uploader!.filesStream() {
                await MainActor.run {
                    self.droppedItems = newItems
                }
            }
        }
    }

    private func handleComplete() async {
        if hasPlayedCompleteSound { return }
        completionSound?.play()
        await MainActor.run {
            hasPlayedCompleteSound = true
        }
    }

    private func handleFailed(withError error: PlatformError) {
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
            case .driveUnauthorized:
                self.showDriveUnauthorized()
            default:
                self.showUnknownErrorDialog()
            }
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
        alert.informativeText = String(localized: "You do not have an active subscription. Please upgrade to upload your files to ShareBox.")
        alert.alertStyle = .warning
        alert.window.center()
        alert.window.level = .floating
        alert.window.makeKeyAndOrderFront(nil)
        alert.runModal()
        self.reset()
        self.globalContext?.openSettingsTab(.account)
    }
    private func showUnauthorizedDialog() {
        let alert = NSAlert()
        alert.messageText = String(localized: "Unauthorized")
        alert.informativeText = String(localized: "You are not signed in. Please Sign in to upload files to ShareBox.")
        alert.alertStyle = .warning
        alert.window.center()
        alert.window.level = .floating
        alert.window.makeKeyAndOrderFront(nil)
        alert.runModal()
        self.reset()
        self.globalContext?.openSettingsTab(.account)
    }
    private func showDriveUnauthorized() {
        let alert = NSAlert()
        alert.messageText = String(localized: "Unauthorized")
        alert.informativeText = String(localized: "You need to sign in again to upload files to this drive.")
        alert.alertStyle = .warning
        alert.window.center()
        alert.window.level = .floating
        alert.window.makeKeyAndOrderFront(nil)
        alert.runModal()
        self.reset()
    }
}
