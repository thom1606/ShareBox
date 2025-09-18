//
//  PricingPage.swift
//  ShareBox
//
//  Created by Thom van den Broek on 08/09/2025.
//

import SwiftUI

struct PricingPage: View {
    @Environment(User.self) private var user

    @Binding var pageSelection: Int
    @Binding var selectedPlan: Plan

    var cancelText: LocalizedStringKey = "Cancel"
    var onCancel: () -> Void
    var onContinue: () -> Void

    private var continueText: LocalizedStringKey {
        if user.authenticated { return "Subscribe" }
        return "Sign Up"
    }

    var body: some View {
        InformationPage(cancelText: cancelText, onCancel: onCancel, continueText: continueText, isLoading: user.isLoading, onContinue: onContinue) {
            HStack {
                VStack(alignment: .leading, spacing: 16) {
                    PriceCard(
                        selectedPlan: $selectedPlan,
                        plan: .plus
                    )
                    PriceCard(
                        selectedPlan: $selectedPlan,
                        plan: .pro
                    )
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
    }
}
