//
//  Notifications.swift
//  ShareBox
//
//  Created by Thom van den Broek on 08/08/2025.
//

import SwiftUI
import UserNotifications

class Utilities {
    /// Show local notification to the user if given permissions
    static func showNotification(title: String, body: String) {
        let center = UNUserNotificationCenter.current()
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        center.add(request) { (error) in
            if let error = error {
                NSLog("Error adding notification: \(error.localizedDescription)")
            } else {
                NSLog("added notification to center")
            }
        }
    }
    
    /// Launch the Helper app if it is not already opened
    static func launchHelperApp() throws {
        
        #if DEBUG
        print("For development the Helper App should be started manually, please do so.")
        return
        #else
        // Check if helper is already running
        let runningApps = NSWorkspace.shared.runningApplications
        let helperRunning = runningApps.contains { app in
            app.bundleIdentifier == "com.thom1606.ShareBox.Helper"
        }

        if helperRunning {
            print("Helper app is already running healthy, skipping this launch...")
            return
        }
        
        // Try to find helper app in different locations
        var helperPath: String?
        
        // 1. Try in main app bundle (production)
        if let bundlePath = Bundle.main.path(forResource: "ShareBox.Helper", ofType: "app") {
            helperPath = bundlePath
            print(bundlePath)
        }
        // 2. Try in build products directory (development)
//        else if let buildProductsPath = findHelperInBuildProducts() {
//            helperPath = buildProductsPath
//        }
        
        guard let helperPath = helperPath else {
            print("Helper app not found in bundle or build products, throwing...")
            throw ShareBoxError.helperNotInstalled
        }
        
        // Launch helper
        NSWorkspace.shared.open(URL(fileURLWithPath: helperPath))
        #endif
        
    }

    /// Find the Helper App in the build folder for local execution
    static func findHelperInBuildProducts() -> String? {
        // Get the main app's bundle path
        let mainAppPath = Bundle.main.bundlePath
        print("main path", mainAppPath)
        // If running from an .appex, find the containing .app, then get its parent directory
        if mainAppPath.hasSuffix(".appex") {
            var url = URL(fileURLWithPath: mainAppPath)
            // Now traverse up until we find a .app
            while url.pathExtension != "app" && url.path != "/" {
                url.deleteLastPathComponent()
            }
            if url.pathExtension == "app" {
                // url is now .../ShareBox.app
                let parentOfApp = url.deletingLastPathComponent()
                let helperAppURL = parentOfApp.appendingPathComponent("ShareBox.Helper.app")
                if FileManager.default.fileExists(atPath: helperAppURL.path) {
                    return helperAppURL.path
                }
            }
        }
        
        // In development, the helper should be in the same directory as the main app
        let mainAppURL = URL(fileURLWithPath: mainAppPath)
        let buildProductsDir = mainAppURL.deletingLastPathComponent()
        let helperPath = buildProductsDir.appendingPathComponent("ShareBox.Helper.app")
        
        // Check if helper exists at this path
        if FileManager.default.fileExists(atPath: helperPath.path) {
            return helperPath.path
        }
        return nil
    }
}
