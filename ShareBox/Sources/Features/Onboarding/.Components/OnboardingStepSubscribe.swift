//

//  OnboardingStepSubscribe.swift
//  ShareBox
//
//  Created by Thom van den Broek on 12/08/2025.
//

import SwiftUI
import ThomKit

struct OnboardingStepSubscribe: View {
    @Binding var pageSelection: Int

    @State private var subscribing = false
    @State private var errored = false
    @State private var processing = false
    private let apiService = ApiService()

    func handleSubscribe() async {
        if subscribing { return }
        withAnimation { subscribing = true }
        do {
            let res: SubscribeResponse = try await apiService.get(endpoint: "/api/subscribe")
            NSWorkspace.shared.open(URL(string: res.url)!)
            
            // start looping to catch the completion of a subscription
            Task {
                await fetchStatus(id: res.sessionId)
            }
        } catch {
            generalLogger.error("Failed to subscribe: \(error.localizedDescription)")
            withAnimation { subscribing = false }
        }
    }
    
    private func fetchStatus(id: String) async {
        try? await Task.sleep(for: .seconds(30))
        do {
            let res: SubscriptionStatusResponse = try await apiService.get(endpoint: "/api/subscribe/status/\(id)")
            if res.status == "complete" {
                pageSelection += 1
            } else if res.status == "open" {
                DispatchQueue.main.async {
                    withAnimation {
                        processing = true
                    }
                }
                await fetchStatus(id: id)
            } else {
                DispatchQueue.main.async {
                    withAnimation {
                        subscribing = false
                        errored = true
                    }
                }
            }
        } catch {
            await fetchStatus(id: id)
        }
    }
    
    var title: LocalizedStringKey {
        if errored { return LocalizedStringKey("Oops!") }
        if processing { return LocalizedStringKey("Payment processing!") }
        return LocalizedStringKey("Start with Sharing!")
    }

    var description: LocalizedStringKey {
        if errored { return LocalizedStringKey("Your payment was not received correctly. Would you please try again?") }
        if processing { return LocalizedStringKey("Your payment is currently processing. Please wait a few minutes. If you do not see a confirmation in a few minutes, please [contact me](mailto:sharebox@thomvandenbroek.com).") }
        return LocalizedStringKey("For the price of **€2,99** we would like to provide you with **250GB** of free cloud storage. With upgrade options coming in the future.")
    }

    var buttonText: LocalizedStringKey {
        if errored { return LocalizedStringKey("Try again") }
        return LocalizedStringKey("Sign me up!")
    }

    var body: some View {
        VStack(alignment: .leading) {
            ZStack {
                Spacer()
                    .frame(maxWidth: .infinity)
                if #available(macOS 15.0, *) {
                    Image(systemName: "star.hexagon.fill")
                        .font(.system(size: 160, weight: .semibold))
                        .padding(.bottom, 64)
                } else {
                    Image(systemName: "star.hexagon.fill")
                        .font(.system(size: 160, weight: .semibold))
                        .padding(.bottom, 64)
                }
            }
            Text(title)
                .foregroundStyle(Color(NSColor.labelColor))
                .font(.title.weight(.bold))
                .animation(.snappy, value: title)
                .contentTransition(.numericText(countsDown: true))
                .padding(.bottom, 2)
            Text(description)
                .foregroundStyle(Color(NSColor.secondaryLabelColor))
                .font(.title3)
                .padding(.bottom, 12)
            Button(action: {
                Task {
                    await handleSubscribe()
                }
            }) {
                ZStack {
                    Text(buttonText)
                        .animation(.snappy, value: buttonText)
                        .contentTransition(.numericText(countsDown: true))
                        .opacity(subscribing ? 0 : 1)
                    ProgressView()
                        .controlSize(.small)
                        .opacity(subscribing ? 1 : 0)
                }
            }
            .buttonStyle(MainButtonStyle())
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .onAppear {
            if userDefaults.string(forKey: Constants.User.subscriptionStatusKey) == "active" {
                pageSelection += 1
            }
        }
    }
}

private struct SubscribeResponse: Codable {
    var url: String
    var sessionId: String
}

private struct SubscriptionStatusResponse: Codable {
    var status: String
}

#Preview {
    OnboardingStepSubscribe(pageSelection: .constant(0))
        .frame(width: 425, height: 600)
}
