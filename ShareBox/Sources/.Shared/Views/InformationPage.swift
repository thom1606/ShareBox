//
//  InformationPage.swift
//  ShareBox
//
//  Created by Thom van den Broek on 07/09/2025.
//

import SwiftUI

struct InformationPage<C: View>: View {
    var cancelText: LocalizedStringKey = "Cancel"
    var onCancel: (() -> Void)?
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
                if onCancel != nil {
                    Button(action: onCancel!, label: {
                        Text(cancelText)
                    })
                    .buttonStyle(CancelButtonStyle())
                    .disabled(isLoading)
                }
                Button(action: onContinue, label: {
                    Text(continueText)
                })
                .buttonStyle(ContinueButtonStyle())
                .environment(\.isLoading, isLoading)
                .disabled(disabled)
                .shake(enabled: hasErrored)
            }
        }
        .padding(16)
    }
}

private struct CancelButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled: Bool
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.vertical, 12)
            .padding(.horizontal, 12)
            .foregroundColor(isHovered ? .primary.opacity(0.6) : .primary)
            .font(.body.weight(.medium))
            .opacity(isEnabled ? 1 : 0.4)
            .onHover { hovering in
                isHovered = hovering
            }
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
                .animation(.easeInOut, value: isLoading)
                .padding(.vertical, 12)
                .padding(.horizontal, 24)
                .background(
                    Color("Colors/ButtonBackground")
                )
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .foregroundColor(Color("Colors/ButtonLabel"))
                .overlay {
                    if isHovered {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(.clear)
                            .stroke(Color("Colors/ButtonLabel"), style: .init(lineWidth: 2))
                    }
                }
                .font(.body.weight(.semibold))
                .opacity(isLoading ? 0 : isEnabled ? 1 : 0.4)

            ProgressView()
                .controlSize(.small)
                .opacity(isLoading ? 1 : 0)
                .animation(.easeInOut, value: isLoading)
        }
        .animation(.spring, value: isEnabled)
        .onHover { hovering in
            withAnimation {
                isHovered = hovering
            }
        }
    }
}
