//
//  ShareBoxApp.swift
//  ShareBox
//
//  Created by Thom van den Broek on 11/08/2025.
//

import SwiftUI
import UserNotifications
import Sparkle

@main
struct ShareBoxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // Properties
    @AppStorage(Constants.Settings.keepInDockPrefKey) private var keepInDock = false
    private let updaterController: SPUStandardUpdaterController

    init() {
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

        #if RELEASE
        if isAnotherInstanceRunning() {
            NSApp.terminate(nil)
        }
        #endif
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared

        if keepInDock {
            NSApplication.shared.setActivationPolicy(.regular)
        } else {
            NSApplication.shared.setActivationPolicy(.accessory)
        }
    }
    
    private func isAnotherInstanceRunning() -> Bool {
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
        return runningApps.count > 1
    }
    
    var body: some Scene {
        Window("Uploader", id: "uploader") {
            UploaderView()
        }
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {
                // Disable the "New Window" menu item
            }
            CommandGroup(after: .appInfo) {
                CheckForUpdatesView(updater: updaterController.updater)
            }
        }
        Window("Onboarding", id: "onboarding") {
            OnboardingView()
        }
        .windowResizability(.contentSize)
        Settings {
            SettingsView()
                .navigationTitle("ShareBox Settings")
        }
        .defaultSize(width: 600, height: 600)
        .defaultPosition(.center)
        Window("Onboarding", id: "onboarding") {
            Text("Onboarding window")
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
    
    // Add this method to handle incoming URLs
   func application(_ application: NSApplication, open urls: [URL]) {
       for url in urls {
           handleIncomingURL(url)
       }
   }
   
   private func handleIncomingURL(_ url: URL) {
       if url.scheme == "sharebox" && url.host == "auth" {
           // Parse the URL and extract tokens
           if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let queryItems = components.queryItems {
               let refreshToken = queryItems.first(where: { $0.name == "refreshToken" })?.value
               let accessToken = queryItems.first(where: { $0.name == "accessToken" })?.value
               
               if refreshToken != nil && accessToken != nil {
                   Keychain.shared.saveToken(refreshToken!, key: "RefreshToken")
                   Keychain.shared.saveToken(accessToken!, key: "AccessToken")
                   
                   Utilities.showNotification(title: String(localized: "Authenticated"), body: String(localized: "You have been authenticated successfully, enjoy sharing files!"))
               }
           }
       } else if url.scheme == "sharebox" && url.host == "subscribed" {
           NotificationCenter.default.post(name: .userDetailsChanged, object: nil, userInfo: [:])
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
        completionHandler([.banner, .badge, .sound])
    }
}
