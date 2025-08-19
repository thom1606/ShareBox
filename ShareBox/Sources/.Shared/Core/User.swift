//
//  User.swift
//  ShareBox
//
//  Created by Thom van den Broek on 19/08/2025.
//

import Foundation

@Observable class User {
    public static var shared: User?

    public var userData: UserData?
    public var subscriptionData: SubscriptionData?
    public var authenticated: Bool = false

    private let api = ApiService()

    init() {
        User.shared = self

        // Check if user is authenticated
        if Keychain.shared.fetchToken(key: "AccessToken") != nil && Keychain.shared.fetchToken(key: "RefreshToken") != nil {
            self.authenticated = true
        }
    }

    /// Update the refresh and acces token in keychain, with the option to notify the user about it (defaults to true)
    public func saveTokens(accessToken: String, refreshToken: String, notify: Bool = true) {
        Keychain.shared.saveToken(refreshToken, key: "RefreshToken")
        Keychain.shared.saveToken(accessToken, key: "AccessToken")

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
        } catch {
            if let apiError = error as? APIError, case .unauthorized = apiError {
                // Failed to authenticate
                self.authenticated = false
            }
        }
    }
}

struct UserData: Codable {
    var id: String
    var fullName: String
    var email: String
}

struct SubscriptionData: Codable {
    var status: Status

    enum Status: String, Codable {
        case active
    }
}

private struct UserFetchResponse: Codable {
    var user: UserData
    var subscription: SubscriptionData?

    struct Subscription: Codable {
        var status: String
    }
}
