//
//  PricingConfirmView.swift
//  ShareBox
//
//  Created by Thom van den Broek on 08/09/2025.
//

import SwiftUI

struct PricingConfirmView: View {
    private let api = ApiService()

    var selectedPlan: Plan
    var cancelText: LocalizedStringKey = "Cancel"
    var onCancel: () -> Void
    var onContinue: () -> Void

    @Environment(User.self) private var user
    @State private var isLoading: Bool = false
    @State private var overLimit: Bool = true
    @State private var couponCode: String = ""
    @State private var couponErrored: Bool = false

    private var bodyText: LocalizedStringKey {
        if selectedPlan == .plus {
            return "For just **€0.99**/month, enjoy a **50GB** upload limit, ensuring your files are always ready to share.\n\nSecure your personal cloud space and effortlessly upload up to **50GB** of files each month."
        }

        return "For just **€3.99**/month, enjoy a **250GB** upload limit, ensuring your files are always ready to share.\n\nSecure your personal cloud space and effortlessly upload up to **250GB** of files each month."
    }

    var body: some View {
        InformationPage(cancelText: cancelText, onCancel: onCancel, continueText: "Subscribe", isLoading: isLoading, onContinue: handleContinue) {
            HStack {
                VStack(alignment: .leading, spacing: 30) {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Almost ready!")
                            .fontDesign(.serif)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text(bodyText)
                            .foregroundStyle(.secondary)
                            .font(.title3)
                    }
                    VStack(alignment: .leading, spacing: 15) {
                        if selectedPlan == .pro {
                            HStack {
                                Toggle("", isOn: $overLimit)
                                    .toggleStyle(.switch)
                                    .controlSize(.mini)
                                VStack(alignment: .leading) {
                                    Text("Pay-as-you-go storage")
                                    Text("Allow to spend €0.03/GB for uploads past the 250GB monthly limit.")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .offset(x: -10)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            TextFieldView(label: "Coupon code", placeholder: "HELLO20", errored: couponErrored, text: $couponCode)
                            if couponErrored {
                                Text("Invalid coupon code provided. Please try again.")
                                    .foregroundStyle(.red)
                                    .font(.subheadline)
                            }
                        }
                    }
                    .font(.title3)
                }
                .frame(width: 350)
                VStack {
                    Image(systemName: "star.hexagon.fill")
                        .foregroundStyle(.primary.opacity(0.3))
                        .font(.system(size: 250))
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.leading, 32)
            .padding(.top, 48)
            .onChange(of: user.subscriptionData) {
                onContinue()
            }
        }
    }

    private func handleContinue() {
        self.couponErrored = false
        self.isLoading = true
        Task {
            do {
                let res: SubscribeResponse = try await api.get(
                    endpoint: "/api/subscribe",
                    parameters: [
                        "plan": selectedPlan.rawValue,
                        "coupon": couponCode,
                        "overLimit": selectedPlan == .pro ? overLimit : false
                    ]
                )
                NSWorkspace.shared.open(URL(string: res.url)!)
            } catch {
                if let apiError = error as? APIError, case .unauthorized = apiError {
                    await self.user.refresh()
                    if !self.user.authenticated {
                        onCancel()
                    }
                } else if let error = error as? APIError, case .serverError(_, let errorResponse) = error {
                    switch errorResponse.error {
                    case "PLAN_NOT_FOUND",
                        "INVALID_PLAN",
                        "OVER_LIMIT_NOT_ALLOWED",
                        "STRIPE_CUSTOMER_NOT_FOUND":
                        self.showSupportDialog()
                    case "COUPON_NOT_FOUND":
                        withAnimation {
                            self.couponErrored = true
                        }
                    default:
                        break
                    }
                }
            }
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
    }

    private func showSupportDialog() {
        let alert = NSAlert()
        alert.messageText = String(localized: "Something went wrong")
        alert.informativeText = String(localized: "You reached a state which is not supported by the current version of the app. Please contact support@shareboxed.app for further assistance.")
        alert.alertStyle = .warning
        alert.window.center()
        alert.window.level = .floating
        alert.window.makeKeyAndOrderFront(nil)
        alert.runModal()
        NSWorkspace.shared.open(URL(string: "mailto:support@shareboxed.app")!)
    }
}
