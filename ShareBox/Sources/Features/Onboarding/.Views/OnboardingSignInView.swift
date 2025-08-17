//
//  OnboardingSignInView.swift
//  ShareBox
//
//  Created by Thom van den Broek on 17/08/2025.
//

import SwiftUI

struct OnboardingSignInView: View {
    @Binding var pageSelection: Int
    @State private var isLoading: Bool = false
    @State private var hasErrored: Bool = false

    var body: some View {
        OnboardingPage(continueText: "Sign up", isLoading: isLoading, onContinue: handleContinue) {
            HStack {
                VStack(alignment: .leading, spacing: 30) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Create your account")
                            .fontDesign(.serif)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("Sign up using your **Apple ID** to secure your own space in the ShareBox cloud.")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                    }
                }
                .frame(width: 350)
                VStack {
                    Image(systemName: "person.crop.circle.fill")
                        .foregroundStyle(.primary.opacity(0.3))
                        .font(.system(size: 250))
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.leading, 32)
            .padding(.top, 48)
        }
        .onDisappear(perform: handleDisappear)
    }

    private func handleContinue() {
        self.hasErrored = false
        self.isLoading = true
        if let domainString = (Bundle.main.object(forInfoDictionaryKey: "BASE_URL") as? String) {
            NSWorkspace.shared.open(URL(string: "\(domainString)/auth/sign-in")!)
        }
        NotificationCenter.default.addObserver(forName: .keychainItemChanged, object: nil, queue: .main) { notification in
            if let userInfo = notification.userInfo, let key = userInfo["key"] as? String, let action = userInfo["action"] as? String {
                if key == "RefreshToken" && action == "save" {

                    NotificationCenter.default.removeObserver(self, name: .keychainItemChanged, object: nil)

                    let api = ApiService()
                    Task {
                        let userData: UserDataResponse? = try? await api.get(endpoint: "/api/auth/user")
                        await MainActor.run {
                            if userData == nil {
                                self.isLoading = false
                                withAnimation { self.hasErrored = true }
                                return
                            }
                            if userData?.subscription?.status == "active" {
                                self.pageSelection += 2
                            } else {
                                self.pageSelection += 1
                            }
                        }
                    }
                }
            }
        }
    }

    private func handleDisappear() {
        NotificationCenter.default.removeObserver(self, name: .keychainItemChanged, object: nil)
    }
}

#Preview {
    OnboardingSignInView(pageSelection: .constant(0))
}
