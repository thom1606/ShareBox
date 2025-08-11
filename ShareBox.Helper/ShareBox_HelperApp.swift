//
//  ShareBox_HelperApp.swift
//  ShareBox.Helper
//
//  Created by Thom van den Broek on 11/08/2025.
//

import SwiftUI
import ServiceManagement
import os

@main
struct ShareBox_HelperApp: App {
    private let messageListener: MessageListener?
    
    init() {
        // Ensure only one instance of the Helper app is running
        let bundleID = Bundle.main.bundleIdentifier ?? "com.thom1606.ShareBox.Helper"
        
        let runningInstances = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        if runningInstances.count > 1 {
                self.messageListener = nil
            // Another instance is already running, terminate this one
            generalLogger.warning("Another instance of ShareBox Helper is already running. Exiting this instance.")
            NSApp.terminate(nil)
            return
        }
        
        self.messageListener = .init()

        // In release mode we will try and add our helper to the login items
        #if RELEASE
        do {
            if SMAppService.mainApp.status == .notFound {
                try SMAppService.mainApp.register()
            } else {
            }
        } catch {
            generalLogger.warning("Could not register helper as login item: \(error)")
        }
        #endif
        
        // For Development purposes, launch the UI from here
//        DispatchQueue.main.async {
//            UploadWindowController.shared.show(
//                items: [
////                    .init(relative: "favicon.ico", absolute: "file:///Users/thomvandenbroek/Projects/Fooxly/account/packages/client/public/favicon.ico"),
////                    .init(relative: "src", absolute: "file:///Users/thomvandenbroek/Projects/Fooxly/account/packages/client/src/"),
//                    .init(relative: "IMG_1776.JPG", absolute: "file:///Users/thomvandenbroek/Other/IMG_1776.JPG"),
//                    .init(relative: "IMG_1777.JPG", absolute: "file:///Users/thomvandenbroek/Other/IMG_1777.JPG")
//                ]
//            )
//        }
    }

    var body: some Scene {
        Settings {}
    }
}
