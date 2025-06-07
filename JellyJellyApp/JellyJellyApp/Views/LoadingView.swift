//
//  LoadingView.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/3/25.
//

import SwiftUI
import CoreData

struct LoadingView: View {
    @State private var animate = false
    let loadingText: String
    
    init(text: String = "loading...") {
        self.loadingText = text
    }

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: animate ? [Color("GradientLight")] : [Color("GradientDark")]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: animate)
            .onAppear {
                animate = true
            }
            VStack {
                JellyfishShape()
                    .stroke(Color.white, lineWidth: 3)
                    .fill(Color.white)
                    .frame(width: 150, height: 120)
                Text(loadingText)
                    .font(.custom("Ranchers-Regular", size: 25))
                    .foregroundColor(.white)
                    .kerning(1.5)
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
