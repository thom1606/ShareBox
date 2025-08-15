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
        _ = try? Messenger.shared.send(
            .init(type: .notify,
                  data: NotificationBody(title: title, message: body).encode()
             )
        )
    }
    
    static func map(minRange: CGFloat, maxRange: CGFloat, minDomain: CGFloat, maxDomain: CGFloat, value: CGFloat) -> CGFloat {
        return minDomain + (maxDomain - minDomain) * (value - minRange) / (maxRange - minRange)
    }

    /// Launch the Helper app if it is not already opened
    static func launchHelperApp() throws {
        #if DEBUG
        print("For development the ShareBox Helper should be started manually, please do so.")
        throw ShareBoxError.noHelperInDevelopment
        #else
        // Check if helper is already running
        let runningApps = NSWorkspace.shared.runningApplications
        let helperRunning = runningApps.contains { app in
            app.bundleIdentifier == "com.thom1606.ShareBox.Helper"
        }

        if helperRunning {
            print("ShareBox Helper is already running healthy, skipping this launch...")
            return
        }

        // Try to find helper app in different locations
        var helperPath: String?

        // Try in main app bundle (main app)
        if let bundlePath = Bundle.main.path(forResource: "ShareBox.Helper", ofType: "app") {
            helperPath = bundlePath
        }

        // Try in parent app's Resources (Finder Sync .appex)
        if helperPath == nil {
            let extensionBundleURL = Bundle.main.bundleURL
            let appBundleURL = extensionBundleURL.deletingLastPathComponent().deletingLastPathComponent()
            let resourcesURL = appBundleURL.appendingPathComponent("Resources")
            let helperURL = resourcesURL.appendingPathComponent("ShareBox.Helper.app")
            if FileManager.default.fileExists(atPath: helperURL.path) {
                helperPath = helperURL.path
            }
        }

        guard let helperPath = helperPath else {
            print("ShareBox Helper not found in bundle or build products, throwing...")
            throw ShareBoxError.helperNotInstalled
        }

        // Launch helper
        NSWorkspace.shared.open(URL(fileURLWithPath: helperPath))
        #endif
    }
}
