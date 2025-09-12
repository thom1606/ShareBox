//
//  User.swift
//  ShareBox
//
//  Created by Thom van den Broek on 19/08/2025.
//

import SwiftUI

@Observable class User {
    public static var shared: User?

    private(set) var isLoading: Bool = true
    private(set) var userData: UserData?
    private(set) var settingsData: SettingsData?
    private(set) var subscriptionData: SubscriptionData?
    private(set) var drivesData: [CloudDrive] = []
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

    public func login() {
        if let domainString = (Bundle.main.object(forInfoDictionaryKey: "BASE_URL") as? String) {
            NSWorkspace.shared.open(URL(string: "\(domainString)/auth/sign-in?platform=macOS")!)
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
            self.settingsData = res.settings
            self.subscriptionData = res.subscription
            self.drivesData = res.drives
            UserDefaults.standard.set(res.settings.groupsPassword, forKey: Constants.Settings.passwordPrefKey)
            UserDefaults.standard.set(res.settings.groupStorageDuration, forKey: Constants.Settings.storagePrefKey)
            UserDefaults.standard.set(res.subscription?.overMonthlyLimitStorage ?? false, forKey: Constants.Settings.overMonthlyLimitStoragePrefKey)
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
    public func updateSettings(password: String, storageDuration: String, overMonthlyLimitStorage: Bool) {
        if !self.authenticated { return }
        // Cancel any existing task
        updateTask?.cancel()
        // Create new debounced task
        updateTask = Task {
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
            if !Task.isCancelled {
                Task {
                    do {
                        _ = try await api.post(endpoint: "/api/auth/user", parameters: [
                            "groupStorageDuration": storageDuration,
                            "groupsPassword": password,
                            "overMonthlyLimitStorage": overMonthlyLimitStorage
                        ]) as ApiService.BasicSuccessResponse
                        UserDefaults.standard.set(password, forKey: Constants.Settings.passwordPrefKey)
                        UserDefaults.standard.set(storageDuration, forKey: Constants.Settings.storagePrefKey)
                    } catch {
                        // Some settings may not be valid, refreshing user
                        await self.refresh()
                    }
                }
            }
        }
    }

    /// Remove a linked drive from the users settings
    public func removeDrive(id: String) async {
        do {
            let _: ApiService.BasicSuccessResponse = try await self.api.delete(endpoint: "/api/drives/\(id)/disconnect")
            self.drivesData.removeAll { $0.id == id }
        } catch { }
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
    var overMonthlyLimitStorage: Bool
    var plan: String

    enum Status: String, Codable {
        case active
        case inactive
    }
}

struct CloudDrive: Codable, Equatable, Identifiable {
    var id: String
    var provider: String
}

struct SettingsData: Codable, Equatable {
    var groupStorageDuration: String
    var groupsPassword: String?
}

private struct UserFetchResponse: Codable {
    var user: UserData
    var settings: SettingsData
    var subscription: SubscriptionData?
    var drives: [CloudDrive]
}
