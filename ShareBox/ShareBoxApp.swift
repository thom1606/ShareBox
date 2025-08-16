//
//  ShareBoxApp.swift
//  ShareBox
//
//  Created by Thom van den Broek on 11/08/2025.
//

import SwiftUI
import UserNotifications

@main
struct ShareBoxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        #if RELEASE
        if isAnotherInstanceRunning() {
            NSApp.terminate(nil)
        }
        #endif
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
    }
    
    private func isAnotherInstanceRunning() -> Bool {
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
        return runningApps.count > 1
    }
    
    var body: some Scene {
        Window("Uploader", id: "uploader") {
            UploadView()
                .onAppear {
                    print("requesting notificaiton access")
                    UNUserNotificationCenter.current().requestAuthorization(options: [.alert]) { _, _ in }
                }
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                // Disable the "New Window" menu item
            }
        }
        Window("Settings", id: "settings") {
            Text("Settings window")
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        if let window = NSApplication.shared.windows.first {
            window.styleMask.remove(.titled)
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.level = .mainMenu
            window.makeKeyAndOrderFront(nil)
        }
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
        print("received notification")
        completionHandler([.banner, .badge, .sound])
    }
}
