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
                        Text("For just **€2.99**/month, enjoy a **250GB** upload limit, ensuring your files are always ready to share. Upgrade options will be available soon, offering even more flexibility.\n\nSecure your personal cloud space and effortlessly upload up to **250GB** of files each month.")
                            .foregroundStyle(.secondary)
                            .font(.title3)
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
                if (user.subscriptionData?.status ?? .inactive) == .active {
                    self.pageSelection += 1
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
