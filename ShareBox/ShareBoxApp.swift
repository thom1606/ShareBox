//
//  ShareBoxApp.swift
//  ShareBox
//
//  Created by Thom van den Broek on 11/08/2025.
//

import SwiftUI
import ServiceManagement
import ThomKit

@main
struct ShareBoxApp: App {
    var body: some Scene {
        WindowGroup {
            FrostedWindow {
                ContentView()
            }
            .frame(width: 425, height: 600)
            .onAppear {
                try? Utilities.launchHelperApp()
            }
        }
        .defaultSize(width: 425, height: 600)
        .windowResizability(.contentSize)
    }
}
