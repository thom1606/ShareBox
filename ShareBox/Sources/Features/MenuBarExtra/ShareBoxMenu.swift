//
//  ShareBoxMenu.swift
//  ShareBox
//
//  Created by Thom van den Broek on 05/09/2025.
//

import SwiftUI
import Sparkle

struct ShareBoxMenu: Scene {
    @Environment(User.self) private var user
    @Environment(GlobalContext.self) private var globalContext
    @AppStorage(Constants.Settings.keepInMenuBarPrefKey) private var keepInMenuBar = true

    var updater: SPUUpdater

    var body: some Scene {
        let buildNumber = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"

        MenuBarExtra("ShareBox", systemImage: "shippingbox.fill", isInserted: $keepInMenuBar) {
            Link("Send Feedback...", destination: URL(string: "mailto:support@shareboxed.app")!)
            Divider()
            Text("Version \(buildNumber) (\(buildVersion))")
                .foregroundStyle(.secondary)
            Button("About ShareBox") {
                globalContext.openSettingsTab(.about)
            }
            Button("Check for Updates") {
                updater.checkForUpdates()
            }
            if !user.authenticated {
                Button("Sign in...", action: user.login)
            }
            SettingsLink {
                Text("Settings…")
            }
            Divider()
            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
        }
    }
}
