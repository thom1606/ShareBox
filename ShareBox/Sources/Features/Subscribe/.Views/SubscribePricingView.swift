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
        InformationPage(cancelText: "Cancel", onCancel: handleCancel, continueText: continueText, onContinue: handleSubscribe) {
            HStack {
                VStack(alignment: .leading, spacing: 30) {
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
