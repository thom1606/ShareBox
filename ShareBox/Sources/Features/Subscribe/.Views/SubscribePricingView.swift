//
//  SubscribePricingView.swift
//  ShareBox
//
//  Created by Thom van den Broek on 07/09/2025.
//

import SwiftUI

struct SubscribePricingView: View {
    @Environment(User.self) private var user
    @Environment(\.dismissWindow) private var dismissWindow

    @Binding var pageSelection: Int
    @Binding var selectedPlan: Plan

    private var continueText: LocalizedStringKey {
        if user.authenticated { return "Subscribe" }
        return "Sign Up"
    }

    var body: some View {
        PricingPage(pageSelection: $pageSelection, selectedPlan: $selectedPlan, onCancel: handleCancel, onContinue: handleSubscribe)
    }

    private func handleCancel() {
        dismissWindow()
    }

    private func handleSubscribe() {
        if user.authenticated {
            pageSelection += 2
        } else {
            pageSelection += 1
        }
    }
}
