//
//  OnboardingPage.swift
//  ShareBox
//
//  Created by Thom van den Broek on 17/08/2025.
//

import SwiftUI

struct OnboardingPage<C: View>: View {
    var continueText: LocalizedStringKey = "Continue"
    var isLoading: Bool = false
    var hasErrored: Bool = false
    var disabled: Bool = false
    var onContinue: () -> Void
    @ViewBuilder var content: () -> C

    var body: some View {
        VStack {
            ZStack {
                Color.clear
                content()
            }
            HStack {
                Spacer()
                Button(action: onContinue, label: {
                    ZStack {
                        Text(continueText)
                            .opacity(isLoading ? 0 : 1)
                        ProgressView()
                            .controlSize(.small)
                            .opacity(isLoading ? 1 : 0)
                    }
                })
                .buttonStyle(ContinueButtonStyle())
                .disabled(disabled)
                .shake(enabled: hasErrored)
            }
        }
        .padding(16)
    }
}

private struct ContinueButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isLoading) private var isLoading: Bool
    @Environment(\.isEnabled) private var isEnabled: Bool
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            configuration.label
                .opacity(isLoading ? 0 : 1)
                .animation(.easeInOut, value: isLoading)
            ProgressView()
                .controlSize(.small)
                .opacity(isLoading ? 1 : 0)
                .animation(.easeInOut, value: isLoading)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 24)
        .background(
            Group {
                if colorScheme == .light {
                    Color.white
                } else {
                    Color.black
                }
            }.opacity(0.75)
        )
        .foregroundColor(Color(NSColor.labelColor))
        .overlay {
            if isHovered {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.clear)
                    .stroke(Color(NSColor.secondaryLabelColor), style: .init(lineWidth: 3))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .font(.body.weight(.semibold))
        .opacity(isEnabled ? 1 : 0.4)
        .onHover { hovering in
            withAnimation {
                isHovered = hovering
            }
        }
    }
}

#Preview {
    OnboardingPage(onContinue: {}, content: {
        ZStack {}
    })
}
