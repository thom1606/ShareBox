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
    var canInteract: Bool = true
    // Indicates if the whole UI is currently off screen or not
    var offScreen: Bool = true {
        didSet {
            if offScreen {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    self.mouseListener.paused = false
                }
            } else {
                self.mouseListener.paused = true
            }
        }
    }
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
    // Track each file their status, progress and possible error
    var uploadProgress: [String: (String, CGFloat, [FileError])] = [:] // swiftlint:disable:this large_tuple
    // The current group we will be trying to upload towards
    var groupDetails: CreateGroupResponse?
    private let apiService = ApiService()
    private var goingOffScreenTimer: DispatchWorkItem?
    private var overlayCloseTimer: DispatchWorkItem?
    private var progressCancellables: [String: AnyCancellable] = [:]
    private var uploadQueue: DispatchQueue = DispatchQueue(label: "com.thom1606.ShareBox.uploadQueue", attributes: .concurrent)
    private var uploadSemaphore = DispatchSemaphore(value: 1)
    private var isCreatingGroup: Bool = false
    private var groupCreationFailed: Bool = false

    init() {
        Keychain.shared.saveToken("eyJhbGciOiJIUzI1NiJ9.eyJ1c2VySWQiOiIwMDA4MzYuOWNlMzBjODAzNDFkNDY2NGE1ODZhMzIyYWY0ZGEzZjkuMTM0MCIsImV4cCI6MTc1NTI1NzUyNn0.5-ZBYFj8hMxtvgyeDYsIxIfqs2ukJh3jMw1C3FhUYlw", key: "AccessToken")
        Keychain.shared.saveToken("eyJhbGciOiJIUzI1NiJ9.eyJ1c2VySWQiOiIwMDA4MzYuOWNlMzBjODAzNDFkNDY2NGE1ODZhMzIyYWY0ZGEzZjkuMTM0MCIsImV4cCI6MTc4NjgxNDIyNn0.X678vktD7k-B5O7N5bSRmNZP7ubS6xNSBMJZo-xQ6RQ", key: "RefreshToken")
    }

    func startClosingUI() {
        self.offScreen = true
        self.pulloutPercentage = 0
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
            uploadProgress[item.absolute] = ("notarized", 0, [])
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
                        // If the group could not be created, everything should fail, complete lockdown
                        self?.canInteract = false
                        self?.groupCreationFailed = true
                        self?.isCreatingGroup = false
                        self?.selectedItems.removeAll()
                        self?.uploadProgress.removeAll()

                        dataLogger.error("Group creation failed: \(error.localizedDescription)")

                        Task {
                            try? await Task.sleep(for: .seconds(0.3))
                            await MainActor.run { [weak self] in
                                self?.showOverlay(systemName: "xmark.seal", timed: false)
                                self?.pulloutPercentage = 1
                                if let apiError = error as? APIError, case .unauthorized = apiError {
                                    self?.showUnauthorizedDialog()
                                } else if let error = error as? APIError, case .serverError(_, let errorResponse) = error {
                                    if errorResponse.error == "GROUP_LIMIT_REACHED" {
                                        self?.showGroupLimiDialog()
                                    } else {
                                        self?.showUnknownErrorDialog()
                                    }
                                } else {
                                    self?.showUnknownErrorDialog()
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

    // Create a new group based on the users preference
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

    // Wait for group details to arrive before we can continue, to make sure files are uploaded to the correct group
    private func waitForGroupId() {
        while groupDetails == nil {
            if self.groupCreationFailed { break }
            Thread.sleep(forTimeInterval: 1) // Sleep for 1 second
        }
    }

    // File batches added to the upload queue are handled here
    private func processUploadQueue(_ paths: [FilePath]) {
        uploadQueue.async { [weak self] in
            // Wait for an active group
            self?.waitForGroupId()
            // If the creation failed, we can not continue and an error should have been thrown by the group creation
            if self?.groupCreationFailed ?? false { return }

            if let self = self {
                Task {
                    do {
                        // Start finding all the files which should be uploaded, so deep search folders for child items
                        var folderPaths: [String: [FilePath]] = [:]
                        var fileItems: [FilePath] = []
                        for path in paths {
                            let url = URL(filePath: path.absolute)
                            if url.hasDirectoryPath {
                                // Remove the last folder from the absolutePath
                                let parentUrl = url.deletingLastPathComponent()
                                let basePath = parentUrl.path

                                // For all folders, it should go in and fetch all those children until there are no folders left
                                let files = self.getFiles(basePath: "file://\(basePath)/", url: URL(string: path.absolute)!)
                                folderPaths[path.absolute] = files
                                fileItems.append(contentsOf: files)
                            } else {
                                // Files are added directly to the queue
                                fileItems.append(path)
                            }
                        }

                        // Register the batch with the backend
                        let addFilesResponse: AddFilesResponse = try await self.apiService.post(endpoint: "/api/groups/files/add", parameters: [
                            "groupId": self.groupDetails!.groupId,
                            "files": fileItems.map { item in
                                let details = item.details()
                                return [
                                    "path": details.paths.relative,
                                    "type": details.type,
                                    "size": details.size
                                ]
                            }
                        ])

                        // Go ahead and upload each successfully registered file
                        for key in addFilesResponse.files.keys {
                            guard let currentItem = fileItems.first(where: { $0.relative == key }) else {
                                dataLogger.error("tried to upload file \(key) but it doesn't exist.")
                                continue
                            }
                            // Start uploading each file
                            await self.uploadFile(currentItem, urlString: addFilesResponse.files[key]!)
                        }

                        // Report on all failed files
                        for key in addFilesResponse.failed.keys {
                            let error = addFilesResponse.failed[key]!
                            let absolutePath = fileItems.first(where: { $0.relative == key })?.absolute ?? "/"

                            let itemError: FileError
                            switch error {
                            case "FILE_SIZE_ZERO":
                                itemError = .fileSizeZero
                            case "FILE_SIZE_TOO_LARGE":
                                itemError = .fileToBig
                            case "NO_PRESIGNED_URL":
                                itemError = .noUrlProvided
                            case "UPLOAD_S3_FAILED":
                                itemError = .s3Failed
                            default:
                                itemError = .unknown
                            }
                            self.uploadProgress[absolutePath] = ("failed", 100, [itemError])
                        }
                    } catch {
                        dataLogger.error("Registering files failed: \(error.localizedDescription)")
                        var filesError: FileError = .unknown
                        if let apiError = error as? APIError, case .unauthorized = apiError {
                            filesError = .unauthorized
                        } else if let error = error as? APIError, case .serverError(_, let errorResponse) = error {
                            switch errorResponse.error {
                            case "FILES_SIZE_TOO_LARGE":
                                filesError = .limitReached
                            case "SUBSCRIPTION_NOT_FOUND":
                                filesError = .noSubscription
                            default:
                                break
                            }
                        }
                        // As the registration of files failed, we will apply an error to the whole batch
                        for path in paths {
                            self.uploadProgress[path.absolute] = ("failed", 100, [filesError])
                        }
                    }
                }
            }
        }
    }

    // Upload each single file to the pre-signed url
    private func uploadFile(_ path: FilePath, urlString: String) async {
        let shouldPutOnS3String: String = (Bundle.main.object(forInfoDictionaryKey: "UPLOAD_S3") as? String ?? "true")
        if let shouldPutOnS3 = Bool(shouldPutOnS3String), !shouldPutOnS3 {
            await MainActor.run {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    dataLogger.debug("Skipping upload to S3 as it is disabled by environment.")
                    self.uploadProgress[path.absolute] = ("completed", 100, [])
                }
            }
            return
        }
        do {
            print("Starting file upload for \(path.relative)")
            let fileData = try Data(contentsOf: URL(string: path.absolute)!)
            var request = URLRequest(url: URL(string: urlString)!)
            request.httpMethod = "PUT"

            let fileDetails = path.details()
            // Set Content-Type header to the file's MIME type
            request.setValue(fileDetails.type, forHTTPHeaderField: "Content-Type")
            // Set Content-Length header
            request.setValue("\(fileDetails.size)", forHTTPHeaderField: "Content-Length")

            // Upload the file to the pre-signed url and track the upload progress
            uploadProgress[path.absolute] = ("uploading", 0, [])
            let uploadTask = URLSession.shared.uploadTask(with: request, from: fileData) { [weak self] _, response, error in
                if let error = error {
                    dataLogger.error("Upload failed: \(error.localizedDescription)")
                    self?.uploadProgress[path.absolute] = ("failed", 100, [.unknown])
                } else if let httpResponse = response as? HTTPURLResponse, !(200...299).contains(httpResponse.statusCode) {
                    dataLogger.error("Upload failed with status code: \(httpResponse.statusCode)")
                    self?.uploadProgress[path.absolute] = ("failed", 100, [.unknown])
                } else {
                    dataLogger.debug("Upload completed successfully")
                    self?.uploadProgress[path.absolute] = ("completed", 100, [])
                }
            }
            progressCancellables[path.absolute] = uploadTask.progress.publisher(for: \.fractionCompleted)
                .receive(on: DispatchQueue.main).sink { [weak self] fraction in
                    DispatchQueue.main.async {
                        self?.uploadProgress[path.absolute] = ("uploading", fraction * 100, [])
                    }
            }
            uploadTask.resume()
        } catch {
            print("errrrr", error.localizedDescription)
            // TODO: catch errors
        }
    }

    // Get files within the given folder path and convert them to FilePath's
    private func getFiles(basePath: String, url: URL) -> [FilePath] {
        var files: [FilePath] = []
        let fileManager = FileManager.default
        var options: FileManager.DirectoryEnumerationOptions = []
        if !userDefaults.bool(forKey: Constants.Settings.hiddenFilesPrefKey) {
            options = [.skipsHiddenFiles]
        }
        let contents = try? fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: options)
        for content in contents ?? [] {
            if content.hasDirectoryPath {
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

struct CreateGroupResponse: Codable {
    var groupId: String
    var url: String
}

private struct AddFilesResponse: Codable {
    var files: [String: String]
    var failed: [String: String]
}
