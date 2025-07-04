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
    @EnvironmentObject var appState: AppState
    @State var currentIndex: Int
    @State private var dragOffset: CGFloat = 0
    @Binding var navigationPath: NavigationPath
    @Binding var selectedTab: Tab
    
    private var playerStore: GenericPlayerManagerStore<T> {
        if T.self == ShareableItem.self {
            return appState.videoPlaybackState.shareablePlayerStore as! GenericPlayerManagerStore<T>
        } else if T.self == RecordedVideo.self {
            return appState.videoPlaybackState.recordedPlayerStore as! GenericPlayerManagerStore<T>
        } else if T.self == LikedItem.self {
            return appState.videoPlaybackState.likedPlayerStore as! GenericPlayerManagerStore<T>
        }
        fatalError("Unsupported video type")
    }
    
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
            if T.self == ShareableItem.self {
                appState.videoPlaybackState.updateCurrentVideoIndex(newIndex, type: .shareable)
            } else if T.self == LikedItem.self {
                appState.videoPlaybackState.updateCurrentVideoIndex(newIndex, type: .liked)
            } else if T.self == RecordedVideo.self {
                appState.videoPlaybackState.updateCurrentVideoIndex(newIndex, type: .recorded)
            }
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
        
        if T.self == ShareableItem.self {
            appState.videoPlaybackState.updateCurrentVideoIndex(currentIndex, type: .shareable)
        } else if T.self == LikedItem.self {
            appState.videoPlaybackState.updateCurrentVideoIndex(currentIndex, type: .liked)
        } else if T.self == RecordedVideo.self {
            appState.videoPlaybackState.updateCurrentVideoIndex(currentIndex, type: .recorded)
        }
        
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
