//
//  UploaderViewModel.swift
//  ShareBox
//
//  Created by Thom van den Broek on 14/08/2025.
//

import SwiftUI

@Observable class UploaderViewModel {
    var mouseListener = MouseListener()
    // If any interactions are available at the moment
    var canInteract: Bool = true
    // Indicates if the whole UI is currently off screen or not
    var offScreen: Bool = true
    // Active Drag & Drop state indicator
    var isDropTarget: Bool = false
    // How far the notch should be pulled out from the sidebar, value should either be 0 or 1
    var pulloutPercentage: CGFloat = 0
    var overlayImage: String?
    var presentingOverlay: Bool = false
    // To keep track of whether or not to close the file upload, we check for drag & drop what the last state was
    var fileCountBeforeDrop: Int = 0
    // The items currently being uploaded
    var selectedItems: [FilePath] = [] {
        didSet {
            uploadNewFiles()
        }
    }
    // Track each file their status and progress
    var uploadProgress: [String: (String, Int)] = [:]
    // The current group we will be trying to upload towards
    var groupDetails: CreateGroupResponse?
    private let apiService = ApiService()
    private var goingOffScreenTimer: DispatchWorkItem?
    private var overlayCloseTimer: DispatchWorkItem?
    private var uploadQueue: DispatchQueue = DispatchQueue(label: "com.thom1606.ShareBox.uploadQueue", attributes: .concurrent)
    private var uploadSemaphore = DispatchSemaphore(value: 1)
    private var isCreatingGroup: Bool = false
    private var groupCreationFailed: Bool = false

    func startClosingUI() {
        goingOffScreenTimer?.cancel()
        goingOffScreenTimer = DispatchWorkItem {
            self.offScreen = true
            self.pulloutPercentage = 0
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: goingOffScreenTimer!)
    }

    func stopClosingUI() {
        goingOffScreenTimer?.cancel()
    }

    func onItemsDrop(providers: [NSItemProvider]) -> Bool {
        if !self.canInteract { return false }
        var hasURL = false
        for provider in providers where provider.hasItemConformingToTypeIdentifier("public.file-url") {
            hasURL = true
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { (item, _) in
                var path: FilePath?
                if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                    path = .init(relative: url.lastPathComponent, absolute: url.absoluteString, isFolder: url.hasDirectoryPath)
                } else if let url = item as? URL {
                    path = .init(relative: url.lastPathComponent, absolute: url.absoluteString, isFolder: url.hasDirectoryPath)
                }

                if path == nil { return }
                // Don't add duplicates
                if self.selectedItems.contains(where: { $0.absolute == path!.absolute }) { return }
                self.selectedItems.append(path!)
            }
        }
        return hasURL
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
        goingOffScreenTimer?.cancel()
        overlayCloseTimer?.cancel()
        self.groupDetails = nil
        self.fileCountBeforeDrop = 0
        self.pulloutPercentage = 0
        self.offScreen = true
        self.selectedItems.removeAll()
        self.uploadProgress.removeAll()
        self.isCreatingGroup = false
        self.presentingOverlay = false
        self.groupCreationFailed = false
        self.canInteract = true
    }

    private func uploadNewFiles() {
        if selectedItems.isEmpty { return }
        // Start of by notarizing the current batch so we don't lose track of what is already being handled.
        var pathsToHandle: [FilePath] = []
        for item in selectedItems where !uploadProgress.keys.contains(item.absolute) {
            pathsToHandle.append(item)
            uploadProgress[item.absolute] = ("notarized", 0)
        }
        // If no group yet exists, we will start this one off by creating a group for other batches to use
        if groupDetails == nil && !isCreatingGroup {
            isCreatingGroup = true
            Task {
                await createGroup { [weak self] result in
                    switch result {
                    case .success(let groupDetails):
                        self?.groupDetails = groupDetails
                        self?.isCreatingGroup = false
                        self?.processUploadQueue(pathsToHandle)
                    case .failure(let error):
                        // If the group could not be created, everything should fail
                        self?.canInteract = false
                        self?.groupCreationFailed = true
                        self?.isCreatingGroup = false
                        self?.selectedItems.removeAll()
                        self?.uploadProgress.removeAll()

                        Task {
                            try? await Task.sleep(for: .seconds(0.3))
                            await MainActor.run { [weak self] in
                                self?.showOverlay(systemName: "xmark.seal", timed: false)
                                self?.pulloutPercentage = 1
                                if let apiError = error as? APIError, case .unauthorized = apiError {
                                    print("Unauthorized")
                                    let alert = NSAlert()
                                    alert.messageText = String(localized: "Unauthorized")
                                    alert.informativeText = String(localized: "You are not signed in. Please open ShareBox and sign in to upload files.")
                                    alert.alertStyle = .warning
                                    alert.window.center()
                                    alert.window.level = .floating
                                    alert.window.makeKeyAndOrderFront(nil)
                                    alert.runModal()

                                    self?.closeWidget()
                                } else if let error = error as? APIError, case .serverError(_, let errorResponse) = error {
                                    print("known error occured", errorResponse.error)
                                } else {
                                    print("Unknown error occured", error.localizedDescription)
                                }
                            }
                        }
                    }
                }
            }
        } else {
            // Start the batch as an group should be on it's way
            processUploadQueue(pathsToHandle)
        }
    }

    private func createGroup(completion: @escaping (Result<CreateGroupResponse, Error>) -> Void) async {
        // Start creating the group
        do {
            let password = userDefaults.string(forKey: Constants.Settings.passwordPrefKey)
            let storageDuration = userDefaults.string(forKey: Constants.Settings.storagePrefKey) ?? "3_days"

            let createdGroupResponse: CreateGroupResponse = try await self.apiService.post(endpoint: "/api/groups", parameters: [
                "password": password,
                "expires_in": storageDuration
            ])
            completion(.success(createdGroupResponse))
        } catch {
            completion(.failure(error))
        }
    }

    private func waitForGroupId() {
        while groupDetails == nil {
            if self.groupCreationFailed { break }
            Thread.sleep(forTimeInterval: 1) // Sleep for 1 second
        }
    }

    private func processUploadQueue(_ paths: [FilePath]) {
        if self.groupCreationFailed { return }
        for path in paths {
            uploadQueue.async { [weak self] in
                self?.waitForGroupId()
                if (self?.groupCreationFailed ?? false) { return }
                self?.uploadFile(path)
            }
        }
    }

    private func uploadFile(_ path: FilePath) {
        // Simulate file upload
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
            print("Uploaded file: \(path.absolute)")
        }
    }
}

struct CreateGroupResponse: Codable {
    var groupId: String
    var url: String
}
