//
//  ShareBoxApp.swift
//  ShareBox
//
//  Created by Thom van den Broek on 11/08/2025.
//

import SwiftUI
import ServiceManagement

@main
struct ShareBoxApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    try? Utilities.launchHelperApp()
                }
        }
    }
}
