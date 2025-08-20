//
//  OnboardingSignInView.swift
//  ShareBox
//
//  Created by Thom van den Broek on 17/08/2025.
//

import SwiftUI

struct OnboardingSignInView: View {
    @Binding var pageSelection: Int
    var user: User

    @State private var isLoading: Bool = false

    var body: some View {
        OnboardingPage(continueText: "Sign up", isLoading: isLoading, onContinue: handleContinue) {
            HStack {
                VStack(alignment: .leading, spacing: 30) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Create your account")
                            .fontDesign(.serif)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("Sign up using your **Apple ID** to secure your own space in the ShareBox cloud.")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                    }
                }
                .frame(width: 350)
                VStack {
                    Image(systemName: "person.crop.circle.fill")
                        .foregroundStyle(.primary.opacity(0.3))
                        .font(.system(size: 250))
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.leading, 32)
            .padding(.top, 48)
        }
        .onChange(of: user.authenticated) {
            if user.authenticated {
                self.isLoading = false
                self.pageSelection += 1
            }
        }
    }

    private func handleContinue() {
        self.isLoading = true
        self.user.login()
    }
}

#Preview {
    OnboardingSignInView(pageSelection: .constant(0), user: .init())
}
