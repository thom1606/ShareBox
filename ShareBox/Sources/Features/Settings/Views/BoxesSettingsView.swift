//
//  BoxesSettingsView.swift
//  ShareBox
//
//  Created by Thom van den Broek on 17/08/2025.
//

import SwiftUI

struct BoxesSettingsView: View {
    private let apiService = ApiService()
    @State private var groups: [SharedGroup] = []
    @State private var loaded: Bool = false

    private func load() async {
        do {
            self.groups = try await apiService.get(endpoint: "/api/groups")
            self.loaded = true
        } catch {
            generalLogger.warning("Failed to fetch groups: \(error.localizedDescription)")
        }
    }

    var body: some View {
        Form {
            Section(header: Text("Open Boxes")) {
                if self.loaded {
                    ForEach(groups) { group in
                        GroupRowView(group: group)
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
    BoxesSettingsView()
}
