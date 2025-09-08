//
//  DrivesSettingsView.swift
//  ShareBox
//
//  Created by Thom van den Broek on 08/09/2025.
//

import SwiftUI

struct DrivesSettingsView: View {
    var body: some View {
        Form {
            Section(header: Text("Cloud Drives")) {
                Text("Drive support coming soon...")
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}

#Preview {
    DrivesSettingsView()
}
