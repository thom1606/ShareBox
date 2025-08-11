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
    init() {
        
            // Ensure only one instance of the Helper app is running
            let bundleID = Bundle.main.bundleIdentifier ?? "com.thom1606.ShareBox.Helper"
            
            let runningInstances = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            if runningInstances.count > 1 {
//                self.messageListener = nil
                // Another instance is already running, terminate this one
                generalLogger.warning("Another instance of HelperApp is already running. Exiting this instance.")
                NSApp.terminate(nil)
                return
            }
            
//            self.messageListener = .init()
            
//            #if RELEASE
            do {
                if SMAppService.mainApp.status == .notFound {
                    try SMAppService.mainApp.register()
                } else {
                }
            } catch {
                generalLogger.warning("Could not register helper as login item: \(error)")
            }
//            #endif
    }
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
