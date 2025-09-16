//
//  NotchShape.swift
//  ShareBox
//
//  Created by Thom van den Broek on 15/09/2025.
//

import SwiftUI

struct NotchShape: Shape {
    var cornerRadii: CGFloat

    var animatableData: CGFloat {
        get { cornerRadii }
        set { cornerRadii = newValue }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let curveSize = cornerRadii
        let maxX: CGFloat = rect.maxX

        path.move(to: .init(x: 0, y: -curveSize))
        path.addQuadCurve(to: .init(x: curveSize, y: 0), control: .init(x: 0, y: 0))
        path.addLine(to: .init(x: maxX - curveSize, y: 0))
        path.addQuadCurve(to: .init(x: maxX, y: curveSize), control: .init(x: maxX, y: 0))

        path.addLine(to: .init(x: maxX, y: rect.maxY - curveSize))
        path.addQuadCurve(to: .init(x: maxX - curveSize, y: rect.maxY), control: .init(x: maxX, y: rect.maxY))
        path.addLine(to: .init(x: curveSize, y: rect.maxY))
        path.addQuadCurve(to: .init(x: 0, y: rect.maxY + curveSize), control: .init(x: 0, y: rect.maxY))

        path.closeSubpath()
        return path
    }
}
