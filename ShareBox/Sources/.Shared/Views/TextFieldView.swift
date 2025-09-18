//
//  TextFieldView.swift
//  ShareBox
//
//  Created by Thom van den Broek on 17/08/2025.
//

import SwiftUI

struct TextFieldView: View {
    var label: LocalizedStringKey
    var placeholder: String
    var errored: Bool = false
    @Binding var text: String

    @FocusState private var isFocused

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .focused($isFocused)
                .frame(height: 36)
                .padding(.horizontal, 8)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(.primary.opacity(0.2))
                )
                .overlay {
                    if isFocused {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(.clear)
                            .stroke(Color(NSColor.secondaryLabelColor), style: .init(lineWidth: 3))
                    }
                }
                .shake(enabled: errored)
        }
    }
}

#Preview {
    TextFieldView(label: "Label", placeholder: "", text: .constant(""))
}
