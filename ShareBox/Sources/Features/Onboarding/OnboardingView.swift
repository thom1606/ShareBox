//
//  OnboardingView.swift
//  ShareBox
//
//  Created by Thom van den Broek on 17/08/2025.
//

import SwiftUI
import ThomKit

struct OnboardingView: View {
    // Properties
    private let api = ApiService()
    @State private var selection = 0
    @State private var selectedPlan: Plan = .pro
    @Environment(User.self) var user

    var body: some View {
        FrostedWindow {
            PagingView(selection: $selection) {
                OnboardingWelcomeView(pageSelection: $selection, isLoading: user.isLoading)
                    .tag(0)
                OnboardingExperienceView(pageSelection: $selection)
                    .tag(1)
                OnboardingSignInView(pageSelection: $selection)
                    .tag(2)
                OnboardingPricingView(pageSelection: $selection, selectedPlan: $selectedPlan)
                    .tag(3)
                    .opacity(user.authenticated && (user.subscriptionData?.status ?? .inactive) != .active ? 1 : 0)
                OnboardingConfirmView(pageSelection: $selection, selectedPlan: selectedPlan)
                    .tag(4)
                    .opacity(user.authenticated && (user.subscriptionData?.status ?? .inactive) != .active ? 1 : 0)
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
            NSApplication.shared.setActivationPolicy(.accessory)
        }
    }
}
