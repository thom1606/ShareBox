//
//  OnboardingWelcomeView.swift
//  ShareBox
//
//  Created by Thom van den Broek on 17/08/2025.
//

import SwiftUI

struct OnboardingWelcomeView: View {
    @Binding var pageSelection: Int
    var user: User
    var isLoading: Bool

    let finalTitleText = String(localized: "Welcome to ShareBox")
    @State private var titleText = ""

    var body: some View {
        OnboardingPage(continueText: "Start setup", isLoading: isLoading, onContinue: handleContinue) {
            VStack(spacing: 30) {
                Image("Images/Logo")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 100, height: 100)
                VStack(spacing: 5) {
                    Text(titleText)
                        .font(.system(size: 60, weight: .bold, design: .serif))
                        .foregroundStyle(.primary)
                        .onAppear { typeWriter(at: 0) }
                    Text("Let's set you up with an easier, more efficient way of sharing files.")
                        .font(.title.weight(.regular))
                        .foregroundStyle(.secondary)
                        .frame(width: 330)
                }
                .multilineTextAlignment(.center)
            }
        }
    }

    private func typeWriter(at position: Int = 0) {
      if position < finalTitleText.count {
          titleText.append(finalTitleText[position])
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
              // call this function again with the character at the next position
              typeWriter(at: position + 1)
          }
      }
    }

    private func handleContinue() {
        if user.authenticated {
            pageSelection += 2
        } else {
            pageSelection += 1            
        }
    }
}

#Preview {
    OnboardingWelcomeView(pageSelection: .constant(0), user: .init(), isLoading: true)
}
