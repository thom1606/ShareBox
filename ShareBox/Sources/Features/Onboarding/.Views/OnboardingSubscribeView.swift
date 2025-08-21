//
//  OnboardingSubscribeView.swift
//  ShareBox
//
//  Created by Thom van den Broek on 17/08/2025.
//

import SwiftUI
import ServiceManagement
import UserNotifications

struct OnboardingSubscribeView: View {
    private let api = ApiService()
    @Binding var pageSelection: Int
    var user: User
    
    @AppStorage(Constants.Settings.passwordPrefKey) private var boxPassword = ""
    @AppStorage(Constants.Settings.storagePrefKey) private var storageDuration = "3_days"
    @AppStorage(Constants.Settings.overMonthlyLimitStoragePrefKey) private var overMonthlyLimitStorage = false
    @State private var isLoading: Bool = false
    
    var body: some View {
        OnboardingPage(continueText: "Subscribe", isLoading: isLoading, onContinue: handleContinue) {
            HStack {
                VStack(alignment: .leading, spacing: 30) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Start sharing!")
                            .fontDesign(.serif)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("For just **€2.99**/month, enjoy a **250GB** upload limit, ensuring your files are always ready to share.\n\nSecure your personal cloud space and effortlessly upload up to **250GB** of files each month.")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                    }
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Toggle("", isOn: $overMonthlyLimitStorage)
                                .toggleStyle(.switch)
                                .controlSize(.mini)
                                .onChange(of: overMonthlyLimitStorage) {
                                    user.updateSettings(password: boxPassword, storageDuration: storageDuration, overMonthlyLimitStorage: overMonthlyLimitStorage)
                                }
                            VStack(alignment: .leading) {
                                Text("Pay-as-you-go storage")
                                Text("Allow to spend €0.03/GB for uploads past the 250GB monthly limit.")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .offset(x: -10)
                    }
                }
                .frame(width: 350)
                VStack {
                    Image(systemName: "star.hexagon.fill")
                        .foregroundStyle(.primary.opacity(0.3))
                        .font(.system(size: 250))
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.leading, 32)
            .padding(.top, 48)
            .onChange(of: user.subscriptionData) {
                if pageSelection == 4 {
                    if (user.subscriptionData?.status ?? .inactive) == .active {
                        self.pageSelection += 1
                    }
                }
            }
        }
    }

    private func handleContinue() {
        self.isLoading = true
        Task {
            do {
                let res: SubscribeResponse = try await api.get(endpoint: "/api/subscribe")
                NSWorkspace.shared.open(URL(string: res.url)!)
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }
    }
}

#Preview {
    OnboardingSubscribeView(pageSelection: .constant(0), user: .init())
}
