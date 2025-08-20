//
//  OnboardingView.swift
//  ShareBox
//
//  Created by Thom van den Broek on 17/08/2025.
//

import SwiftUI
import ThomKit

struct OnboardingView: View {
    var user: User

    private let api = ApiService()
    // Properties
    @AppStorage(Constants.Settings.keepInDockPrefKey) private var keepInDock = false
    @State private var selection = 0

    var body: some View {
        FrostedWindow {
            PagingView(selection: $selection, pageCount: 6) {
                OnboardingWelcomeView(pageSelection: $selection, isLoading: user.isLoading)
                    .tag(0)
                OnboardingExperienceView(pageSelection: $selection)
                    .tag(1)
                OnboardingSecureView(pageSelection: $selection, user: user)
                    .tag(2)
                OnboardingSignInView(pageSelection: $selection, user: user)
                    .tag(3)
                OnboardingSubscribeView(pageSelection: $selection, user: user)
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
        }
        .onDisappear {
            if !keepInDock {
                NSApplication.shared.setActivationPolicy(.accessory)
            }
        }
    }
}

#Preview {
    OnboardingView(user: .init())
}
