//
//  UploaderSlimScene.swift
//  ShareBox
//
//  Created by Thom van den Broek on 16/09/2025.
//

import SwiftUI

struct UploaderSlimScene: View {
    @Environment(UploaderViewModel.self) private var uploader

    var body: some View {
        let totalProgress: CGFloat = CGFloat(uploader.uploadProgress.keys.count) * 100.0
        let currentProgress: CGFloat = CGFloat(uploader.uploadProgress.values.reduce(0.0, { $0 + $1.uploadProgress }))

        VStack(alignment: .center, spacing: 16) {
            Image(systemName: "cloud.fill")
                .foregroundStyle(.white)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Color.gray.opacity(0.3)
                    if totalProgress > 0 {
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            Color.accent
                                .frame(height: geo.size.height / totalProgress * currentProgress)
                                .animation(.smooth, value: currentProgress)
                        }
                    }
                }
            }
            .mask(RoundedRectangle(cornerRadius: 2))
            .frame(width: 4)
            Image(systemName: "laptopcomputer")
                .foregroundStyle(.white)
        }
        .frame(width: 40)
        .padding(.vertical, 16)
    }
}

#Preview {
    UploaderSlimScene()
}
