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
