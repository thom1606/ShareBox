//
//  ProgressCircles.swift
//  ShareBox
//
//  Created by Thom van den Broek on 15/08/2025.
//

import SwiftUI

struct ThreeQuarterFilledCircle: Shape {
    var progress: CGFloat // Progress between 0 and 100

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        
        // Start angle at top (-90 degrees), end angle at 270 degrees (3/4 of circle)
        path.addArc(center: center,
                    radius: radius,
                    startAngle: .degrees(-90),
                    endAngle: .degrees(
                        Utilities.map(minRange: 0, maxRange: 100, minDomain: -90, maxDomain: 270, value: progress)),
                    clockwise: false)
        
        // Close the path to make it a filled wedge
        path.addLine(to: center)
        path.closeSubpath()
        
        return path
    }
}

struct ProgressCircle: View {
    var progress: CGFloat // Progress between 0 and 100

    var body: some View {
        ZStack {
            Circle()
                .fill(.white.opacity(0.3))
            ThreeQuarterFilledCircle(progress: progress)
                .fill(.white)
        }
    }
}

#Preview {
    ProgressCircle(progress: 75)
        .background(.black)
        .padding()
}
