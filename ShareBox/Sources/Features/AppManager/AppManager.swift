//
//  AppManager.swift
//  ShareBox
//
//  Created by Thom van den Broek on 15/09/2025.
//

import SwiftUI

struct AppManager<C: View>: View {
    @ViewBuilder var content: () -> C

    @Environment(\.openSettings) private var openSettings
    @Environment(GlobalContext.self) private var globalContext

    @State private var hasAppeared = false

    var body: some View {
        content()
            .onAppear {
                if hasAppeared { return }
                self.hasAppeared = true

                // Initialize app settings
                globalContext.initialize(openSettings: openSettings)
            }
            .opacity(hasAppeared ? 1 : 0)
    }
}
