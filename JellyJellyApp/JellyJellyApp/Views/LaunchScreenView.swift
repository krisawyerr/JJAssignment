//
//  LaunchScreenView.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/7/25.
//

import SwiftUI

struct LaunchScreenView: View {
    var body: some View {
        ZStack {
            Color("JellyPrimary")
            
            VStack {
                Text("jellyjelly")
                    .font(.custom("Ranchers-Regular", size: 50))
                    .foregroundColor(.white)
                    .kerning(1.5)
            }
        }
        .ignoresSafeArea()
    }
}

#Preview {
    LaunchScreenView()
}
