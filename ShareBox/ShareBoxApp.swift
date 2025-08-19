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
    private let updaterController: SPUStandardUpdaterController
    @AppStorage(Constants.Settings.keepInDockPrefKey) private var keepInDock = false
    @State private var user = User()

    init() {
        // Initialize variables
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: nil, userDriverDelegate: nil)

        // For release we only allow up to 1 instance running at a time
        #if RELEASE
        if isAnotherInstanceRunning() {
            NSApp.terminate(nil)
        }
        #endif

        // Setup local handlers
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
        }
        .defaultSize(width: 600, height: 600)
        .defaultPosition(.center)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    // Correct the UI for the main uploader window on startup
    public func applicationDidFinishLaunching(_ notification: Notification) {
        if let window = NSApplication.shared.windows.first {
            window.styleMask.remove(.titled)
            window.isOpaque = false
            window.backgroundColor = .clear
            window.hasShadow = false
            window.level = .mainMenu
            window.makeKeyAndOrderFront(nil)
        }
    }

    // Shutdown warning when uploads are in progress
    public func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Check if there are ongoing uploads
        if let uploader = UploaderViewModel.shared, uploader.uploadState != .idle {
            // Show alert preventing the shutdown
            let alert = NSAlert()
            alert.messageText = String(localized: "Upload in Progress")
            alert.informativeText = String(localized: "You have files currently uploading. Closing the app now may interrupt these uploads. Are you sure you want to quit?")
            alert.alertStyle = .warning
            alert.addButton(withTitle: String(localized: "Quit Anyway"))
            alert.addButton(withTitle: String(localized: "Cancel"))
            alert.window.center()
            alert.window.level = .floating
            alert.window.makeKeyAndOrderFront(nil)
            let response = alert.runModal()
            // If the user wants to continue, cancel the termination
            if response == .alertFirstButtonReturn {
                return .terminateNow
            } else {
                return .terminateCancel
            }
        }
        return .terminateNow
    }
    
    // Listen for deeplinks coming in
    public func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            handleIncomingURL(url)
        }
    }

    // Handle each incoming URL and check their purpose
    private func handleIncomingURL(_ url: URL) {
        Task {
            if url.scheme == "sharebox" && url.host == "auth" {
                // Parse the URL and extract tokens
                if let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
                   let queryItems = components.queryItems {
                    let refreshToken = queryItems.first(where: { $0.name == "refreshToken" })?.value
                    let accessToken = queryItems.first(where: { $0.name == "accessToken" })?.value
                    
                    // Only if both exist we override them
                    if refreshToken != nil && accessToken != nil {
                        User.shared?.saveTokens(accessToken: accessToken!, refreshToken: refreshToken!)
                    }
                }
            } else if url.scheme == "sharebox" && url.host == "subscribed" {
                await User.shared?.refresh()
            }
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
