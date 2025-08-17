//
//  OnboardingExperienceView.swift
//  ShareBox
//
//  Created by Thom van den Broek on 17/08/2025.
//

import SwiftUI
import ServiceManagement
import UserNotifications

struct OnboardingExperienceView: View {
    @Binding var pageSelection: Int

    @AppStorage(Constants.Settings.keepInDockPrefKey) private var keepInDock = false
    @State private var startAtLogin: Bool
    @State private var requestNotifications: Bool = false
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    init(pageSelection: Binding<Int>) {
        self._pageSelection = pageSelection
        try? SMAppService.mainApp.register()
        self._startAtLogin = State(initialValue: SMAppService.mainApp.status == .enabled)
    }

    var body: some View {
        OnboardingPage(onContinue: handleContinue) {
            HStack {
                VStack(alignment: .leading, spacing: 30) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Setup your experience")
                            .fontDesign(.serif)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("Let's make everything feel right for you. Your preferences are just a click away.")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                    }
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Toggle("", isOn: $startAtLogin)
                                .toggleStyle(.switch)
                                .controlSize(.mini)
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
                                    self.startAtLogin = SMAppService.mainApp.status == .enabled
                                }
                            Text("Start at Login")
                        }
                        .offset(x: -10)
                        HStack {
                            Toggle("", isOn: $requestNotifications)
                                .toggleStyle(.switch)
                                .controlSize(.mini)
                                .disabled(notificationStatus != .notDetermined)
                                .onChange(of: requestNotifications) {
                                    if requestNotifications { requestNotificationAccess() }
                                }
                            Text("Get status notifications")
                        }
                        .offset(x: -10)
                        HStack {
                            Toggle("", isOn: $keepInDock)
                                .toggleStyle(.switch)
                                .controlSize(.mini)
                            Text("Keep icon in Dock")
                        }
                        .offset(x: -10)
                    }
                    .font(.title3)
                }
                .frame(width: 350)
                VStack {
                    if #available(macOS 15.0, *) {
                        Image(systemName: "hand.wave.fill")
                            .foregroundStyle(.primary.opacity(0.3))
                            .font(.system(size: 250))
                            .symbolEffect(.wiggle.byLayer, options: .repeating)
                    } else {
                        Image(systemName: "hand.wave.fill")
                            .foregroundStyle(.primary.opacity(0.3))
                            .font(.system(size: 250))
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.leading, 32)
            .padding(.top, 48)
            .onAppear {
                checkNotificationAuthorization()
            }
        }
    }

    private func checkNotificationAuthorization() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.requestNotifications = settings.authorizationStatus == .authorized
                self.notificationStatus = settings.authorizationStatus
            }
        }
    }

    private func requestNotificationAccess() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                if granted {
                    self.notificationStatus = .authorized
                } else {
                    self.notificationStatus = .denied
                }
                self.requestNotifications = granted
            }
        }
    }

    private func handleContinue() {
        pageSelection += 1
    }
}

#Preview {
    OnboardingExperienceView(pageSelection: .constant(0))
}
