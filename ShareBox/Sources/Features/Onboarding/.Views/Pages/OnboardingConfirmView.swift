//
//  OnboardingConfirmView.swift
//  ShareBox
//
//  Created by Thom van den Broek on 08/09/2025.
//

import SwiftUI

struct OnboardingConfirmView: View {
    @Binding var pageSelection: Int
    var selectedPlan: Plan

    var body: some View {
        PricingConfirmView(selectedPlan: selectedPlan, onCancel: {
            self.pageSelection -= 1
        }, onContinue: {
            self.pageSelection += 1
        })
    }
}
