//
//  DrivesSettingsView.swift
//  ShareBox
//
//  Created by Thom van den Broek on 08/09/2025.
//

import SwiftUI

struct DrivesSettingsView: View {
    @Environment(User.self) private var user
    private let api = ApiService()

    var body: some View {
        Form {
            Section(header: Text("Cloud Drives")) {
                ForEach(user.drivesData) { drive in
                    CloudDriveRow(drive: drive)
                }
                Button("Connect Google", action: {
                    Task {
                        do {
                            let res: ApiService.BasicRedirectResponse = try await api.post(endpoint: "/api/drives/link", parameters: [
                                "type": "google"
                            ])
                            NSWorkspace.shared.open(URL(string: res.redirectUrl)!)
                        } catch {
                            print("aaaaa", error)
                        }
                    }
                })
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

private struct SessionResponse: Codable {
    var accessToken: String
}
