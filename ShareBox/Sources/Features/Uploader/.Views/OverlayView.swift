//
//  OverlayView.swift
//  ShareBox
//
//  Created by Thom van den Broek on 15/08/2025.
//

import SwiftUI

struct LoadingOverlayView: View {
    var active: Bool

    var body: some View {
        ZStack(alignment: .center) {
            Color.black
            Color.white.mask {
                ProgressView()
                    .controlSize(.regular)
            }
            .animation(.bouncy, value: active)
        }
        .opacity(active ? 1 : 0)
        .animation(.spring(duration: 0.3), value: active)
        .allowsHitTesting(active)
    }
}

struct OverlayView: View {
    var systemName: String
    var color: Color = .white
    var active: Bool

    var body: some View {
        ZStack(alignment: .center) {
            Color.black
            Image(systemName: systemName)
                .resizable()
                .scaledToFit()
                .foregroundStyle(color)
                .frame(width: 30, height: 30)
                .scaleEffect(active ? 1 : 0.3)
                .rotationEffect(active ? .degrees(0) : .degrees(-180))
                .animation(.bouncy, value: active)
        }
        .opacity(active ? 1 : 0)
        .animation(.spring(duration: 0.3), value: active)
        .allowsHitTesting(active)
    }
}

#Preview {
    OverlayView(systemName: "document.badge.plus", active: true)
}
