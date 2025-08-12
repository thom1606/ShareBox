//

//  OnboardingStepSubscribe.swift
//  ShareBox
//
//  Created by Thom van den Broek on 12/08/2025.
//

import SwiftUI
import ThomKit

struct OnboardingStepSubscribe: View {
    @Binding var pageSelection: Int

    // TODO: bind subscribe
    func handleSubscribe() {
    }

    var body: some View {
        VStack(alignment: .leading) {
            ZStack {
                Spacer()
                    .frame(maxWidth: .infinity)
                if #available(macOS 15.0, *) {
                    Image(systemName: "star.hexagon.fill")
                        .font(.system(size: 160, weight: .semibold))
                        .padding(.bottom, 64)
                } else {
                    Image(systemName: "star.hexagon.fill")
                        .font(.system(size: 160, weight: .semibold))
                        .padding(.bottom, 64)
                }
            }
            Text("Start with Sharing!")
                .foregroundStyle(Color(NSColor.labelColor))
                .font(.title.weight(.bold))
                .padding(.bottom, 2)
            Text("For the price of **€2,99** we would like to provide you with **250GB** of free cloud storage. With upgrade options coming in the future.")
                .foregroundStyle(Color(NSColor.secondaryLabelColor))
                .font(.title3)
                .padding(.bottom, 12)
            Button(action: handleSubscribe) {
                Text("Sign me up!")
            }
            .buttonStyle(MainButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }
}

#Preview {
    OnboardingStepSubscribe(pageSelection: .constant(0))
        .frame(width: 425, height: 600)
}
