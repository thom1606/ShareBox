//
//  WelcomeViewModel.swift
//  ShareBox
//
//  Created by Thom van den Broek on 07/08/2025.
//

import SwiftUI
import AuthenticationServices

@MainActor
@Observable class WelcomeViewModel {
    var authenticated: Bool
    var signInFailed: Bool = false
    
    private var api = ApiService()

    init() {
        authenticated = Keychain.shared.fetchToken(key: "AccessToken") != nil && Keychain.shared.fetchToken(key: "RefreshToken") != nil
        
        if authenticated {
            Task {
                await fetchUserDetails()
            }
                
        }
    }
    
    private func fetchUserDetails() async {
        do {
            let userData: UserDataResponse = try await api.get(endpoint: "/api/auth/user")
            
            // Keep track of the subscription details
            userDefaults.set(userData.subscription?.status, forKey: Constants.User.subscriptionStatusKey)
        } catch {
            if let apiError = error as? APIError, case .unauthorized = apiError {
                // Failed to authenticate
                authenticated = false
            }
        }
    }
    
    public func onSignIn(result: Result<ASAuthorization, any Error>) {
        signInFailed = false
        switch result {
        case .success(let authorization):
            if let userCredentials = authorization.credential as? ASAuthorizationAppleIDCredential {
                if let codeData = userCredentials.authorizationCode,
                   let code = String(data: codeData, encoding: .utf8) {
                    Task {
                        do {
                            Keychain.shared.deleteToken(key: "AccessToken")
                            Keychain.shared.deleteToken(key: "RefreshToken")
                            let res: TokenResponse = try await api.post(endpoint: "/api/auth/apple/callback", parameters: [
                                "code": code,
                                "email": userCredentials.email ?? "",
                                "firstName": userCredentials.fullName?.givenName ?? "",
                                "lastName": userCredentials.fullName?.familyName ?? "",
                                "idToken": userCredentials.user
                            ])
                            // If we have been authorized we update tokens
                            Keychain.shared.saveToken(res.accessToken, key: "AccessToken")
                            Keychain.shared.saveToken(res.refreshToken, key: "RefreshToken")

                            // Retrieve user details
                            await fetchUserDetails()

                            withAnimation {
                                authenticated = true
                            }
                        } catch {
                            print("Failed to submit details", error)
                            withAnimation {
                                signInFailed = true
                            }
                        }
                    }
                } else {
                    // TODO: log with sentry
                    print("No user access code")
                    withAnimation {
                        signInFailed = true
                    }
                }
            } else {
                // TODO: log with sentry
                print("No user credentials")
                withAnimation {
                    signInFailed = true
                }
            }
        case .failure:
            // TODO: log with sentry
            print("Failed to sign in")
            withAnimation {
                signInFailed = true
            }
        }
    }
}

private struct UserDataResponse: Codable {
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
