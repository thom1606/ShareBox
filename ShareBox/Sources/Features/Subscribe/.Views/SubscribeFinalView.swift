//
//  SubscribeFinalPage.swift
//  ShareBox
//
//  Created by Thom van den Broek on 07/09/2025.
//

import SwiftUI

struct SubscribeFinalView: View {
    @Environment(\.dismissWindow) private var dismissWindow

    var body: some View {
        InformationPage(continueText: "Let's go!", onContinue: handleContinue) {
            HStack {
                VStack(alignment: .leading, spacing: 30) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("You're ready!")
                            .fontDesign(.serif)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("Thank you for subscribing! You can now enjoy the full ShareBox experience.")
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
        dismissWindow()
    }
}
