//
//  OnboardingSecureView.swift
//  ShareBox
//
//  Created by Thom van den Broek on 17/08/2025.
//

import SwiftUI

struct OnboardingSecureView: View {
    @Binding var pageSelection: Int
    var userData: UserDataResponse?

    @AppStorage(Constants.Settings.hiddenFilesPrefKey) private var includeHiddenFiles = false
    @AppStorage(Constants.Settings.passwordPrefKey) private var boxPassword = ""
    @AppStorage(Constants.Settings.storagePrefKey) private var storageDuration = "3_days"

    var body: some View {
        OnboardingPage(onContinue: handleContinue) {
            HStack {
                VStack(alignment: .leading, spacing: 30) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Enhance your security")
                            .fontDesign(.serif)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text("Security is important for everyone, which is why you have options to better protect your files.")
                            .foregroundStyle(.secondary)
                            .font(.title3)
                    }
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            Toggle("", isOn: $includeHiddenFiles)
                                .toggleStyle(.switch)
                                .controlSize(.mini)
                            Text("Include hidden files")
                        }
                        .offset(x: -10)
                        TextFieldView(label: "Set box password", placeholder: "password", text: $boxPassword)
                        PickerView(label: "Select storage duration", selection: $storageDuration, items: [
                            ("1_days", "1 day"),
                            ("2_days", "2 days"),
                            ("3_days", "3 days"),
                            ("5_days", "5 days"),
                            ("7_days", "7 days")
                        ])
                    }
                    .font(.title3)
                }
                .frame(width: 350)
                VStack {
                    Image(systemName: "checkmark.shield.fill")
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
        if userData != nil {
            if userData?.subscription?.status == "active" {
                pageSelection += 3
            } else {
                pageSelection += 2
            }
        } else {
            pageSelection += 1
        }
    }
}

#Preview {
    OnboardingSecureView(pageSelection: .constant(0))
}
