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

    @State private var isLoading: Bool = false
    @State private var hasErrored: Bool = false

    var body: some View {
        OnboardingPage(continueText: "Subscribe", isLoading: isLoading, onContinue: handleContinue) {
            HStack {
                VStack(alignment: .leading, spacing: 30) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Start with sharing!")
                            .fontDesign(.serif)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("For just **€2.99**/mo, enjoy a neat **250GB** upload limit each month. Upgrade options will be available soon.\n\nGet access to your space in the cloud with the possibility to upload up to **250GB** of files each month.")
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
        }
        .onAppear(perform: handleAppear)
        .onDisappear(perform: handleDisappear)
    }

    private func handleContinue() {
        self.hasErrored = false
        self.isLoading = true
        Task {
            do {
                let res: SubscribeResponse = try await api.get(endpoint: "/api/subscribe")
                NSWorkspace.shared.open(URL(string: res.url)!)
            } catch {
                DispatchQueue.main.async {
                    self.isLoading = false
                    withAnimation { self.hasErrored = true }
                }
            }
        }
    }

    private func handleAppear() {
        NotificationCenter.default.addObserver(forName: .userDetailsChanged, object: nil, queue: .main) { _ in
            Task {
                await fetchUserDetails()
            }
        }
    }

    private func handleDisappear() {
        NotificationCenter.default.removeObserver(self, name: .userDetailsChanged, object: nil)
    }

    private func fetchUserDetails() async {
        do {
            let userData: UserDataResponse = try await api.get(endpoint: "/api/auth/user")
            if userData.subscription?.status == "active" {
                self.pageSelection += 1
            } else {
                throw ShareBoxError.failed
            }
        } catch {
            withAnimation {
                self.hasErrored = true
            }
        }
        self.isLoading = false
    }
}

#Preview {
    OnboardingSubscribeView(pageSelection: .constant(0))
}
