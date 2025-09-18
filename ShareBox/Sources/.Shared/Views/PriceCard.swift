//
//  PriceCard.swift
//  ShareBox
//
//  Created by Thom van den Broek on 07/09/2025.
//

import SwiftUI

struct PriceCard: View {
    @Binding var selectedPlan: Plan
    var plan: Plan

    @State private var isHovering: Bool = false

    var title: LocalizedStringKey {
        if plan == .plus { return "Plus" }
        return "Pro"
    }

    var price: LocalizedStringKey {
        if plan == .plus { return "€0.99/mo" }
        return "€3.99/mo"
    }

    var description: LocalizedStringKey {
        if plan == .plus { return "Get started with ShareBox. Useful if you just want to share some files without going all in." }
        return "Perfect for power users who share a lot of (large) files with clients."
    }

    var options: [PriceOption] {
        if plan == .plus {
            return [
                .init(text: String(localized: "50GB of ShareBox Packages")),
                .init(text: String(localized: "Unlimited Cloud Drives")),
                .init(text: String(localized: "Store files up to 7 days")),
                .init(
                    text: String(localized: "Pay-as-you-go option exceeding limit"),
                    included: false
                )
            ]
        }
        return [
            .init(text: String(localized: "250GB of ShareBox Packages")),
            .init(text: String(localized: "Unlimited Cloud Drives")),
            .init(text: String(localized: "Store files up to 2 weeks")),
            .init(
                text: String(localized: "Pay-as-you-go option exceeding limit"),
                description: .init(
                    title: String(localized: "Pay-as-you-go"),
                    text: String(localized: "For users sharing more than 250GB of ShareBox Packages per each month. Enable the pay-as-you-go option and pay €0.03/GB.")
                )
            )
        ]
    }

    var isSelected: Bool {
        selectedPlan == plan
    }

    var body: some View {
        Button(action: {
            selectedPlan = plan
        }, label: {
            VStack(spacing: 0) {
                HStack(alignment: .center) {
                    Text(title)
                        .font(.title.bold())
                        .foregroundStyle(isSelected ? .accent : .primary)
                    Spacer()
                    Text(price)
                        .font(.title3.weight(.medium))
                }
                .padding(.bottom, 6)
                Text(description)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 12)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minWidth: 0, maxWidth: .infinity)
                VStack(spacing: 6) {
                    ForEach(options, id: \.text) { option in
                        PriceCardRow(option: option)
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color("Colors/ButtonBackground").opacity(0.1) : Color.black.opacity(0.001))
                    .stroke(isHovering || isSelected ? .accent : Color.primary.opacity(0.2), lineWidth: 2)
            )
        })
        .buttonStyle(.plain)
        .onHover { isOver in
            withAnimation(.spring) {
                self.isHovering = isOver
            }
        }
    }
}

enum Plan: String {
    case plus
    case pro
}

struct PriceOption {
    var text: String
    var included: Bool = true
    var description: PriceOptionDescription?

    struct PriceOptionDescription {
        var title: String
        var text: String
    }
}

#Preview {
    PriceCard(
        selectedPlan: .constant(.pro),
        plan: .pro
    )
}
