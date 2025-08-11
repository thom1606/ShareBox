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
        }
        
        guard let helperPath = helperPath else {
            print("Helper app not found in bundle or build products, throwing...")
            throw ShareBoxError.helperNotInstalled
        }
        
        // Launch helper
        NSWorkspace.shared.open(URL(fileURLWithPath: helperPath))
        #endif
        
    }
}
