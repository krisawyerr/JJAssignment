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
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color("Primary")
                
                if let player = playerManager.player {
                    AVPlayerView(player: player)
                        .clipped()
                        .onTapGesture {
                            playerManager.togglePlayback()
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
                }
                
                if !playerManager.isPlaying && !playerManager.isLoading && playerManager.playerStatus == .readyToPlay {
                    Button(action: {
                        playerManager.togglePlayback()
                    }) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                if playerManager.isLoading {
                    LoadingView(text: "jellies incoming...")
                } else if playerManager.playerStatus == .failed {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                        Text("Failed to load video")
                            .foregroundColor(.white)
                            .font(.caption)
                    }
                }
                
                if !playerManager.isPlaying && !playerManager.isLoading && playerManager.playerStatus == .readyToPlay {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: {
                                playerManager.toggleMute()
                            }) {
                                MuteLottieView(
                                    animationName: "mute",
                                    isPlaying: $playerManager.shouldAnimateMute,
                                    shouldReverse: !playerManager.isMuted
                                )
                                .frame(width: 40, height: 40)
                            }
                            .buttonStyle(PlainButtonStyle())
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
        }
    }
}
