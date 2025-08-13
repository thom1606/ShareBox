//
//  GroupRowView.swift
//  ShareBox
//
//  Created by Thom van den Broek on 12/08/2025.
//

import SwiftUI
import ThomKit

struct GroupRowView: View {
    var group: SharedGroup

    private var expiresAtDate: Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        return formatter.date(from: group.expiresAt)
    }

    private var expiresAtDisplay: String {
        guard let date = expiresAtDate else {
            return group.expiresAt
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(alignment: .center) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.id)
                        .foregroundStyle(.blue)
                        .fontWeight(.medium)
                    // Subtitle
                    Text("\(group.fileCount) files, \(group.downloadCount) downloads, expires on \(expiresAtDisplay)")
                }
                .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    Button(action: {
                        if let url = URL(string: group.url) {
                            NSWorkspace.shared.open(url)
                        }
                    }, label: {
                        Image(systemName: "globe")
                    })
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            SeparatorView()
        }
    }
}

#Preview {
    GroupRowView(group: .init(id: "ecc4c01d-8da", downloadCount: 3, fileCount: 24, expiresAt: "2025-08-14T11:48:45.000Z", url: "https://www.google.com"))
}
