//
//  SettingsView.swift
//  ShareBox
//
//  Created by Thom van den Broek on 16/08/2025.
//

import SwiftUI
import Sparkle

struct SettingsView: View {
    @Binding var selectedTab: SettingsTab

    var updater: SPUUpdater
    var user: User

    var body: some View {
        ZStack {
            Color.clear
            TabView(selection: $selectedTab) {
                GeneralSettingsView(updater: updater, user: user)
                    .tabItem {
                        Label("Preferences", systemImage: "gear")
                    }
                    .tag(SettingsTab.preferences)
                ZStack {
                    Text("Drives")
                }
                .tabItem {
                    Label("Drives", systemImage: "cloud.fill")
                }
                .tag(SettingsTab.drives)
                AccountSettingsView(user: user)
                    .tabItem {
                        Label("Account", systemImage: "person.circle")
                    }
                    .tag(SettingsTab.account)
                BoxesSettingsView(user: user)
                    .tabItem {
                        Label("Boxes", systemImage: "shippingbox.fill")
                    }
                    .tag(SettingsTab.boxes)
                AboutSettingsView()
                    .tabItem {
                        Label("About", systemImage: "info.circle.fill")
                    }
                    .tag(SettingsTab.about)
            }
        }
        .onAppear {
            NSApplication.shared.setActivationPolicy(.regular)
        }
        .onDisappear {
            NSApplication.shared.setActivationPolicy(.accessory)
        }
    }
}

enum SettingsTab {
    case preferences
    case drives
    case account
    case boxes
    case about
}

#Preview {
    let mockUpdater = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil).updater
    SettingsView(selectedTab: .constant(.about), updater: mockUpdater, user: .init())
}
