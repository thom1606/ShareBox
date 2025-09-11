//
//  OnboardingView.swift
//  ShareBox
//
//  Created by Thom van den Broek on 17/08/2025.
//

import SwiftUI
import ThomKit

struct SubscribeView: View {
    // Properties
    private let api = ApiService()
    @Environment(User.self) private var user
    @State private var selection = 0
    @State private var selectedPlan: Plan = .pro

    var body: some View {
        FrostedWindow {
            PagingView(selection: $selection) {
                SubscribePricingView(pageSelection: $selection, selectedPlan: $selectedPlan)
                    .tag(0)
                SubscribeSignInView(pageSelection: $selection)
                    .opacity(user.authenticated ? 0 : 1)
                    .tag(1)
                SubscribeConfirmView(pageSelection: $selection, selectedPlan: selectedPlan)
                    .tag(2)
                SubscribeFinalView()
                    .tag(3)
            }
        }
        .frame(width: 1000, height: 600)
        .background(WindowAccessor { window in
            window.titleVisibility = .hidden
        })
    }
}
