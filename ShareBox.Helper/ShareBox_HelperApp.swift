//
//  ShareBox_HelperApp.swift
//  ShareBox.Helper
//
//  Created by Thom van den Broek on 11/08/2025.
//

import SwiftUI
import ServiceManagement
import os
import UserNotifications

@main
struct ShareBox_HelperApp: App {
    private let messageListener: MessageListener?

    init() {
        // Ensure only one instance of the Helper app is running
        let bundleID = Bundle.main.bundleIdentifier ?? "com.thom1606.ShareBox.Helper"
        let myBuildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        let runningInstances = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        if runningInstances.count > 1 {
            var shouldKill = true
            if let bundleURL = runningInstances[0].bundleURL,
               let infoPlist = NSDictionary(contentsOf: bundleURL.appendingPathComponent("Contents/Info.plist")),
               let buildNumber = infoPlist["CFBundleVersion"] as? String {
                if buildNumber != myBuildNumber {
                    generalLogger.warning("Another instance of ShareBox Helper is running with a different build number. Exiting that instance.")
                    // Terminate the other instance
                    runningInstances[0].terminate()
                    shouldKill = false
                }
            }
            if shouldKill {
                self.messageListener = nil
                // Another instance is already running, terminate this one
                generalLogger.warning("Another instance of ShareBox Helper is already running. Exiting this instance.")
                NSApp.terminate(nil)
                return
            }
        }

        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
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

        #if DEBUG
        // For Development purposes, launch the UI from here
        DispatchQueue.main.async {
            UploadWindowController.shared.show(
                items: [
                    .init(relative: "favicon.ico", absolute: "file:///Users/thomvandenbroek/Projects/Fooxly/account/packages/client/public/favicon.ico", isFolder: false),
                    .init(relative: "favicon.icon", absolute: "file:///Users/thomvandenbroek/Projects/Fooxly/account/packages/client/public/favicon.icon", isFolder: false),
//                    .init(relative: "src", absolute: "file:///Users/thomvandenbroek/Projects/Fooxly/account/packages/client/src/"),
                    .init(relative: "test", absolute: "file:///Users/thomvandenbroek/Projects/TryOut/test/", isFolder: true)
//                    .init(relative: "IMG_1776.JPG", absolute: "file:///Users/thomvandenbroek/Other/IMG_1776.JPG"),
//                    .init(relative: "IMG_1777.JPG", absolute: "file:///Users/thomvandenbroek/Other/IMG_1777.JPG")
                ]
            )
        }
        #endif
    }

    var body: some Scene {
        Settings {}
    }
}

// Singleton delegate to handle notifications
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()

    // This method is called when a notification is delivered while the app is in the foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show banner, badge, and play sound even if app is in foreground
        print("Received notification")
        completionHandler([.banner, .badge, .sound])
    }
}
