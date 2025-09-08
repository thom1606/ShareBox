//
//  OnboardingPricingView.swift
//  ShareBox
//
//  Created by Thom van den Broek on 08/09/2025.
//

import SwiftUI

struct OnboardingPricingView: View {
    @Environment(User.self) private var user
    @Environment(\.dismissWindow) private var dismissWindow

    @Binding var pageSelection: Int
    @Binding var selectedPlan: Plan

    private var continueText: LocalizedStringKey {
        if user.authenticated { return "Subscribe" }
        return "Sign Up"
    }

    var body: some View {
        PricingPage(pageSelection: $pageSelection, selectedPlan: $selectedPlan, cancelText: "Later", onCancel: handleSkip, onContinue: handleSubscribe)
    }

    private func handleSkip() {
        pageSelection += 2
    }

    private func handleSubscribe() {
        pageSelection += 1
    }
}
