//
//  GeneralSettingsView.swift
//  ShareBox
//
//  Created by Thom van den Broek on 16/08/2025.
//

import SwiftUI
import ServiceManagement
import UserNotifications

struct GeneralSettingsView: View {
    @AppStorage(Constants.Settings.keepInDockPrefKey) private var keepInDock = false
    @AppStorage(Constants.Settings.mouseActivationPrefKey) private var enableMouseActivation = true
    @AppStorage(Constants.Settings.hiddenFilesPrefKey) private var includeHiddenFiles = false
    @AppStorage(Constants.Settings.passwordPrefKey) private var boxPassword = ""
    @AppStorage(Constants.Settings.storagePrefKey) private var storageDuration = "3_days"

    @State private var startAtLogin: Bool
    @State private var isNotificationAuthorized = false

    init() {
        self._startAtLogin = State(initialValue: SMAppService.mainApp.status == .enabled)
    }

    private func checkNotificationAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isNotificationAuthorized = (settings.authorizationStatus == .authorized)
            }
        }
    }
    private func requestNotificationAccess() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                self.isNotificationAuthorized = granted
            }
        }
    }

    var body: some View {
        Form {
            Section(header: Text("General")) {
                Toggle(isOn: $keepInDock) {
                    Text("Keep in Dock")
                }
                Toggle(isOn: $startAtLogin) {
                    Text("Start at login")
                }
                .onChange(of: startAtLogin) {
                    do {
                        if startAtLogin {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                    } catch {
                        generalLogger.warning("Failed to modify login items: \(error.localizedDescription)")
                    }
                }
                if !isNotificationAuthorized {
                    HStack {
                        Text("Request notification access")
                        Spacer()
                        Button(action: requestNotificationAccess, label: {
                            Text("Request access")
                        })
                    }
                }
            }
            Section(header: Text("Behaviour")) {
                Toggle(isOn: $enableMouseActivation) {
                    VStack(alignment: .leading) {
                        Text("Enable mouse activation")
                        Text("When enabled, moving your mouse to the screen edge will active the ShareBox Uploader.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                Toggle(isOn: $includeHiddenFiles) {
                    VStack(alignment: .leading) {
                        Text("Include hidden files")
                        Text("Include files which are normally hidden in Finder. Be aware that this may cause sensitive files to be shared unintentionally.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                VStack(alignment: .leading) {
                    TextField("Box Password", text: $boxPassword)
                    Text("Protect your boxes by letting users enter a password to access them.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                HStack {
                    Picker(selection: $storageDuration, label:
                        VStack(alignment: .leading) {
                            Text("Storage duration")
                            Text("Determine the duration of time a Box will be accessible after being shared.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    ) {
                        #if DEBUG
                        Text("5 minutes").tag("5_minutes")
                        #endif
                        Text("1 day").tag("1_days")
                        Text("2 days").tag("2_days")
                        Text("3 days").tag("3_days")
                        Text("5 days").tag("5_days")
                        Text("7 days").tag("7_days")
                    }
                    Spacer()
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .onAppear {
            checkNotificationAuthorization()
        }
    }
}

#Preview {
    GeneralSettingsView()
}
