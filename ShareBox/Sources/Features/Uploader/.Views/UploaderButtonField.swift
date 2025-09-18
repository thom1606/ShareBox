//
//  UploaderButtonField.swift
//  ShareBox
//
//  Created by Thom van den Broek on 06/09/2025.
//

import SwiftUI

struct UploaderButtonField: View {
    var image: Image
    var onTap: () -> Void

    @State private var isHovering: Bool = false

    var body: some View {
        ZStack(alignment: .center) {
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovering ? Color.accentColor.opacity(0.3) : Color("Colors/TileBackground"))
                .stroke(isHovering ? Color.accentColor : .clear)
                .frame(width: 44, height: 66)
            image
                .resizable()
                .scaledToFit()
                .frame(width: 20, height: 20)
                .foregroundStyle(isHovering ? Color.accentColor : .white.opacity(0.5))
        }
        .onHover { isOver in
            withAnimation(.spring) {
                isHovering = isOver
            }
        }
        .onTapGesture(perform: onTap)
        .frame(width: 60, height: 74)
        .frame(maxWidth: 60, maxHeight: 74)
    }
}
