//
//  SubscribeConfirmView.swift
//  ShareBox
//
//  Created by Thom van den Broek on 07/09/2025.
//

import SwiftUI
import ServiceManagement
import UserNotifications

struct SubscribeConfirmView: View {
    @Environment(User.self) private var user

    @Binding var pageSelection: Int
    var selectedPlan: Plan

    var body: some View {
        PricingConfirmView(selectedPlan: selectedPlan, onCancel: {
            if user.authenticated {
                self.pageSelection -= 2
            } else {
                self.pageSelection -= 1
            }
        }, onContinue: {
            self.pageSelection += 1
        })
    }
}
