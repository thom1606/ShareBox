//
//  UploadView.swift
//  ShareBox
//
//  Created by Thom van den Broek on 14/08/2025.
//

import SwiftUI

struct UploaderView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings
    @Environment(\.settingsTab) private var settingsTab
    @AppStorage(Constants.Settings.mouseActivationPrefKey) private var enableMouseActivation = true
    @AppStorage(Constants.Settings.keepNotchOpenWhileUploadingPrefKey) private var keepNotchOpen = true
    @AppStorage(Constants.Settings.completedOnboardingPrefKey) private var completedOnboarding = false

    @State private var state = UploaderViewModel()
    @State private var hasAppeared = false

    private var notchXOffset: CGFloat {
        if state.uiState == .hidden { return -70 }
        if state.uiState == .peeking { return -114 }
        return -10
    }

    private var notchWidth: CGFloat {
        if state.uiState == .visible { return 130 }
        if state.uiState == .peeking { return 130 }
        return 70
    }

    private var notchCornerRadius: CGFloat {
        if state.uiState == .visible { return 32 }
        if state.uiState == .peeking { return 32 }
        return 12
    }

    private var hoverHelper: some View {
        GeometryReader { geo in
            HStack {
                Color.black.opacity(0.001)
                    .onHover(perform: { isOver in
                        state.onHover(isOver: isOver)
                    })
                    .allowsHitTesting(enableMouseActivation && state.uiState == .hidden)
                    .frame(width: state.uiState == .hidden || state.uiState == .peeking ? 13 : geo.size.width)
                Spacer()
            }
        }
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Color.clear

                VStack(alignment: .leading, spacing: -1) {
                    NotchCorner()
                        .fill(.black)
                        .frame(width: notchCornerRadius * 2, height: notchCornerRadius * 2)
                        .animation(.bouncy, value: state.uiState)
                        .offset(x: 5)
                    ZStack(alignment: .leading) {
                        if state.uploadState == .idle {
                            NotchIntroScene()
                                .transition(.opacity)
                        } else {
                            NotchUploadingScene(geo: geo)
                        }
                    }
                    .padding(.vertical, 4)
                    .padding(.leading, 10)
                    .frame(maxWidth: notchWidth)
                    .background(
                        UnevenRoundedRectangle(cornerRadii: .init(bottomTrailing: notchCornerRadius, topTrailing: notchCornerRadius))
                            .fill(.black)
                            .animation(.bouncy, value: state.uiState)
                    )
                    .onHover { isOver in
                        if state.uiState == .hidden { return }
                        state.onHover(isOver: isOver)
                    }
                    NotchCorner(inverted: true)
                        .fill(.black)
                        .frame(width: notchCornerRadius * 2, height: notchCornerRadius * 2)
                        .animation(.bouncy, value: state.uiState)
                        .offset(x: 5)
                }
                .offset(x: notchXOffset)
                .overlay(hoverHelper)
                .animation(.bouncy, value: notchXOffset)
            }
            .environment(self.state)
        }
        .frame(width: Constants.Uploader.windowWidth)
        // Listen for mouse changes so we can move the window to the active screen when needed
        .background(WindowAccessor { window in
            state.mouseListener.startTrackingMouse(window: window)
        })
        .onAppear {
            if hasAppeared { return }
            self.hasAppeared = true
            if !completedOnboarding {
                openWindow(id: "onboarding")
            }
            state.onAppear(openSettings: { view in
                if view != nil {
                    settingsTab.wrappedValue = view!
                }
                openSettings()
            })
            state.keepNotchOpen = keepNotchOpen
        }
        .onChange(of: keepNotchOpen) {
            state.keepNotchOpen = keepNotchOpen
        }
        .onChange(of: state.uiMovable) {
            state.mouseListener.paused = !state.uiMovable
        }
    }
}

#Preview {
    UploaderView()
        .frame(width: 130, height: 800)
}
