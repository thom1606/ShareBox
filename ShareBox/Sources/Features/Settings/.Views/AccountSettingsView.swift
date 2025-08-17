//
//  AccountSettingsView.swift
//  ShareBox
//
//  Created by Thom van den Broek on 16/08/2025.
//

import SwiftUI

struct AccountSettingsView: View {
    private let api = ApiService()
    @AppStorage(Constants.User.subscriptionStatusKey) private var subscriptionStatus = "inactive"
    @State private var loadingBilling = false
    @State private var loadingSubscribe = false
    @State private var loadedUser = false
    @State private var userDetails: UserDataResponse?
    @State private var authenticated = false

    private func fetchUserDetails() async {
        do {
            let userData: UserDataResponse = try await api.get(endpoint: "/api/auth/user")
            self.authenticated = true
            self.userDetails = userData
            self.loadedUser = true
            self.subscriptionStatus = userData.subscription?.status ?? "inactive"
        } catch {
            if let apiError = error as? APIError, case .unauthorized = apiError {
                // Failed to authenticate
                self.authenticated = false
                self.loadedUser = true
            }
        }
    }

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

    private func handleSignIn() {
        if let domainString = (Bundle.main.object(forInfoDictionaryKey: "BASE_URL") as? String) {
            NSWorkspace.shared.open(URL(string: "\(domainString)/auth/sign-in")!)
        }
    }

    private func handleSignOut() {
        Task {
            _ = try? await api.get(endpoint: "/api/auth/sign-out") as ApiService.BasicSuccessResponse
            Keychain.shared.deleteToken(key: "AccessToken")
            Keychain.shared.deleteToken(key: "RefreshToken")
            self.userDetails = nil
        }
    }

    var body: some View {
        Form {
            Section(header: Text("User Details")) {
                if !self.loadedUser {
                    HStack {
                        Spacer()
                        ProgressView()
                            .controlSize(.small)
                        Spacer()
                    }
                } else if self.userDetails == nil {
                    HStack {
                        Text("Sign in to ShareBox")
                        Spacer()
                        Button(action: handleSignIn, label: {
                            Text("Sign in")
                        })
                    }
                } else {
                    HStack {
                        Text("Name")
                        Spacer()
                        Text(self.userDetails!.user.fullName)
                    }
                    HStack {
                        Text("Email")
                        Spacer()
                        Text(self.userDetails!.user.email)
                    }
                    HStack {
                        Spacer()
                        Button(action: handleSignOut, label: {
                            Text("Sign out")
                        })
                    }
                }
            }
            if self.userDetails != nil {
                Section(header: Text("Subscription")) {
                    if subscriptionStatus != "active" {
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
        .onAppear {
            NotificationCenter.default.addObserver(forName: .keychainItemChanged, object: nil, queue: .main) { notification in
                if let userInfo = notification.userInfo, let key = userInfo["key"] as? String {
                    if key == "AccessToken" || key == "RefreshToken" {
                        Task {
                            await fetchUserDetails()
                        }
                    }
                }
            }
            NotificationCenter.default.addObserver(forName: .userDetailsChanged, object: nil, queue: .main) { _ in
                Task {
                    await fetchUserDetails()
                }
            }
        }
        .onDisappear {
            NotificationCenter.default.removeObserver(self, name: .keychainItemChanged, object: nil)
            NotificationCenter.default.removeObserver(self, name: .userDetailsChanged, object: nil)
        }
        .task {
            await fetchUserDetails()
        }
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
    AccountSettingsView()
}
