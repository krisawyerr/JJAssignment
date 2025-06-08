//
//  GenericVideoPlayerCell.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/6/25.
//

import SwiftUI
import AVFoundation
import UIKit
import Lottie

struct GenericVideoPlayerCell<T: VideoPlayable>: View {
    let videoItem: T
    let isCurrentVideo: Bool
    @ObservedObject var playerManager: GenericVideoPlayerManager<T>
    @State private var showLikeAnimation = false
    @EnvironmentObject var appState: AppState
    @State private var isLiked = false
    @Binding var navigationPath: NavigationPath
    @Binding var selectedTab: Tab
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color("JellyPrimary")
                
                if let player = playerManager.player {
                    AVPlayerView(player: player)
                        .clipped()
                        .onTapGesture {
                            playerManager.togglePlayback()
                        }
                        .onTapGesture(count: 2) {
                            handleLike(method: "Double Tap")
                        }
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                }
                
                if !playerManager.isPlaying && !playerManager.isLoading && playerManager.playerStatus == .readyToPlay {
                    Color.black.opacity(0.5)
                        .onTapGesture {
                            playerManager.togglePlayback()
                        }
                        .onTapGesture(count: 2) {
                            handleLike(method: "Double Tap")
                        }
                }
                
                if !playerManager.isPlaying && !playerManager.isLoading && playerManager.playerStatus == .readyToPlay {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            VStack(spacing: 20) {
                                if videoItem is ShareableItem || videoItem is LikedItem {
                                    Button(action: {
                                        handleLike(method: "Button")
                                    }) {
                                        Image(systemName: videoItem is LikedItem || isLiked ? "heart.fill" : "heart")
                                            .resizable()
                                            .scaledToFit()
                                            .frame(width: 28, height: 28)
                                            .foregroundColor(videoItem is LikedItem || isLiked ? .red : .white)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                
                                Button(action: {
                                    playerManager.toggleMute()
                                }) {
                                    MuteLottieView(
                                        animationName: "mute",
                                        isPlaying: $playerManager.shouldAnimateMute,
                                        shouldReverse: !playerManager.isMuted
                                    )
                                    .frame(width: 50, height: 50)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                            .padding(.trailing, 16)
                        }
                    }
                    .padding(.bottom, 60)
                    
                    VStack {
                        Spacer()
                        CustomSliderView(
                            value: Binding(
                                get: { playerManager.currentTime },
                                set: { playerManager.seek(to: $0) }
                            ),
                            in: 0...max(playerManager.duration, 1),
                            onEditingChanged: { editing in

                            }
                        )
                        .frame(height: 30)
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                    }
                }
                
                if showLikeAnimation {
                    TabbarLottieView(
                        animationName: "heart",
                        play: true,
                        strokeColor: .red,
                        fillColor: .red
                    )
                    .frame(width: 150, height: 150)
                }
            }
        }
        .onChange(of: isCurrentVideo) { _, newValue in
            if newValue {
                playerManager.syncMuteState()
                playerManager.play()
            } else {
                playerManager.pause()
            }
        }
        .onAppear {
            if isCurrentVideo {
                playerManager.syncMuteState()
                playerManager.play()
            }
            if let shareableItem = videoItem as? ShareableItem {
                isLiked = appState.isItemLiked(shareableItem.id)
            }
        }
    }
    
    private func handleLike(method: String) {
        guard let shareableItem = videoItem as? ShareableItem else { return }
        
        if isLiked {
            handleUnlike(method: method)
        } else if method == "Button" || (method == "Double Tap" && !isLiked) {
            appState.likeItem(shareableItem)
            isLiked = true
        }
        
        if method == "Double Tap" {
            showLikeAnimation = true
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                showLikeAnimation = false
            }
        }
    }
    
    private func handleUnlike(method: String) {
        guard method == "Button" else { return }
        
        if let likedItem = videoItem as? LikedItem {
            let context = appState.viewContext
            context.delete(likedItem)
            
            do {
                try context.save()
                isLiked = false
                
                navigationPath = NavigationPath()
                selectedTab = .library
            } catch {
                print("Error removing liked item: \(error)")
            }
        } else if let shareableItem = videoItem as? ShareableItem {
            appState.likeItem(shareableItem)
            isLiked = false
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
}
