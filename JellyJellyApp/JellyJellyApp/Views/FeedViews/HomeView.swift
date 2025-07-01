//
//  HomeView.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/3/25.
//

import SwiftUI
import AVFoundation
import UIKit
import Lottie

struct HomeView: View {
    @EnvironmentObject private var appState: AppState
    @State private var navigationPath = NavigationPath()
    @State private var selectedTab: Tab = .home
    
    var body: some View {
        VStack {
            Group {
                if appState.shareableItemsState.shareableItems.isEmpty {
                    LoadingView(text: "jellies incoming...")
                } else {
                    GenericScrollerView(
                        videoItems: appState.shareableItemsState.shareableItems,
                        currentIndex: 0,
                        navigationPath: $navigationPath,
                        selectedTab: $selectedTab
                    )
                }
            }
            .onAppear {
                setupAudioSession()
            }
            .cornerRadius(16)
        }
        .safeAreaInset(edge: .top) { Spacer().frame(height: 0) }
        .safeAreaInset(edge: .leading) { Spacer().frame(width: 0) }
        .safeAreaInset(edge: .trailing) { Spacer().frame(width: 0) }
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
