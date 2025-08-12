//
//  SettingsView.swift
//  ShareBox
//
//  Created by Thom van den Broek on 11/08/2025.
//

import SwiftUI
import ThomKit

struct SettingsView: View {
    @AppStorage(Constants.Settings.storagePrefKey, store: userDefaults) private var selectedDuration = "3_days"
    @AppStorage(Constants.Settings.passwordPrefKey, store: userDefaults) private var groupsPassword = ""
    @AppStorage(Constants.Settings.hiddenFilesPrefKey, store: userDefaults) private var hiddenFilesPrefKey = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 0) {
                    Text("Share your files easily with one click. Your shared links will be available for a set time. After this, everything will be removed forever.")
                        .foregroundStyle(.secondary)
                        .font(.body)
                    Spacer(minLength: 0)
                }
                // TODO: add shared file list
                Button(action: {}, label: {
                    Text("View my Shared Files")
                })
                .buttonStyle(MainButtonStyle(fullWidth: true))
                SeparatorView()
                PickerView(label: "Store Duration", selection: $selectedDuration, items: [
                    ("5_minutes", "5 Minutes"),
                    ("1_days", "24 Hours"),
                    ("2_days", "48 Hours"),
                    ("3_days", "3 Days"),
                    ("5_days", "5 Days"),
                    ("7_days", "1 Week")
                ])
                VStack {
                    CheckboxView(label: "Include Hidden Files", checked: $hiddenFilesPrefKey)
                    Text("Do you wish to include hidden files from your folders to your upload. Please be aware that hidden files could be sensitive and some should not be shared.")
                        .foregroundStyle(.secondary)
                        .font(.body)
                }
                LabeledTextFieldView(label: "Password", placeholder: "My Password", text: $groupsPassword)
                SeparatorView()
                VStack {
                    Text("There is a new update available for ShareBox! Please download the latest version to enjoy new features and improvements.")
                        .foregroundStyle(.secondary)
                        .font(.body)
                    // TODO: link
                    Button(action: {}, label: {
                        Text("New Update Available")
                    })
                    .buttonStyle(MainButtonStyle(fullWidth: true))
                }
                Rectangle()
                    .fill(.clear)
                    .frame(width: 30, height: 24)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .clipped()
    }
}

#Preview {
    SettingsView()
        .frame(width: 425, height: 600)
}
