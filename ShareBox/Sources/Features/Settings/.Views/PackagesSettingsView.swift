//
//  BoxesSettingsView.swift
//  ShareBox
//
//  Created by Thom van den Broek on 17/08/2025.
//

import SwiftUI

struct PackagesSettingsView: View {
    var user: User

    private let apiService = ApiService()
    @State private var groups: [SharedGroup] = []
    @State private var loaded: Bool = false

    private func load() async {
        do {
            self.groups = try await apiService.get(endpoint: "/api/groups")
            self.loaded = true
        } catch {
            self.loaded = true
            generalLogger.warning("Failed to fetch groups: \(error.localizedDescription)")
        }
    }

    var body: some View {
        Form {
            Section(header: Text("Open Packages")) {
                if self.loaded {
                    if !user.authenticated || user.userData == nil {
                        HStack {
                            Spacer()
                            Text("You are not signed in to ShareBox.")
                            Spacer()
                        }
                    } else if groups.isEmpty {
                        HStack {
                            Spacer()
                            Text("No open packages found.")
                            Spacer()
                        }
                    } else {
                        ForEach(groups) { group in
                            GroupRowView(group: group)
                        }
                    }
                } else {
                    HStack {
                        Spacer()
                        ProgressView()
                            .controlSize(.small)
                        Spacer()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .task {
            await load()
        }
    }
}

#Preview {
    PackagesSettingsView(user: .init())
}
