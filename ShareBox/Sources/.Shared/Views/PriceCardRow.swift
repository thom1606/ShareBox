//
//  PriceCardRow.swift
//  ShareBox
//
//  Created by Thom van den Broek on 07/09/2025.
//

import SwiftUI

struct PriceCardRow: View {
    var option: PriceOption

    @State private var hovering: Bool = false

    var body: some View {
        HStack(spacing: 0) {
            HStack(alignment: .center, spacing: 6) {
                Image(systemName: option.included ? "checkmark.seal" : "xmark.seal")
                    .foregroundStyle(option.included ? .green : Color.secondary)
                    .offset(y: 1)
                Text(option.text)
                    .foregroundStyle(.secondary)
            }
            .overlay {
                if option.included {
                    ZStack {}
                } else {
                    Rectangle()
                        .fill(Color.primary.opacity(0.3))
                        .frame(height: 2)
                        .offset(y: 1)
                }
            }
            Spacer(minLength: 16)
            if let description = option.description {
                Image(systemName: "info.circle")
                    .foregroundStyle(.primary)
                    .onHover(perform: { isOver in
                        hovering = isOver
                    })
                    .popover(isPresented: $hovering) {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(description.title)
                                .font(.headline)
                            Text(description.text)
                                .font(.body)
                                .padding(.top, 3)
                                .foregroundStyle(.secondary)
                        }
                        .frame(minWidth: 200, idealWidth: 200, maxWidth: 200)
                        .padding(10)
                    }
            }
        }
    }
}

#Preview {
    PriceCardRow(option: .init(text: "250GB of ShareBox uploads"))
}
