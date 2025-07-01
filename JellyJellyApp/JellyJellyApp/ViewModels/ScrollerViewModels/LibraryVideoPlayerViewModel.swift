//
//  LibraryVideoPlayerViewModel.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/4/25.
//

import Foundation
import Combine
import AVFoundation

class LibraryVideoPlayerViewModel: ObservableObject {
    @Published var player = AVPlayer()
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    
    private var timeObserver: Any?
    
    init() {
        setupTimeObserver()
    }
    
    deinit {
        if let observer = timeObserver {
            player.removeTimeObserver(observer)
        }
    }
    
    func loadVideo(url: URL) {
        let playerItem = AVPlayerItem(url: url)
        player.replaceCurrentItem(with: playerItem)
        
        currentTime = 0
        duration = 0
        isPlaying = false
        
        Task {
            do {
                let duration = try await playerItem.asset.load(.duration)
                await MainActor.run {
                    if duration.isValid && !duration.isIndefinite {
                        self.duration = CMTimeGetSeconds(duration)
                    }
                }
            } catch {
                print("Failed to load duration: \(error)")
            }
        }
        
        player.play()
        isPlaying = true
    }
    
    private func setupTimeObserver() {
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            self?.currentTime = CMTimeGetSeconds(time)
            self?.isPlaying = self?.player.rate != 0
        }
    }
    
    func togglePlayPause() {
        if player.rate == 0 {
            player.play()
            isPlaying = true
        } else {
            player.pause()
            isPlaying = false
        }
    }
    
    func toggleMute() {
        player.isMuted.toggle()
    }
    
    func seek(to time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: cmTime)
    }
    
    func stop() {
        player.pause()
        isPlaying = false
        currentTime = 0
    }
    
    func start() {
        player.play()
        isPlaying = true
    }
}
