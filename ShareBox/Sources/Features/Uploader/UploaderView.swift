//
//  UploadView.swift
//  ShareBox
//
//  Created by Thom van den Broek on 14/08/2025.
//

import SwiftUI

struct UploaderView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.settingsTab) private var settingsTab
    @Environment(GlobalContext.self) private var globalContext
    @AppStorage(Constants.Settings.mouseActivationPrefKey) private var enableMouseActivation = true
    @AppStorage(Constants.Settings.keepNotchOpenWhileUploadingPrefKey) private var keepNotchOpen = true
    @AppStorage(Constants.Settings.completedOnboardingPrefKey) private var completedOnboarding = false

    @State private var state = UploaderViewModel()
    @State private var hasAppeared = false

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Color.clear
                DynamicNotch(
                    compact: {
                        UploaderIntroScene()
                    },
                    slim: {
                        UploaderSlimScene()
                            .frame(maxHeight: max(600, geo.size.height / 2))
                    },
                    expanded: {
                        UploaderUploadingScene()
                            .frame(maxHeight: max(600, geo.size.height / 2))
                    }
                )
            }
        }
        .environment(self.state)
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
            state.onAppear(globalContext: globalContext)
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
