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
        menu.addItem(withTitle: NSLocalizedString("Upload to ShareBox (Dev)", comment: "Finder Context Menu Label"), action: #selector(handleFileSelection(_:)), keyEquivalent: "")
        return menu
    }

    @IBAction func handleFileSelection(_: AnyObject?) {
        // Make sure we have all the required data to proceed
        guard let items = FIFinderSyncController.default().selectedItemURLs() else {
            Utilities.showNotification(
                title: NSLocalizedString("Oops!", comment: ""),
                body: NSLocalizedString("No files or folders selected? Please try again after selecting items.", comment: "If ShareBox ever gets triggered without files or folders selected.")
            )
            finderLogger.warning("ShareBox Upload was triggered without any files or folders selected. This should never be the case.")
            return
        }
        // Initiate the upload to the helper app
        uploadFiles(items: items)
    }

    private func uploadFiles(items: [URL]) {
        finderLogger.debug("Found items to upload, trying to get everything ready...")

        // Create request for Mach
        let req: MachFileUploadBody = .init(
            items: items.map {
                $0.toFilePath()
            }
        )

        // Check if the main app is running
        if !NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == "com.thom1606.ShareBox" }) {
            // Start the main app
            NSWorkspace.shared.open(URL(string: "sharebox://")!)
            // Wait for the main app to be running
            while !NSWorkspace.shared.runningApplications.contains(where: { $0.bundleIdentifier == "com.thom1606.ShareBox" }) {
                sleep(1)
            }
        }

        do {
            finderLogger.debug("Request for mach created, sending packet to uploader...")
            _ = try MachMessenger.shared.send(MachMessage(type: .fileUploadRequest, data: req.encode()))
            // Everything should be cool, we are done here
            finderLogger.debug("Task successfully sent to the ShareBox Uploader, handling everything from there.")
        } catch {
            Utilities.showNotification(
                title: NSLocalizedString("Oops!", comment: ""),
                body: NSLocalizedString("Something went wrong internally, please try again.", comment: "")
            )
            finderLogger.error("Failed to create Mach message for file upload request, encoding failed. Aborting upload.")
        }
    }
}
