//
//  OnboardingStepFinal.swift
//  ShareBox
//
//  Created by Thom van den Broek on 12/08/2025.
//

import SwiftUI
import ThomKit

struct OnboardingStepFinal: View {
    func handleComplete() {
        let task = Process()
        task.launchPath = "/usr/bin/env"
        task.arguments = ["pluginkit", "-e", "use", "-i", "com.thom1606.ShareBox.Finder"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        task.launch()
        task.waitUntilExit()

        UserDefaults.standard.set(true, forKey: "onboardingCompleted")
    }

    var body: some View {
        VStack(alignment: .leading) {
            ZStack {
                Spacer()
                    .frame(maxWidth: .infinity)
                if #available(macOS 15.0, *) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 160, weight: .semibold))
                        .padding(.bottom, 64)
                        .symbolEffect(.wiggle.byLayer, options: .repeating)
                } else {
                    Image(systemName: "play.fill")
                        .font(.system(size: 160, weight: .semibold))
                        .padding(.bottom, 64)
                }
            }
            Text("Ready to Begin?")
                .foregroundStyle(Color(NSColor.labelColor))
                .font(.title.weight(.bold))
                .padding(.bottom, 2)
            Text("You're all set to start your journey with ShareBox! Begin by selecting files in Finder and choosing the **\"Upload to ShareBox\"** option.")
                .foregroundStyle(Color(NSColor.secondaryLabelColor))
                .font(.title3)
                .padding(.bottom, 12)
            Button(action: handleComplete) {
                Text("Let's go!")
            }
            .buttonStyle(MainButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }
}

#Preview {
    OnboardingStepFinal()
        .frame(width: 425, height: 600)
}
