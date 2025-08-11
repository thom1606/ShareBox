//
//  FinderSync.swift
//  ShareBox.Finder
//
//  Created by Thom van den Broek on 11/08/2025.
//

import Cocoa
import FinderSync
import os

class FinderSync: FIFinderSync {
    override init() {
        super.init()

        let finderSync = FIFinderSyncController.default()
        if let mountedVolumes = FileManager.default.mountedVolumeURLs(includingResourceValuesForKeys: nil, options: [.skipHiddenVolumes]) {
            finderSync.directoryURLs = Set<URL>(mountedVolumes)
        }
        let notificationCenter = NSWorkspace.shared.notificationCenter
        notificationCenter.addObserver(forName: NSWorkspace.didMountNotification, object: nil, queue: .main) { notification in
            if let volumeURL = notification.userInfo?[NSWorkspace.volumeURLUserInfoKey] as? URL {
                finderSync.directoryURLs.insert(volumeURL)
            }
        }
    }
    
    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        if menuKind == .toolbarItemMenu { return nil }
        // Produce a menu for the extension.
        let menu = NSMenu(title: "")
        menu.addItem(withTitle: NSLocalizedString("Upload to ShareBox", comment: "Finder Context Menu Label"), action: #selector(handleFileSelection(_:)), keyEquivalent: "")
        return menu
    }
    
    @IBAction func handleFileSelection(_ sender: AnyObject?) {
        // Make sure we have all the required data to proceed
        guard let items = FIFinderSyncController.default().selectedItemURLs(), let target = FIFinderSyncController.default().targetedURL() else {
            Utilities.showNotification(
                title: NSLocalizedString("Oops!", comment: ""),
                body: NSLocalizedString("No files or folders selected? Please try again after selecting items.", comment: "If ShareBox Ever get's triggered without files or folders selected.")
            )
            finderLogger.warning("ShareBox Upload was triggered without any files or folders selected. This should never be the case.")
            return
        }
        
        // Initiate the upload to the helper app
        uploadFiles(items: items, target: target)
    }
    
    private func uploadFiles(items: [URL], target: URL, retry: Bool = false) {
        finderLogger.debug("Found items to upload, trying to get everything ready...")
        
        // Create request for Mach
        let req: FileUploadBody = .init(
            items: items.map { .init(relative: $0.absoluteString.replacingOccurrences(of: target.absoluteString, with: ""), absolute: $0.absoluteString) }
        )
        guard let mach = MachMessage(type: .fileUploadRequest, data: req.encode()).encode() else {
            Utilities.showNotification(
                title: NSLocalizedString("Oops!", comment: ""),
                body: NSLocalizedString("Something went wrong internally, please try again.", comment: "")
            )
            finderLogger.error("Failed to create Mach message for file upload request, encoding failed. Aborting upload.")
            return
        }
        
        finderLogger.debug("Request for mach created, trying to start the connection...")
        // Submit the paths to the helper
        guard let remotePort = CFMessagePortCreateRemote(nil, Constants.Mach.portName as CFString) else {
            do {
                if retry {
                    throw ShareBoxError.failedExecute("Failed to startup ShareBox Helper. Even after retry, it is not running.")
                } else {
                    finderLogger.error("Unable to connect to the ShareBox Helper Remote Port using Mach, trying to launch helper.")
                    // Try and launch the helper to save this upload request
                    try Utilities.launchHelperApp()
                    finderLogger.info("Finder has started the helper, trying to submit data again...")
                    // Looks good, retry upload once
                    uploadFiles(items: items, target: target, retry: true)
                    return
                }
            } catch {
                Utilities.showNotification(
                    title: NSLocalizedString("Oops!", comment: ""),
                    body: NSLocalizedString("The ShareBox Helper is not running, please try again.", comment: "")
                )
                finderLogger.error("Helper connection failed: \(error.localizedDescription)")
            }
            return
        }
        
        finderLogger.debug("Correctly connected to the Helper app Remote Port, sending request...")
        
        let messageID: Int32 = 0x1111
        let timeout: CFTimeInterval = 1.0
        
        var returnData: Unmanaged<CFData>?
        let status = CFMessagePortSendRequest(remotePort, messageID, mach, timeout, timeout, CFRunLoopMode.defaultMode.rawValue, &returnData)
        if status == kCFMessagePortSuccess, let data = returnData?.takeRetainedValue() as Data? {
            if let response = try? JSONDecoder().decode([String: String].self, from: data),
               response["status"] == "busy" {
                Utilities.showNotification(
                    title: NSLocalizedString("Oops!", comment: ""),
                    body: NSLocalizedString("An upload is already active, please wait for it to finish.", comment: "")
                )
                finderLogger.warning("Another ShareBoxis already active, user should try again after.")
                return
            }
            finderLogger.debug("Task successfully sent to the Helper app, handling everything from there.")
        } else {
            Utilities.showNotification(
                title: NSLocalizedString("Oops!", comment: ""),
                body: NSLocalizedString("Failed to start the upload request with the Helper App, please make sure it is running!", comment: "")
            )
            finderLogger.error("Failed to send the message to the Helper app, status: \(status)")
        }
    }
}

