//
//  JellyfishShape.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/6/25.
//

import SwiftUI

struct JellyfishShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.size.width
        let height = rect.size.height
        
        path.move(to: CGPoint(x: 0.44*width, y: (1.0 - 0.96)*height))
        path.addCurve(to: CGPoint(x: 0.36*width, y: (1.0 - 0.93)*height), control1: CGPoint(x: 0.41*width, y: (1.0 - 0.96)*height), control2: CGPoint(x: 0.39*width, y: (1.0 - 0.95)*height))
        path.addCurve(to: CGPoint(x: 0.23*width, y: (1.0 - 0.75)*height), control1: CGPoint(x: 0.30*width, y: (1.0 - 0.89)*height), control2: CGPoint(x: 0.25*width, y: (1.0 - 0.83)*height))
        path.addCurve(to: CGPoint(x: 0.22*width, y: (1.0 - 0.59)*height), control1: CGPoint(x: 0.22*width, y: (1.0 - 0.72)*height), control2: CGPoint(x: 0.22*width, y: (1.0 - 0.69)*height))
        path.addCurve(to: CGPoint(x: 0.22*width, y: (1.0 - 0.49)*height), control1: CGPoint(x: 0.23*width, y: (1.0 - 0.53)*height), control2: CGPoint(x: 0.22*width, y: (1.0 - 0.51)*height))
        path.addCurve(to: CGPoint(x: 0.12*width, y: (1.0 - 0.38)*height), control1: CGPoint(x: 0.21*width, y: (1.0 - 0.45)*height), control2: CGPoint(x: 0.18*width, y: (1.0 - 0.42)*height))
        path.addCurve(to: CGPoint(x: 0.06*width, y: (1.0 - 0.29)*height), control1: CGPoint(x: 0.07*width, y: (1.0 - 0.36)*height), control2: CGPoint(x: 0.06*width, y: (1.0 - 0.33)*height))
        path.addCurve(to: CGPoint(x: 0.20*width, y: (1.0 - 0.25)*height), control1: CGPoint(x: 0.06*width, y: (1.0 - 0.22)*height), control2: CGPoint(x: 0.12*width, y: (1.0 - 0.21)*height))
        path.addCurve(to: CGPoint(x: 0.25*width, y: (1.0 - 0.28)*height), control1: CGPoint(x: 0.21*width, y: (1.0 - 0.26)*height), control2: CGPoint(x: 0.23*width, y: (1.0 - 0.27)*height))
        path.addCurve(to: CGPoint(x: 0.27*width, y: (1.0 - 0.31)*height), control1: CGPoint(x: 0.26*width, y: (1.0 - 0.30)*height), control2: CGPoint(x: 0.27*width, y: (1.0 - 0.31)*height))
        path.addCurve(to: CGPoint(x: 0.25*width, y: (1.0 - 0.25)*height), control1: CGPoint(x: 0.29*width, y: (1.0 - 0.32)*height), control2: CGPoint(x: 0.28*width, y: (1.0 - 0.30)*height))
        path.addCurve(to: CGPoint(x: 0.22*width, y: (1.0 - 0.15)*height), control1: CGPoint(x: 0.22*width, y: (1.0 - 0.19)*height), control2: CGPoint(x: 0.21*width, y: (1.0 - 0.17)*height))
        path.addCurve(to: CGPoint(x: 0.30*width, y: (1.0 - 0.12)*height), control1: CGPoint(x: 0.24*width, y: (1.0 - 0.11)*height), control2: CGPoint(x: 0.27*width, y: (1.0 - 0.10)*height))
        path.addCurve(to: CGPoint(x: 0.36*width, y: (1.0 - 0.19)*height), control1: CGPoint(x: 0.31*width, y: (1.0 - 0.12)*height), control2: CGPoint(x: 0.33*width, y: (1.0 - 0.14)*height))
        path.addCurve(to: CGPoint(x: 0.42*width, y: (1.0 - 0.26)*height), control1: CGPoint(x: 0.39*width, y: (1.0 - 0.23)*height), control2: CGPoint(x: 0.42*width, y: (1.0 - 0.26)*height))
        path.addCurve(to: CGPoint(x: 0.43*width, y: (1.0 - 0.17)*height), control1: CGPoint(x: 0.43*width, y: (1.0 - 0.26)*height), control2: CGPoint(x: 0.43*width, y: (1.0 - 0.24)*height))
        path.addCurve(to: CGPoint(x: 0.43*width, y: (1.0 - 0.08)*height), control1: CGPoint(x: 0.43*width, y: (1.0 - 0.13)*height), control2: CGPoint(x: 0.43*width, y: (1.0 - 0.09)*height))
        path.addCurve(to: CGPoint(x: 0.47*width, y: (1.0 - 0.04)*height), control1: CGPoint(x: 0.44*width, y: (1.0 - 0.06)*height), control2: CGPoint(x: 0.45*width, y: (1.0 - 0.04)*height))
        path.addCurve(to: CGPoint(x: 0.54*width, y: (1.0 - 0.08)*height), control1: CGPoint(x: 0.50*width, y: (1.0 - 0.03)*height), control2: CGPoint(x: 0.52*width, y: (1.0 - 0.05)*height))
        path.addCurve(to: CGPoint(x: 0.54*width, y: (1.0 - 0.19)*height), control1: CGPoint(x: 0.55*width, y: (1.0 - 0.10)*height), control2: CGPoint(x: 0.55*width, y: (1.0 - 0.11)*height))
        path.addCurve(to: CGPoint(x: 0.55*width, y: (1.0 - 0.24)*height), control1: CGPoint(x: 0.54*width, y: (1.0 - 0.23)*height), control2: CGPoint(x: 0.54*width, y: (1.0 - 0.24)*height))
        path.addCurve(to: CGPoint(x: 0.61*width, y: (1.0 - 0.18)*height), control1: CGPoint(x: 0.56*width, y: (1.0 - 0.25)*height), control2: CGPoint(x: 0.57*width, y: (1.0 - 0.24)*height))
        path.addCurve(to: CGPoint(x: 0.68*width, y: (1.0 - 0.12)*height), control1: CGPoint(x: 0.65*width, y: (1.0 - 0.14)*height), control2: CGPoint(x: 0.66*width, y: (1.0 - 0.13)*height))
        path.addCurve(to: CGPoint(x: 0.76*width, y: (1.0 - 0.13)*height), control1: CGPoint(x: 0.71*width, y: (1.0 - 0.09)*height), control2: CGPoint(x: 0.74*width, y: (1.0 - 0.10)*height))
        path.addCurve(to: CGPoint(x: 0.73*width, y: (1.0 - 0.25)*height), control1: CGPoint(x: 0.78*width, y: (1.0 - 0.15)*height), control2: CGPoint(x: 0.77*width, y: (1.0 - 0.19)*height))
        path.addCurve(to: CGPoint(x: 0.70*width, y: (1.0 - 0.33)*height), control1: CGPoint(x: 0.70*width, y: (1.0 - 0.30)*height), control2: CGPoint(x: 0.69*width, y: (1.0 - 0.33)*height))
        path.addCurve(to: CGPoint(x: 0.75*width, y: (1.0 - 0.28)*height), control1: CGPoint(x: 0.71*width, y: (1.0 - 0.33)*height), control2: CGPoint(x: 0.73*width, y: (1.0 - 0.31)*height))
        path.addCurve(to: CGPoint(x: 0.93*width, y: (1.0 - 0.26)*height), control1: CGPoint(x: 0.80*width, y: (1.0 - 0.21)*height), control2: CGPoint(x: 0.90*width, y: (1.0 - 0.20)*height))
        path.addCurve(to: CGPoint(x: 0.93*width, y: (1.0 - 0.32)*height), control1: CGPoint(x: 0.94*width, y: (1.0 - 0.28)*height), control2: CGPoint(x: 0.94*width, y: (1.0 - 0.30)*height))
        path.addCurve(to: CGPoint(x: 0.86*width, y: (1.0 - 0.39)*height), control1: CGPoint(x: 0.91*width, y: (1.0 - 0.34)*height), control2: CGPoint(x: 0.90*width, y: (1.0 - 0.35)*height))
        path.addCurve(to: CGPoint(x: 0.77*width, y: (1.0 - 0.50)*height), control1: CGPoint(x: 0.81*width, y: (1.0 - 0.42)*height), control2: CGPoint(x: 0.78*width, y: (1.0 - 0.46)*height))
        path.addCurve(to: CGPoint(x: 0.76*width, y: (1.0 - 0.60)*height), control1: CGPoint(x: 0.76*width, y: (1.0 - 0.52)*height), control2: CGPoint(x: 0.76*width, y: (1.0 - 0.53)*height))
        path.addCurve(to: CGPoint(x: 0.73*width, y: (1.0 - 0.80)*height), control1: CGPoint(x: 0.76*width, y: (1.0 - 0.70)*height), control2: CGPoint(x: 0.75*width, y: (1.0 - 0.74)*height))
        path.addCurve(to: CGPoint(x: 0.44*width, y: (1.0 - 0.96)*height), control1: CGPoint(x: 0.68*width, y: (1.0 - 0.91)*height), control2: CGPoint(x: 0.56*width, y: (1.0 - 0.98)*height))
        path.closeSubpath()
        return path
    }
}
