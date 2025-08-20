//
//  User.swift
//  ShareBox
//
//  Created by Thom van den Broek on 19/08/2025.
//

import Foundation

@Observable class User {
    public static var shared: User?

    private(set) var isLoading: Bool = true
    private(set) var userData: UserData?
    private(set) var subscriptionData: SubscriptionData?
    private(set) var authenticated: Bool = false
    private var updateTask: Task<Void, Never>?

    private let api = ApiService()

    init() {
        User.shared = self
        setup()
    }

    private func setup() {
        // Check if user is authenticated
        if Keychain.shared.fetchToken(key: "RefreshToken") != nil {
            self.authenticated = true
            Task {
                await self.refresh()
            }
        } else {
            self.isLoading = false
        }
    }

    /// Update the refresh and acces token in keychain, with the option to notify the user about it (defaults to true)
    public func saveTokens(accessToken: String, refreshToken: String, notify: Bool = true) {
        Keychain.shared.saveToken(refreshToken, key: "RefreshToken")
        Keychain.shared.saveToken(accessToken, key: "AccessToken")
        Task {
            await self.refresh()
        }
        // Update user that tokens have been updated
        if notify {
            Utilities.showNotification(title: String(localized: "Authenticated"), body: String(localized: "You have been authenticated successfully, enjoy sharing files!"))
        }
    }

    /// Refresh user details
    public func refresh() async {
        do {
            let res: UserFetchResponse = try await api.get(endpoint: "/api/auth/user")
            self.authenticated = true
            self.userData = res.user
            self.subscriptionData = res.subscription
            self.isLoading = false
        } catch {
            self.isLoading = false
            if let apiError = error as? APIError, case .unauthorized = apiError {
                // Failed to authenticate
                self.authenticated = false
            }
        }
    }

    /// Update some settings creted by the user
    public func updateSettings(password: String, storageDuration: String) {
        if !self.authenticated { return }
        // Cancel any existing task
        updateTask?.cancel()
        // Create new debounced task
        updateTask = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
            if !Task.isCancelled {
                Task {
                    try? await api.post(endpoint: "/api/auth/user", parameters: [
                        "groupStorageDuration": storageDuration,
                        "groupsPassword": password
                    ]) as ApiService.BasicSuccessResponse
                }
            }
        }
    }

    /// Sign out and remove all user details
    public func signOut() {
        Task {
            _ = try? await api.get(endpoint: "/api/auth/sign-out") as ApiService.BasicSuccessResponse
            Keychain.shared.deleteToken(key: "AccessToken")
            Keychain.shared.deleteToken(key: "RefreshToken")
            self.userData = nil
            self.subscriptionData = nil
            self.authenticated = false
        }
    }
}

struct UserData: Codable, Equatable {
    var id: String
    var fullName: String
    var email: String
}

struct SubscriptionData: Codable, Equatable {
    var status: Status

    enum Status: String, Codable {
        case active
        case inactive
    }
}

private struct UserFetchResponse: Codable {
    var user: UserData
    var subscription: SubscriptionData?

    struct Subscription: Codable {
        var status: String
    }
}
