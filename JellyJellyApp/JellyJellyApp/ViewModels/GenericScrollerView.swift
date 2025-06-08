//
//  GenericScrollerView.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/6/25.
//

import SwiftUI
import AVFoundation
import UIKit
import Lottie

struct GenericScrollerView<T: VideoPlayable>: View {
    let videoItems: [T]
    @StateObject private var playerStore = GenericPlayerManagerStore<T>()
    @State var currentIndex: Int
    @State private var dragOffset: CGFloat = 0
    @EnvironmentObject var appState: AppState
    @Binding var navigationPath: NavigationPath
    @Binding var selectedTab: Tab
    
    var body: some View {
        GeometryReader { geometry in
            let screenHeight = geometry.size.height
            let screenWidth = geometry.size.width
            
            ZStack {
                ForEach(Array(videoItems.enumerated()), id: \.element.id) { index, item in
                    GenericVideoPlayerCell(
                        videoItem: item,
                        isCurrentVideo: index == currentIndex,
                        playerManager: playerStore.getManager(for: item),
                        navigationPath: $navigationPath,
                        selectedTab: $selectedTab
                    )
                    .frame(width: screenWidth, height: screenHeight)
                    .offset(y: CGFloat(index - currentIndex) * screenHeight + dragOffset)
                }
            }
            .animation(.interactiveSpring(response: 0.6, dampingFraction: 0.8), value: currentIndex)
            .animation(.interactiveSpring(response: 0.3, dampingFraction: 0.9), value: dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation.height
                    }
                    .onEnded { value in
                        handleDragEnd(value: value, screenHeight: screenHeight)
                    }
            )
        }
        .onAppear {
            setupInitialVideo()
        }
        .onDisappear {
            pauseAllVideos()
        }
        .onChange(of: currentIndex) { _, newIndex in
            preloadAdjacentVideos(around: newIndex)
        }
    }
    
    private func handleDragEnd(value: DragGesture.Value, screenHeight: CGFloat) {
        let threshold = screenHeight * 0.25
        let velocity = value.predictedEndTranslation.height - value.translation.height
        
        withAnimation(.easeOut(duration: 0.3)) {
            if value.translation.height > threshold || velocity > 300 {
                if currentIndex > 0 {
                    currentIndex -= 1
                }
            } else if value.translation.height < -threshold || velocity < -300 {
                if currentIndex < videoItems.count - 1 {
                    currentIndex += 1
                }
            }
            
            dragOffset = 0
        }
    }
    
    private func pauseAllVideos() {
        for item in videoItems {
            let manager = playerStore.getManager(for: item)
            manager.pause()
        }
    }
    
    private func setupInitialVideo() {
        guard !videoItems.isEmpty else { return }
        
        let firstItem = videoItems[currentIndex]
        let manager = playerStore.getManager(for: firstItem)
        manager.play()
        
        if videoItems.count > 1 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                let nextIndex = (currentIndex + 1) % videoItems.count
                playerStore.preloadManager(for: videoItems[nextIndex])
            }
        }
    }
    
    private func preloadAdjacentVideos(around index: Int) {
        if index + 1 < videoItems.count {
            playerStore.preloadManager(for: videoItems[index + 1])
        }
        
        if index - 1 >= 0 {
            playerStore.preloadManager(for: videoItems[index - 1])
        }
    }
}
