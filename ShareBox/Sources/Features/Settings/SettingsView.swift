//
//  SettingsView.swift
//  ShareBox
//
//  Created by Thom van den Broek on 16/08/2025.
//

import SwiftUI
import Sparkle

struct SettingsView: View {
    @Environment(GlobalContext.self) private var globalContext

    var updater: SPUUpdater
    var user: User

    var body: some View {
        @Bindable var context = globalContext
        ZStack {
            Color.clear
            TabView(selection: $context.settingsTab) {
                GeneralSettingsView(updater: updater, user: user)
                    .tabItem {
                        Label("Preferences", systemImage: "gear")
                    }
                    .tag(SettingsTab.preferences)
                DrivesSettingsView()
                    .tabItem {
                        Label("Drives", systemImage: "cloud.fill")
                    }
                    .tag(SettingsTab.drives)
                AccountSettingsView(user: user)
                    .tabItem {
                        Label("Account", systemImage: "person.circle")
                    }
                    .tag(SettingsTab.account)
                PackagesSettingsView(user: user)
                    .tabItem {
                        Label("Packages", systemImage: "shippingbox.fill")
                    }
                    .tag(SettingsTab.packages)
                AboutSettingsView()
                    .tabItem {
                        Label("About", systemImage: "info.circle.fill")
                    }
                    .tag(SettingsTab.about)
            }
        }
    }
}

enum SettingsTab {
    case preferences
    case drives
    case account
    case packages
    case about
}
