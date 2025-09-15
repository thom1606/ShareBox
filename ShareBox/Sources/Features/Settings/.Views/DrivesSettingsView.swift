//
//  DrivesSettingsView.swift
//  ShareBox
//
//  Created by Thom van den Broek on 08/09/2025.
//

import SwiftUI

struct DrivesSettingsView: View {
    @Environment(User.self) private var user
    @Environment(\.openWindow) private var openWindow
    private let api = ApiService()

    @State private var selectedProvider: DriveProvider?

    var body: some View {
        Form {
            Section(header: Text("Cloud Drives")) {
                ForEach(user.drivesData) { drive in
                    CloudDriveRow(drive: drive)
                }
                if user.subscriptionData?.status == .active || user.drivesData.isEmpty {
                    HStack {
                        Spacer()
                        Menu {
                            if !user.drivesData.contains(where: { $0.provider == .ICLOUD }) {
                                Button("iCloud") { startLink(.ICLOUD) }
                            }
                            Button("Google Drive") { startLink(.GOOGLE) }
                            Button("OneDrive") { startLink(.ONEDRIVE) }
                            Button("Dropbox") { startLink(.DROPBOX) }
                        } label: {
                            Image(systemName: "plus")
                        }
                        .menuStyle(.borderedButton)
                        .frame(width: 44)
                    }
                } else {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Show multiple drives?")
                            Text("Wnat more than 1 drive visible in your sidebar? Upgrade your subscription.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(action: {
                            openWindow(id: "subscribe")
                        }, label: {
                            ZStack {
                                Text("Upgrade")
                            }
                        })
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private func startLink(_ type: DriveProvider) {
        Task {
            do {
                if type == .ICLOUD {
                    // Check locally if icloud is allowed
                    let res: ApiService.BasicSuccessResponse = try await api.post(endpoint: "/api/drives/link", parameters: [
                        "type": type.rawValue
                    ])
                    if res.success {
                        await user.refresh()
                    }
                } else {
                    let res: ApiService.BasicRedirectResponse = try await api.post(endpoint: "/api/drives/link", parameters: [
                        "type": type.rawValue
                    ])
                    NSWorkspace.shared.open(URL(string: res.redirectUrl)!)
                }
            } catch {}
        }
    }
}

private struct SessionResponse: Codable {
    var accessToken: String
}
