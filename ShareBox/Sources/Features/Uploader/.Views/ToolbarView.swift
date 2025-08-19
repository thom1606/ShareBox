//
//  ToolbarView.swift
//  ShareBox
//
//  Created by Thom van den Broek on 16/08/2025.
//

import SwiftUI

struct ToolbarView: View {
    @Environment(\.openSettings) private var openSettings

    var state: UploaderViewModel

    private var activeItemCount: Int {
        var total = 1
        if state.uploadState == .completed && !hasOpenStandingProgresses && !state.droppedItems.isEmpty { total += 1 }
        return total
    }

    private var hasOpenStandingProgresses: Bool {
        for item in state.uploadProgress.values where item.status != .completed && item.status != .failed {
            return true
        }
        return false
    }

    var body: some View {
        HStack(spacing: 8) {
            Button(action: { openSettings() }, label: {
                Image(systemName: "gearshape")
            })
            .buttonStyle(.plain)
            if state.uploadState == .completed && !hasOpenStandingProgresses && !state.droppedItems.isEmpty {
                Button(action: state.gracefullyClose, label: {
                    Image(systemName: "checkmark.circle")
                })
                .buttonStyle(.plain)
            }
        }
        .font(.title3)
        .foregroundStyle(.white)
        .padding(.horizontal, 6)
        .padding(.vertical, 6)
        .background(
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 20)
                    .fill(.white.opacity(0.25))
                    .frame(width: activeItemCount == 1 ? geo.size.height : geo.size.width, height: geo.size.height)
                    .animation(.spring(duration: 0.3), value: geo.size.width)
            }
        )
        .overlay(
            Rectangle()
                .fill(.black)
                .opacity(state.hasActiveOverlay ? 1 : 0)
                .animation(.spring(duration: 0.3), value: state.hasActiveOverlay)
                .allowsHitTesting(state.hasActiveOverlay)
        )
    }
}

#Preview {
    ToolbarView(state: .init())
}
