//
//  NotchShape.swift
//  ShareBox
//
//  Created by Thom van den Broek on 11/08/2025.
//

import SwiftUI

struct NotchShape: Shape {
    var pulloutPercentage: CGFloat = 0

    var animatableData: CGFloat {
        get { pulloutPercentage }
        set { pulloutPercentage = newValue }
    }

    private var xWidth: CGFloat {
        Utilities.map(minRange: 0, maxRange: 1, minDomain: 23, maxDomain: Constants.Uploader.windowWidth, value: animatableData)
    }

    private var smallOffset: CGFloat {
        Utilities.map(minRange: 0, maxRange: 1, minDomain: 40, maxDomain: 0, value: animatableData)
    }

    func path(in rect: CGRect) -> Path {
        let pointOffset: CGFloat = 100
        let controlOffset: CGFloat = 25

        var path = Path()

        path.move(to: CGPoint(x: rect.minX, y: rect.minY + smallOffset))
        path.addCurve(
            to: CGPoint(x: xWidth, y: rect.minY + pointOffset),
            control1: CGPoint(x: rect.minX, y: rect.minY + pointOffset - controlOffset),
            control2: CGPoint(x: xWidth, y: rect.minY + controlOffset + smallOffset)
        )
        path.addLine(to: CGPoint(x: xWidth, y: rect.maxY - pointOffset))
        path.addCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - smallOffset),
            control1: CGPoint(x: xWidth, y: rect.maxY - controlOffset - smallOffset),
            control2: CGPoint(x: rect.minX, y: rect.maxY - pointOffset + controlOffset)
        )
        path.closeSubpath()
        return path
    }
}
