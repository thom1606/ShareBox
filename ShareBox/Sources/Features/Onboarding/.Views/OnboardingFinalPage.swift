//
//  OnboardingFinalPage.swift
//  ShareBox
//
//  Created by Thom van den Broek on 17/08/2025.
//

import SwiftUI

struct OnboardingFinalPage: View {
    @AppStorage(Constants.Settings.completedOnboardingPrefKey) private var onboardingCompleted = false
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        OnboardingPage(continueText: "Let's go!", onContinue: handleContinue) {
            HStack {
                VStack(alignment: .leading, spacing: 30) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("I'm ready!")
                            .fontDesign(.serif)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("Go ahead and move your mouse to the left edge of your screen to start with ShareBox. You can also right click on a file or folder in Finder and select **Upload to ShareBox**.")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                    }
                }
                .frame(width: 350)
                VStack {
                    Image(systemName: "play.circle")
                        .foregroundStyle(.primary.opacity(0.3))
                        .font(.system(size: 250))
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.leading, 32)
            .padding(.top, 48)
        }
    }

    private func handleContinue() {
        onboardingCompleted = true
        _ = try? MachMessenger.shared.send(MachMessage(type: .peek, data: nil))
        dismissWindow()
    }
}

#Preview {
    OnboardingFinalPage()
}
