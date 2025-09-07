//
//  SubscribeConfirmView.swift
//  ShareBox
//
//  Created by Thom van den Broek on 07/09/2025.
//

import SwiftUI
import ServiceManagement
import UserNotifications

struct SubscribeConfirmView: View {
    private let api = ApiService()
    @Binding var pageSelection: Int
    @Binding var selectedPlan: Plan

    @Environment(User.self) private var user
    @State private var isLoading: Bool = false
    @State private var overLimit: Bool = true
    @State private var couponCode: String = ""

    private var bodyText: LocalizedStringKey {
        if selectedPlan == .plus {
            return "For just **€0.99**/month, enjoy a **50GB** upload limit, ensuring your files are always ready to share.\n\nSecure your personal cloud space and effortlessly upload up to **50GB** of files each month."
        }

        return "For just **€3.99**/month, enjoy a **250GB** upload limit, ensuring your files are always ready to share.\n\nSecure your personal cloud space and effortlessly upload up to **250GB** of files each month."
    }

    var body: some View {
        InformationPage(cancelText: "Cancel", onCancel: handleCancel, continueText: "Subscribe", isLoading: isLoading, onContinue: handleContinue) {
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
                        TextFieldView(label: "Coupon code", placeholder: "HELLO20", text: $couponCode)
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
                self.pageSelection += 1
            }
        }
    }

    private func handleContinue() {
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
                // TODO: if the error contains something like "INVALID_COUPON" we should shake the coupon field and notify the user
                DispatchQueue.main.async {
                    self.isLoading = false
                }
            }
        }
    }

    private func handleCancel() {
        self.pageSelection -= 2
    }
}
