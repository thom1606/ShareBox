//
//  GroupRowView.swift
//  ShareBox
//
//  Created by Thom van den Broek on 17/08/2025.
//

import SwiftUI

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
        HStack {
            VStack(alignment: .leading) {
                Text(group.id)
                if group.fileCount == 1 {
                    Text("1 file, expires on \(expiresAtDisplay)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                } else {
                    Text("\(group.fileCount) files, expires on \(expiresAtDisplay)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Button(action: {
                if let url = URL(string: group.url) {
                    NSWorkspace.shared.open(url)
                }
            }, label: {
                Image(systemName: "globe")
                    .foregroundStyle(.blue)
            })
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    GroupRowView(group: .init(id: "test", downloadCount: 3, fileCount: 3, expiresAt: "2025-01-01T12:00:00.000Z", url: ""))
}
