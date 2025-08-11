//
//  ProgressVie.swift
//  ShareBox.Helper
//
//  Created by Thom van den Broek on 11/08/2025.
//
import SwiftUI

struct ProgressView: View {
    var progress: CGFloat = 0

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 20)
                    .fill(.blue)
                    .frame(width: 3, height: geo.size.height * progress / 100)
                    .animation(.spring, value: progress)
                Spacer(minLength: 0)
            }
            .background(.white.opacity(0.2))
            .mask(RoundedRectangle(cornerRadius: 100))
        }
        .frame(width: 3)
    }
}

#Preview {
    ProgressView()
        .frame(width: 10, height: 300)
}
