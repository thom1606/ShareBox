//
//  BoxesView.swift
//  ShareBox
//
//  Created by Thom van den Broek on 12/08/2025.
//

import SwiftUI

struct BoxesView: View {
    @Binding var showFiles: Bool

    @State private var groups: [SharedGroup] = []
    @State private var loaded: Bool = false

    private let apiService = ApiService()

    var body: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .leading) {
                Button(action: { showFiles = false }, label: {
                    Image(systemName: "multiply.circle")
                })
                .buttonStyle(.plain)
                HStack {
                    Spacer()
                    Text("Your Shared Boxes")
                    Spacer()
                }
            }
            .font(.headline)
            .padding(6)
            if !self.loaded {
                VStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.bottom, 6)
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(groups) { group in
                            GroupRowView(group: group)
                        }
                    }
                }
            }
        }
        .frame(width: 600, height: 450)
        .task { await load() }
    }

    private func load() async {
        do {
            self.groups = try await apiService.get(endpoint: "/api/groups")
            self.loaded = true
        } catch {
            generalLogger.warning("Failed to fetch groups: \(error.localizedDescription)")
        }
    }
}

#Preview {
    BoxesView(showFiles: .constant(false))
}
