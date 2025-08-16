//
//  UploadView.swift
//  ShareBox
//
//  Created by Thom van den Broek on 14/08/2025.
//

import SwiftUI

struct UploadView: View {
    @State private var state = UploaderViewModel()
    @AppStorage(Constants.Settings.mouseActivationPrefKey) private var enableMouseActivation = true

    private var dragAndDropHandler: some View {
        Color.black.opacity(0.001)
            // We add a small space for the drag and drop to activate from.
            // And we enlarge it when the UI is opened so dropping files is active over the whole width and height.
            .frame(width: state.uiState == .hidden || state.uiState == .peeking ? 13 : Constants.Uploader.windowWidth)
            .onDrop(of: [.fileURL], isTargeted: $state.isLiveDropTarget, perform: state.onItemsDrop)
            .onHover { isOver in
                if !enableMouseActivation { return }
                if isOver { state.isDropzoneHovered = isOver } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: { state.isDropzoneHovered = false })
                }
            }
            .allowsHitTesting(state.uiState == .hidden)
    }

    private var toolbar: some View {
        VStack(alignment: .leading) {
            ToolbarView(state: state)
            Spacer()
        }
        .offset(y: -28)
    }

    private var overlays: some View {
        ZStack(alignment: .center) {
            // Drop File Overlay
            OverlayView(systemName: "document.badge.plus", active: state.isLiveDropTarget)
            OverlayView(systemName: "xmark.seal", color: .red, active: state.showErrorOverlay)
            LoadingOverlayView(active: state.showLoadingOverlay)
        }
    }

    private var fileList: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(state.droppedItems, id: \.self) { item in
                    ItemPreview(
                        state: state,
                        item: item
                    )
                }
            }
            // Extra padding for fades
            .padding(.vertical, 10)
        }
        .frame(maxWidth: .infinity)
    }

    private var mainBody: some View {
        ZStack {
            Color.clear

            NotchShape(pulloutPercentage: state.uiState == .visible ? 1 : 0)
                .fill(.black)
                .animation(.spring(duration: 0.3), value: state.uiState)

            ZStack(alignment: .leading) {
                Color.clear
                if state.droppedItems.isEmpty {
                    HStack(spacing: 0) {
                        Spacer(minLength: 0)
                        VStack(spacing: 8) {
                            Image(systemName: "questionmark.folder")
                                .font(.largeTitle)
                                .foregroundStyle(.white)
                            Text("Start adding files")
                                .foregroundStyle(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                        }
                        Spacer(minLength: 0)
                    }
                }
                fileList

                VStack(alignment: .center) {
                    LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .bottom)
                        .frame(height: 15)
                    Spacer()
                    LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom)
                        .frame(height: 15)
                }
                .allowsHitTesting(false)

                toolbar

                // Overlay which can be toggled by state model
                overlays
            }
            .padding(.horizontal, 10)
            // We will add some initial vertical padding for the content
            .padding(.vertical, 40)
            .onHover { isOver in
                if isOver { state.isContentHovered = isOver } else {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: { state.isContentHovered = false })
                }
            }
            // And after that we will add some additional padding which the hover will be placed within
            .padding(.vertical, 50)
            .offset(x: state.uiState == .peeking || state.uiState == .hidden ? -115 : 0)
            .animation(.spring(duration: 0.3), value: state.uiState)
            .mask(
                NotchShape(pulloutPercentage: state.uiState == .visible ? 1 : 0)
                    .fill(.white)
            )
        }
        .offset(x: state.uiState == .hidden ? -23 : 0)
        .animation(.spring(duration: 0.3), value: state.uiState)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Color.clear

                // Height Bound Wrapper
                ZStack(alignment: .leading) {
                    Color.clear
                    // Main Content of the notch
                    mainBody
                    // Drag & Drop Handler
                    dragAndDropHandler
                }
                .frame(width: geo.size.width, height: max(600, geo.size.height / 2))
            }
        }
        // Listen for mouse changes so we can move the window to the active screen when needed
        .background(WindowAccessor { window in
            state.mouseListener.startTrackingMouse(window: window)
        })
    }
}

#Preview {
    UploadView()
        .frame(width: 100, height: 800)
}
