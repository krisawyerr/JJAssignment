//
//  LikedItemsPlayerView.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/6/25.
//

import SwiftUI
import AVFoundation
import UIKit
import Lottie

struct LikedItemsPlayerView: View {
    let videos: [LikedItem]
    @State private var currentIndex: Int
    @Binding var selectedTab: Tab
    @Binding var navigationPath: NavigationPath
    
    init(videos: [LikedItem], currentIndex: Int, selectedTab: Binding<Tab>, navigationPath: Binding<NavigationPath>) {
        self.videos = videos
        self._currentIndex = State(initialValue: currentIndex)
        self._selectedTab = selectedTab
        self._navigationPath = navigationPath
    }
    
    var body: some View {
        ZStack {
            GenericScrollerView(
                videoItems: videos,
                currentIndex: currentIndex,
                navigationPath: $navigationPath,
                selectedTab: $selectedTab
            )
            .onAppear {
                setupAudioSession()
            }
            .cornerRadius(16)
            
            VStack {
                HStack {
                    Button(action: {
                        navigationPath.removeLast()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .medium))
                            Text("Back")
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.white)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                Spacer()
            }
        }
        .safeAreaInset(edge: .top) { Spacer().frame(height: 0) }
        .safeAreaInset(edge: .leading) { Spacer().frame(width: 8) }
        .safeAreaInset(edge: .trailing) { Spacer().frame(width: 8) }
    }
    
    private func setupAudioSession() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay, .allowBluetooth])
        try? AVAudioSession.sharedInstance().setActive(true)
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
