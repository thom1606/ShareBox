//
//  View.swift
//  ShareBox
//
//  Created by Thom van den Broek on 15/09/2025.
//

import SwiftUI

struct SizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

extension View {
    func measureSize(_ onChange: @escaping (CGSize) -> Void) -> some View {
        overlay(
            GeometryReader { geo in
                Color.clear
                    .preference(key: SizeKey.self, value: geo.size)
                    .allowsHitTesting(false)
            }
        )
        .onPreferenceChange(SizeKey.self, perform: onChange)
    }
}
