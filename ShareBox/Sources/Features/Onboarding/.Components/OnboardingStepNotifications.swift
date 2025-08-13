
//
//  OnboardingStepNotifications.swift
//  ShareBox
//
//  Created by Thom van den Broek on 12/08/2025.
//

import SwiftUI
import ThomKit

struct OnboardingStepNotifications: View {
    @Binding var pageSelection: Int
    @State private var errored = false

    // Request notifiation permissions from the user
    func requestNotifications() {
        if errored {
            pageSelection += 1
            return
        }
        
        do {
            _ = try Messenger.shared.send(.init(type: .requestNotifications))
            pageSelection += 1
        } catch {
            generalLogger.error("Failed to request notification permissions via ShareBox Helper: \(error.localizedDescription)")
            withAnimation {
                errored = true
            }
        }
    }
    
    var title: LocalizedStringKey {
        if errored { return LocalizedStringKey("Oops!") }
        return LocalizedStringKey("Stay Informed")
    }

    var description: LocalizedStringKey {
        if errored { return LocalizedStringKey("We encountered a problem whilst requestion notification permissions. Would you like to continue without?") }
        return LocalizedStringKey("To ensure you are always up to date with your upload progress, we would like to send you notifications when it's essential for you. No promotions or spam.")
    }

    var buttonText: LocalizedStringKey {
        if errored { return LocalizedStringKey("Continue") }
        return LocalizedStringKey("Request access")
    }

    var body: some View {
        VStack(alignment: .leading) {
            ZStack {
                Spacer()
                    .frame(maxWidth: .infinity)
                if #available(macOS 15.0, *) {
                    Image(systemName: errored ? "bell.slash.fill" : "bell.fill")
                        .font(.system(size: 160, weight: .semibold))
                        .padding(.bottom, 64)
                        .symbolEffect(.wiggle.byLayer, options: .repeating)
                        .contentTransition(.symbolEffect(.replace))
                } else {
                    Image(systemName: errored ? "bell.slash.fill" : "bell.fill")
                        .font(.system(size: 160, weight: .semibold))
                        .padding(.bottom, 64)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            Text(title)
                .foregroundStyle(.primary)
                .font(.title.weight(.bold))
                .animation(.snappy, value: title)
                .contentTransition(.numericText(countsDown: true))
                .padding(.bottom, 2)
            Text(description)
                .foregroundStyle(.secondary)
                .font(.title3)
                .padding(.bottom, 12)
            Button(action: requestNotifications) {
                Text(buttonText)
                    .animation(.snappy, value: buttonText)
                    .contentTransition(.numericText(countsDown: true))
            }
            .buttonStyle(MainButtonStyle())
            .environment(\.hasErrored, errored)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }
}

#Preview {
    OnboardingStepNotifications(pageSelection: .constant(0))
        .frame(width: 425, height: 600)
}
