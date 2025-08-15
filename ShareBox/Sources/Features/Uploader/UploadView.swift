//
//  UploadView.swift
//  ShareBox
//
//  Created by Thom van den Broek on 14/08/2025.
//

import SwiftUI

struct UploadView: View {
    @State private var state = UploaderViewModel()

    private var dragAndDropHandler: some View {
        Color.clear
            // We add a small space for the drag and drop to activate from.
            // And we enlarge it when the UI is opened so dropping files is active over the whole width and height.
            .frame(width: state.pulloutPercentage == 0 ? 23 : Constants.Uploader.windowWidth)
            .onDrop(of: [.fileURL], isTargeted: $state.isDropTarget, perform: state.onItemsDrop)
            .onChange(of: state.isDropTarget) {
                if !state.canInteract { return }
                // If a file is currently being dropped, we want to fully open the UI
                if state.isDropTarget {
                    state.showOverlay(systemName: "document.badge.plus", timed: false)
                    state.fileCountBeforeDrop = state.selectedItems.count
                    state.pulloutPercentage = 1
                    state.offScreen = false
                } else if !state.didDropFiles {
                    // When the file is being moved away, we want it to wait for the state to update quickly
                    // before making a decision to fully close the UI or not.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        if !state.canInteract || state.isDropTarget { return }
                        state.closeOverlay()
                        if state.selectedItems.count == state.fileCountBeforeDrop {
                            state.pulloutPercentage = 0
                            if state.selectedItems.isEmpty {
                                state.startClosingUI()
                            }
                        }
                    }
                }
            }
            .onHover { isOver in
                if !state.canInteract || !isOver { return }
                state.offScreen = false
                state.pulloutPercentage = 1
            }
            // Only listen for hover events when the UI is off screen, otherwise it should take over and
            // nothing should be blocking the UI interactions
            .allowsHitTesting(state.offScreen)
    }

    private var overlay: some View {
        ZStack(alignment: .center) {
            Color.black
            Image(systemName: state.overlayImage ?? "questionmark.circle.dashed")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white)
                .frame(width: 30, height: 30)
                .scaleEffect(state.presentingOverlay ? 1 : 0.3)
                .rotationEffect(state.presentingOverlay ? .degrees(0) : .degrees(-180))
                .opacity(state.presentingOverlay ? 1 : 0)
                .animation(.bouncy, value: state.presentingOverlay)
        }
        .opacity(state.presentingOverlay ? 1 : 0)
        .animation(.spring(duration: 0.3), value: state.presentingOverlay)
        .allowsHitTesting(state.presentingOverlay)
    }

    private var fileList: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(state.selectedItems, id: \.self) { item in
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

            NotchShape(pulloutPercentage: state.pulloutPercentage)
                .fill(.black)
                .animation(.spring(duration: 0.3), value: state.pulloutPercentage)

            ZStack {
                Color.clear
                fileList
                // Overlay which can be toggled by state model
                overlay
            }
            .padding(.horizontal, 10)
            // We will add some initial vertical padding for the content
            .padding(.vertical, 40)
            .onHover { isOver in
                if !state.canInteract { return }
                if isOver {
                    state.pulloutPercentage = 1
                } else {
                    state.pulloutPercentage = 0
                    if state.selectedItems.isEmpty {
                        state.startClosingUI()
                    }
                }
            }
            // And after that we will add some additional padding which the hover will be placed within
            .padding(.vertical, 50)
            .offset(x: state.pulloutPercentage == 0 ? -80 : 0)
            .animation(.spring(duration: 0.3), value: state.pulloutPercentage)
        }
        .offset(x: state.offScreen ? -23 : 0)
        .animation(.spring(duration: 0.3), value: state.offScreen)
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
