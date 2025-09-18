//
//  NotchCorners.swift
//  ShareBox
//
//  Created by Thom van den Broek on 05/09/2025.
//

import SwiftUI

struct NotchCorner: Shape {
    var inverted = false

    func path(in rect: CGRect) -> Path {
        var path = Path()

        if inverted {
            path.move(to: .init(x: rect.maxX, y: 0))
            path.addCurve(to: .init(x: 0, y: rect.maxY), control1: .init(x: 0, y: 0), control2: .init(x: 0, y: 0))
            path.addLine(to: .init(x: 0, y: 0))
        } else {
            path.move(to: .init(x: 0, y: 0))
            path.addCurve(to: .init(x: rect.maxX, y: rect.maxY), control1: .init(x: 0, y: rect.maxY), control2: .init(x: 0, y: rect.maxY))
            path.addLine(to: .init(x: 0, y: rect.maxY))
        }

        path.closeSubpath()
        return path
    }
}
