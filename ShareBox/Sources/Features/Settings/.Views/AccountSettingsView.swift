//
//  AccountSettingsView.swift
//  ShareBox
//
//  Created by Thom van den Broek on 16/08/2025.
//

import SwiftUI

struct AccountSettingsView: View {
    var user: User

    private let api = ApiService()
    @State private var loadingBilling = false
    @Environment(\.openWindow) private var openWindow
    @AppStorage(Constants.Settings.passwordPrefKey) private var boxPassword = ""
    @AppStorage(Constants.Settings.storagePrefKey) private var storageDuration = "3_days"
    @AppStorage(Constants.Settings.overMonthlyLimitStoragePrefKey) private var overMonthlyLimitStorage = false

    private func openBilling() {
        if self.loadingBilling { return }
        withAnimation { self.loadingBilling = true }
        Task {
            do {
                let res: BillingResponse = try await api.get(endpoint: "/api/billing")
                NSWorkspace.shared.open(URL(string: res.url)!)
                DispatchQueue.main.async {
                    withAnimation { self.loadingBilling = false }
                }
            } catch {
                DispatchQueue.main.async {
                    withAnimation { self.loadingBilling = false }
                }
            }
        }
    }

    private func subscribe() {
        openWindow(id: "subscribe")
    }

    private var subscriptionName: String {
        guard let subscriptionData = user.subscriptionData else {
            return "Free"
        }
        if subscriptionData.plan == "plus" { return "ShareBox+" }
        if subscriptionData.plan == "pro" { return "ShareBox Pro" }
        return "Legacy"
    }

    var body: some View {
        Form {
            Section(header: Text("User Details")) {
                if user.isLoading {
                    HStack {
                        Spacer()
                        ProgressView()
                            .controlSize(.small)
                        Spacer()
                    }
                } else if !user.authenticated || user.userData == nil {
                    HStack {
                        Text("Sign in to ShareBox")
                        Spacer()
                        Button(action: user.login, label: {
                            Text("Sign in")
                        })
                    }
                } else {
                    HStack {
                        Text("Name")
                        Spacer()
                        Text(user.userData?.fullName ?? "?")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Email")
                        Spacer()
                        Text(user.userData?.email ?? "?")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Spacer()
                        Button(action: user.signOut, label: {
                            Text("Sign out")
                        })
                    }
                }
            }
            if user.authenticated && user.userData != nil {
                Section(header: Text("Subscription")) {
                    HStack {
                        Text("Current plan")
                        Spacer()
                        Text(subscriptionName)
                            .foregroundStyle(.secondary)
                    }
                    if (user.subscriptionData?.status ?? .inactive) != .active {
                        HStack {
                            Text("Subscribe to ShareBox")
                            Spacer()
                            Button(action: subscribe, label: {
                                ZStack {
                                    Text("Subscribe")
                                }
                            })
                        }
                    } else {
                        if user.subscriptionData?.plan == "pro" {
                            Toggle(isOn: $overMonthlyLimitStorage) {
                                VStack(alignment: .leading) {
                                    Text("Pay-as-you-go storage")
                                    Text("Allow to spend €0.03/GB for uploads past the 250GB monthly limit.")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .onChange(of: overMonthlyLimitStorage) {
                                user.updateSettings(password: boxPassword, storageDuration: storageDuration, overMonthlyLimitStorage: overMonthlyLimitStorage)
                            }
                        }
                    }
                    HStack {
                        Text("Manage billing")
                        Spacer()
                        Button(action: openBilling, label: {
                            ZStack {
                                Text("Open billing")
                                    .opacity(loadingBilling ? 0 : 1)
                                ProgressView()
                                    .controlSize(.small)
                                    .opacity(loadingBilling ? 1 : 0)
                            }
                        })
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct BillingResponse: Codable {
    var url: String
}

struct SubscribeResponse: Codable {
    var url: String
    var sessionId: String
}

struct UserDataResponse: Codable {
    var user: User
    var subscription: Subscription?

    struct User: Codable {
        var id: String
        var fullName: String
        var email: String
    }

    struct Subscription: Codable {
        var status: String
    }
}

#Preview {
    AccountSettingsView(user: .init())
}
