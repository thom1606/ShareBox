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
    @State private var loadingSubscribe = false
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
        if self.loadingSubscribe { return }
        withAnimation { self.loadingSubscribe = true }
        Task {
            do {
                let res: SubscribeResponse = try await api.get(endpoint: "/api/subscribe")
                NSWorkspace.shared.open(URL(string: res.url)!)
                DispatchQueue.main.async {
                    withAnimation { self.loadingSubscribe = false }
                }
            } catch {
                DispatchQueue.main.async {
                    withAnimation { self.loadingSubscribe = false }
                }
            }
        }
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
                    }
                    HStack {
                        Text("Email")
                        Spacer()
                        Text(user.userData?.email ?? "?")
                    }
                    HStack {
                        Spacer()
                        Button(action: user.signOut, label: {
                            Text("Sign out")
                        })
                    }
                }
            }
            if user.authenticated {
                Section(header: Text("Subscription")) {
                    if (user.subscriptionData?.status ?? .inactive) != .active {
                        HStack {
                            Text("Subscribe to ShareBox")
                            Spacer()
                            Button(action: subscribe, label: {
                                ZStack {
                                    Text("Subscribe")
                                        .opacity(loadingSubscribe ? 0 : 1)
                                    ProgressView()
                                        .controlSize(.small)
                                        .opacity(loadingSubscribe ? 1 : 0)
                                }
                            })
                        }
                    } else {
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
