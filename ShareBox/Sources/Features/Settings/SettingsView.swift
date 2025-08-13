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
    
    @State private var isNewUpdateAvailable = false
    @State private var showFiles = false
    @State private var loadingBilling = false
    private let api = ApiService()
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack(spacing: 0) {
                    Text("Share your files easily with one click. Your shared links will be available for a set time. After this, everything will be removed forever. For support [open an issue](https://github.com/thom1606/ShareBox/issues/new?labels=support).")
                        .foregroundStyle(.secondary)
                        .font(.body)
                    Spacer(minLength: 0)
                }
                Button(action: {
                    showFiles.toggle()
                }, label: {
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
                    Text("Do you wish to include hidden files from your folders to your upload? Please be aware that hidden files could be sensitive and some should not be shared.")
                        .foregroundStyle(.secondary)
                        .font(.body)
                }
                LabeledTextFieldView(label: "Password", placeholder: "My Password", text: $groupsPassword)
                SeparatorView()
                
                VStack(spacing: 10) {
                    HStack(spacing: 0) {
                        Text("You can manage all your billing and subscription details here.")
                            .foregroundStyle(.secondary)
                            .font(.body)
                        Spacer(minLength: 0)
                    }
                    Button(action: openBilling, label: {
                        ZStack {
                            Text("Manage my Billing")
                                .opacity(loadingBilling ? 0 : 1)
                            ProgressView()
                                .controlSize(.small)
                                .opacity(loadingBilling ? 1 : 0)
                        }
                    })
                    .buttonStyle(MainButtonStyle(fullWidth: true))
                }
                if isNewUpdateAvailable {
                    SeparatorView()
                    VStack(spacing: 10) {
                        Text("There is a new update available for ShareBox! Please download the latest version to enjoy new features and improvements.")
                            .foregroundStyle(.secondary)
                            .font(.body)
                        Link("New Update Available", destination: URL(string: "https://sharebox.thomvandenbroek.com/download")!)
                            .buttonStyle(MainButtonStyle(fullWidth: true))
                    }
                }

                Rectangle()
                    .fill(.clear)
                    .frame(width: 30, height: 24)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .clipped()
        .onAppear(perform: load)
        .sheet(isPresented: $showFiles) {
            BoxesView(showFiles: $showFiles)
        }
    }
    
    /// Check for available updates
    private func checkForUpdates() {
        // get app version from Info.plist
        guard let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String else {
            print("Failed to get app version")
            return
        }
        let encodedAppVersion = appVersion.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? appVersion
        let updateURL = URL(string: "https://sharebox.thomvandenbroek.com/api/update?version=\(encodedAppVersion)")!
        URLSession.shared.dataTask(with: updateURL) { _, response, error in
            guard error == nil else {
                print("Failed to check for updates: \(error?.localizedDescription ?? "Unknown error")")
                return
            }
            // Check if the current version is the latest available
            if let response = response as? HTTPURLResponse, response.statusCode == 200 {
                DispatchQueue.main.async {
                    isNewUpdateAvailable = true
                }
            }
        }.resume()
    }
    
    private func openBilling() {
        if loadingBilling { return }
        withAnimation { self.loadingBilling = true }
        Task {
            do {
                let res: BillingResponse = try await api.get(endpoint: "/api/billing")
                NSWorkspace.shared.open(URL(string: res.url)!)
                DispatchQueue.main.async {
                    withAnimation { self.loadingBilling = false }
                }
            } catch {
                print(error)
                DispatchQueue.main.async {
                    withAnimation { self.loadingBilling = false }
                }
            }
        }
    }
    
    private func load() {
        // Check for updates in ShareBox
        checkForUpdates()
    }
}

private struct BillingResponse: Codable {
    var url: String
}

#Preview {
    SettingsView()
        .frame(width: 425, height: 600)
}
