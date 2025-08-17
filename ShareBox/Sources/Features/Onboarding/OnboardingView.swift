//
//  OnboardingView.swift
//  ShareBox
//
//  Created by Thom van den Broek on 17/08/2025.
//

import SwiftUI
import ThomKit

struct OnboardingView: View {
    private let api = ApiService()
    // Properties
    @AppStorage(Constants.Settings.keepInDockPrefKey) private var keepInDock = false
    @State private var selection = 0
    @State private var userData: UserDataResponse?
    @State private var hasLoadedUserData = false

    var body: some View {
        FrostedWindow {
            PagingView(selection: $selection, pageCount: 6) {
                OnboardingWelcomeView(pageSelection: $selection, isLoading: !hasLoadedUserData)
                    .tag(0)
                OnboardingExperienceView(pageSelection: $selection)
                    .tag(1)
                OnboardingSecureView(pageSelection: $selection, userData: userData)
                    .tag(2)
                OnboardingSignInView(pageSelection: $selection)
                    .tag(3)
                OnboardingSubscribeView(pageSelection: $selection)
                    .tag(4)
                OnboardingFinalPage()
                    .tag(5)
            }
        }
        .frame(width: 1000, height: 600)
        .background(WindowAccessor { window in
            window.titleVisibility = .hidden
        })
        .onAppear {
            NSApplication.shared.setActivationPolicy(.regular)
            Task {
                self.userData = try? await api.get(endpoint: "/api/auth/user")
                self.hasLoadedUserData = true
            }
        }
        .onDisappear {
            if !keepInDock {
                NSApplication.shared.setActivationPolicy(.accessory)
            }
        }
    }
}

#Preview {
    OnboardingView()
}
