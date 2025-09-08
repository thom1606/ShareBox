//
//  NotchUploadingScene.swift
//  ShareBox
//
//  Created by Thom van den Broek on 06/09/2025.
//

import SwiftUI

struct NotchUploadingScene: View {
    @Environment(UploaderViewModel.self) private var uploader

    var geo: GeometryProxy

    private var fileList: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(uploader.droppedItems, id: \.self) { item in
                    ItemPreview(
                        state: uploader,
                        item: item
                    )
                }
            }
            // Extra padding for fades
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: .infinity)
    }

    var body: some View {
        ZStack(alignment: .center) {
            if uploader.uploadState == .preparingGroup {
                Color.white.mask {
                    ProgressView()
                        .controlSize(.regular)
                }
            } else {
                Group {
                    let openStanding = uploader.uploadProgress.values.contains { $0.status != .completed && $0.status != .failed }
                    let isDone = uploader.uploadState == .completed && !openStanding && !uploader.droppedItems.isEmpty

                    fileList
                        .padding(.bottom, isDone ? 36 : 0)
                    VStack(alignment: .center, spacing: 0) {
                        LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                            .frame(height: 15)
                            .allowsHitTesting(false)
                        Spacer()
                            .allowsHitTesting(false)
                        LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                            .frame(height: 15)
                            .allowsHitTesting(false)
                        if isDone {
                            Button("Done") {
                                uploader.activeUploader?.complete()
                            }
                            .buttonStyle(NotchButton())
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .frame(maxHeight: max(600, geo.size.height / 2))
        .padding(.vertical, 12)
    }
}

#Preview {
    GeometryReader { geo in
        NotchUploadingScene(geo: geo)
    }
}
