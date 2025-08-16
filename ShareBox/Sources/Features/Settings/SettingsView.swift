//
//  SettingsView.swift
//  ShareBox
//
//  Created by Thom van den Broek on 16/08/2025.
//

import SwiftUI

struct SettingsView: View {
    // Properties
    @AppStorage(Constants.Settings.keepInDockPrefKey) private var keepInDock = false

    var body: some View {
        ZStack {
            Color.clear
            TabView {
                GeneralSettingsView()
                    .tabItem {
                        Label("Preferences", systemImage: "gear")
                    }
                Text("Account")
                    .tabItem {
                        Label("Account", systemImage: "person.circle")
                    }
                Text("Third View")
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
    SettingsView()
}
