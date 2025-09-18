//
//  Buttons.swift
//  ShareBox
//
//  Created by Thom van den Broek on 06/09/2025.
//

import SwiftUI

struct NotchButton: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isLoading) private var isLoading: Bool
    @Environment(\.isEnabled) private var isEnabled: Bool
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            configuration.label
                .opacity(isLoading ? 0 : 1)
            Color.white.mask {
                ProgressView()
                    .controlSize(.small)
            }
            .opacity(isLoading ? 1 : 0)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 36)
        .background(
            Color("Colors/TileBackground")
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .foregroundColor(.white)
        .overlay {
            if isHovered {
                RoundedRectangle(cornerRadius: 18)
                    .fill(.clear)
                    .stroke(.gray, style: .init(lineWidth: 2))
            }
        }
        .font(.body.weight(.semibold))
        .opacity(isEnabled ? 1 : 0.4)
        .onHover { hovering in
            withAnimation {
                isHovered = hovering
            }
        }
    }
}
