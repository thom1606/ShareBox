//
//  SignInPage.swift
//  ShareBox
//
//  Created by Thom van den Broek on 07/09/2025.
//

import SwiftUI

struct SignInPage: View {
    var user: User
    var cancelText: LocalizedStringKey = "Later"
    var onCancel: () -> Void
    var onContinue: () -> Void

    @State private var approvedTerms: Bool = false

    var body: some View {
        InformationPage(cancelText: cancelText, onCancel: onCancel, continueText: "Sign up", disabled: !approvedTerms, onContinue: handleContinue) {
            HStack {
                VStack(alignment: .leading, spacing: 30) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Create your account")
                            .fontDesign(.serif)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("Sign up using your **Apple ID** to secure your own space in the ShareBox cloud and sync settings across multiple devices.")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                    }
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Toggle("", isOn: $approvedTerms)
                                .toggleStyle(.switch)
                                .controlSize(.mini)
                            VStack(alignment: .leading) {
                                Text("I have read and agree to the [Terms and Conditions](https://shareboxed.app/terms-and-conditions) and [Privacy Policy](https://shareboxed.app/privacy-policy).")
                            }
                        }
                        .offset(x: -10)
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
                onContinue()
            }
        }
    }

    private func handleContinue() {
        self.user.login()
    }
}
