//
//  GeneralSettingsView.swift
//  ShareBox
//
//  Created by Thom van den Broek on 16/08/2025.
//

import SwiftUI
import ServiceManagement
import UserNotifications
import Sparkle

struct GeneralSettingsView: View {
    private let updater: SPUUpdater
    var user: User

    @AppStorage(Constants.Settings.keepInMenuBarPrefKey) private var keepInMenuBar = true
    @AppStorage(Constants.Settings.mouseActivationPrefKey) private var enableMouseActivation = true
    @AppStorage(Constants.Settings.keepNotchOpenWhileUploadingPrefKey) private var keepNotchOpen = true
    @AppStorage(Constants.Settings.hiddenFilesPrefKey) private var includeHiddenFiles = false
    @AppStorage(Constants.Settings.uploadNotificationsPrefKey) private var showUploadNotifications = true
    @AppStorage(Constants.Settings.passwordPrefKey) private var boxPassword = ""
    @AppStorage(Constants.Settings.storagePrefKey) private var storageDuration = "3_days"
    @AppStorage(Constants.Settings.overMonthlyLimitStoragePrefKey) private var overMonthlyLimitStorage = false

    @State private var startAtLogin: Bool
    @State private var isNotificationAuthorized = false

    init(updater: SPUUpdater, user: User) {
        self.updater = updater
        self.user = user
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
                Toggle(isOn: $keepInMenuBar) {
                    Text("Show ShareBox in menu bar")
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
                } else {
                    Toggle(isOn: $showUploadNotifications) {
                        VStack(alignment: .leading) {
                            Text("Send notifcation after upload")
                            Text("When enabled, a notification is send after all your files have been uploaded.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                HStack {
                    Text("Check for updates")
                    Spacer()
                    Button(action: { updater.checkForUpdates() }, label: {
                        ZStack {
                            Text("Check")
                        }
                    })
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
                Toggle(isOn: $keepNotchOpen) {
                    VStack(alignment: .leading) {
                        Text("Keep notch open while uploading")
                        Text("Keep the notch open while uploads are happening, otherwise morph into a small notch to hover over.")
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
                        .onChange(of: boxPassword) {
                            user.updateSettings(password: boxPassword, storageDuration: storageDuration, overMonthlyLimitStorage: overMonthlyLimitStorage)
                        }
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
                    .onChange(of: storageDuration) {
                        user.updateSettings(password: boxPassword, storageDuration: storageDuration, overMonthlyLimitStorage: overMonthlyLimitStorage)
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
    let mockUpdater = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil).updater

    GeneralSettingsView(updater: mockUpdater, user: .init())
}
