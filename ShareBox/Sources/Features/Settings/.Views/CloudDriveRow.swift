//
//  CloudDriveRow.swift
//  ShareBox
//
//  Created by Thom van den Broek on 12/09/2025.
//

import SwiftUI

struct CloudDriveRow: View {
    @Environment(User.self) private var user
    private let api = ApiService()
    var drive: CloudDrive

    @State private var presentingConfirmDeleteAlert: Bool = false

    var driveName: String {
        switch drive.provider {
        case "GOOGLE":
            return "Google Drive"
        default:
            return "-"
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image("Images/Drives/Colored/\(drive.provider)")
                .resizable()
                .frame(width: 26, height: 26)
            Text(driveName)
            Spacer()
            Button("Disconnect", action: {
                self.presentingConfirmDeleteAlert.toggle()
            })
        }
        .alert("Are you sure?", isPresented: $presentingConfirmDeleteAlert, actions: {
            Button("Disconnect", role: .destructive) {
                Task {
                    await user.removeDrive(id: drive.id)
                }
            }
            Button("Cancel", role: .cancel) { }
        }, message: {
            Text("Are you sure you want to disconnect this drive? This action is irreversible.")
        })
    }
}
