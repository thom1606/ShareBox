//
//  AboutSettingsView.swift
//  ShareBox
//
//  Created by Thom van den Broek on 16/08/2025.
//

import SwiftUI

struct AboutSettingsView: View {
    var body: some View {
        let buildNumber = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
        let buildVersion = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown"

        Form {
            Section(header: Text("App Details")) {
                HStack {
                    Text("Build number")
                    Spacer()
                    Text(buildNumber)
                }
                HStack {
                    Text("Build version")
                    Spacer()
                    Text(buildVersion)
                }
            }

            Section(header: Text("Developer")) {
                Text("Developed by Thom van den Broek")
                Link("Visit Website", destination: URL(string: "https://shareboxed.app")!)
            }

            Section(header: Text("Support")) {
                Link("Contact Support", destination: URL(string: "mailto:support@shareboxed.app")!)
                Link("Feedback", destination: URL(string: "https://github.com/thom1606/ShareBox/issues/new")!)
            }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    AboutSettingsView()
}
