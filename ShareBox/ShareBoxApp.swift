//
//  ShareBoxApp.swift
//  ShareBox
//
//  Created by Thom van den Broek on 11/08/2025.
//

import SwiftUI

@main
struct ShareBoxApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    init() {
        #if RELEASE
        if isAnotherInstanceRunning() {
            NSApp.terminate(nil)
        }
        #endif
    }
    
    private func isAnotherInstanceRunning() -> Bool {
        let runningApps = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "")
        return runningApps.count > 1
    }
    
    var body: some Scene {
        Window("Uploader", id: "uploader") {
            UploadView()
        }
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
