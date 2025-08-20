//
//  SettingsView.swift
//  ShareBox
//
//  Created by Thom van den Broek on 16/08/2025.
//

import SwiftUI
import Sparkle

struct SettingsView: View {
    var updater: SPUUpdater
    var user: User

    // Properties
    @AppStorage(Constants.Settings.keepInDockPrefKey) private var keepInDock = false

    var body: some View {
        ZStack {
            Color.clear
            TabView {
                GeneralSettingsView(updater: updater, user: user)
                    .tabItem {
                        Label("Preferences", systemImage: "gear")
                    }
                AccountSettingsView(user: user)
                    .tabItem {
                        Label("Account", systemImage: "person.circle")
                    }
                BoxesSettingsView()
                    .tabItem {
                        Label("Boxes", systemImage: "shippingbox.fill")
                    }
                AboutSettingsView()
                    .tabItem {
                        Label("About", systemImage: "info.circle.fill")
                    }
            }
        }
        .onAppear {
            NSApplication.shared.setActivationPolicy(.regular)
        }
        .onDisappear {
            if !keepInDock {
                NSApplication.shared.setActivationPolicy(.accessory)
            }
        }
    }
}

#Preview {
    let mockUpdater = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil).updater

    SettingsView(updater: mockUpdater, user: .init())
}
