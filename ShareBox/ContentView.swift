//
//  ContentView.swift
//  ShareBox
//
//  Created by Thom van den Broek on 11/08/2025.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        WelcomeView {
            OnboardingStack {
                SettingsView()                
            }
        }
    }
}

#Preview {
    ContentView()
        .frame(width: 425, height: 600)
}
