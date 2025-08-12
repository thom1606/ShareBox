//
//  OnboardingStack.swift
//  ShareBox
//
//  Created by Thom van den Broek on 12/08/2025.
//

import SwiftUI
import ThomKit

struct OnboardingStack<C: View>: View {
    @ViewBuilder var content: () -> C
    @AppStorage("onboardingCompleted") private var onboardingCompleted: Bool = false
    @State private var selection = 0

    var body: some View {
        ZStack {
            if onboardingCompleted {
                content()
            } else {
                PagingView(selection: $selection, pageCount: 3) {
                    OnboardingStepWelcome(pageSelection: $selection)
                        .tag(0)
                    OnboardingStepNotifications(pageSelection: $selection)
                        .tag(1)
                    OnboardingStepSubscribe(pageSelection: $selection)
                        .tag(2)
                    OnboardingStepFinal()
                        .tag(2)
                }
            }
        }
    }
}

#Preview(traits: .fixedLayout(width: 425, height: 650)) {
    OnboardingStack {
        Text("Content")
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
}
