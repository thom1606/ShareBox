//
//  OnboardingStepWelcome.swift
//  ShareBox
//
//  Created by Thom van den Broek on 12/08/2025.
//

import SwiftUI
import ThomKit

struct OnboardingStepWelcome: View {
    @Binding var pageSelection: Int

    func handleNext() {
        pageSelection += 1
    }

    var body: some View {
        VStack(alignment: .leading) {
            ZStack {
                Spacer()
                    .frame(maxWidth: .infinity)
                if #available(macOS 15.0, *) {
                    Image(systemName: "hand.wave.fill")
                        .font(.system(size: 160, weight: .semibold))
                        .padding(.bottom, 64)
                        .symbolEffect(.wiggle.byLayer, options: .repeating)
                } else {
                    Image(systemName: "hand.wave.fill")
                        .font(.system(size: 160, weight: .semibold))
                        .padding(.bottom, 64)
                }
            }
            Text("Welcome to ShareBox")
                .foregroundStyle(Color(NSColor.labelColor))
                .font(.title.weight(.bold))
                .padding(.bottom, 2)
            Text("Get your own box in the cloud, share files and folders with anyone, anywhere.")
                .foregroundStyle(Color(NSColor.secondaryLabelColor))
                .font(.title3)
                .padding(.bottom, 12)
            Button(action: handleNext) {
                Text("Get started")
            }
            .buttonStyle(MainButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }
}

#Preview {
    OnboardingStepWelcome(pageSelection: .constant(0))
        .frame(width: 425, height: 600)
}
