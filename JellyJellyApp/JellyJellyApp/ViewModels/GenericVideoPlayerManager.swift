//
//  GenericVideoPlayerManager.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/6/25.
//

import SwiftUI
import AVFoundation
import UIKit
import Lottie

class GenericVideoPlayerManager<T: VideoPlayable>: NSObject, ObservableObject {
    @Published var player: AVPlayer?
    @Published var isPlaying = false
    @Published var isMuted = false
    @Published var playerStatus: AVPlayerItem.Status = .unknown
    @Published var isLoading = true
    @Published var currentTime: Double = 0
    @Published var duration: Double = 1
    @Published var shouldAnimateMute = false
    
    private var playerItem: AVPlayerItem?
    private let videoItem: T
    private var statusObserver: NSKeyValueObservation?
    private var endTimeObserver: NSObjectProtocol?
    private var timeObserverToken: Any?
    private var isSetup = false
    private let globalMuteManager = GlobalMuteManager.shared
    
    init(videoItem: T) {
        self.videoItem = videoItem
        super.init()
        
        self.isMuted = globalMuteManager.isGloballyMuted
    }
    
    func setupPlayerIfNeeded() {
        guard !isSetup else { return }
        isSetup = true
        setupPlayer()
    }
    
    private func setupPlayer() {
        cleanupObservers()
        
        let videoURL: URL?
        
        if videoItem.videoURL.hasPrefix("http") {
            videoURL = URL(string: videoItem.videoURL)
        } else {
            guard let lastComponent = videoItem.videoURL.components(separatedBy: "/").last,
                  let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                DispatchQueue.main.async {
                    self.playerStatus = .failed
                    self.isLoading = false
                }
                return
            }
            let fullURL = documentsURL.appendingPathComponent(lastComponent)
            videoURL = FileManager.default.fileExists(atPath: fullURL.path) ? fullURL : nil
        }
        
        guard let url = videoURL else {
            DispatchQueue.main.async {
                self.playerStatus = .failed
                self.isLoading = false
            }
            return
        }
        
        let asset = AVURLAsset(url: url)
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 2.0
        
        self.playerItem = item
        player = AVPlayer(playerItem: item)
        player?.automaticallyWaitsToMinimizeStalling = false
        player?.volume = 1.0
        
        player?.isMuted = globalMuteManager.isGloballyMuted
        self.isMuted = globalMuteManager.isGloballyMuted
        
        statusObserver = item.observe(\.status, options: [.new]) { [weak self] playerItem, _ in
            DispatchQueue.main.async {
                self?.handleStatusChange(playerItem.status)
            }
        }
        
        endTimeObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: item,
            queue: .main
        ) { [weak self] _ in
            self?.player?.seek(to: .zero)
            self?.currentTime = 0
            if self?.isPlaying == true {
                self?.player?.play()
            }
        }
        
        addPeriodicTimeObserver()
        
        loadDuration()
    }
    
    private func handleStatusChange(_ status: AVPlayerItem.Status) {
        playerStatus = status
        
        switch status {
        case .readyToPlay:
            isLoading = false
            player?.isMuted = globalMuteManager.isGloballyMuted
            if isPlaying {
                player?.play()
            }
        case .failed:
            isLoading = false
            if let error = playerItem?.error {
                print("❌ Player failed with error: \(error.localizedDescription)")
            }
        case .unknown:
            isLoading = true
        @unknown default:
            isLoading = false
        }
    }
    
    func play() {
        isPlaying = true
        setupPlayerIfNeeded()
        
        if playerStatus == .readyToPlay {
            player?.isMuted = globalMuteManager.isGloballyMuted
            player?.play()
        }
    }
    
    func pause() {
        player?.pause()
        isPlaying = false
    }
    
    func togglePlayback() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }
    
    func toggleMute() {
        globalMuteManager.setMuted(!globalMuteManager.isGloballyMuted)
        
        isMuted = globalMuteManager.isGloballyMuted
        player?.isMuted = globalMuteManager.isGloballyMuted
        
        shouldAnimateMute = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.shouldAnimateMute = false
        }
    }
    
    func seek(to time: Double) {
        guard let player = player else { return }
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: cmTime) { [weak self] _ in
            DispatchQueue.main.async {
                self?.currentTime = time
            }
        }
    }
    
    private func addPeriodicTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserverToken = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self else { return }
            self.currentTime = time.seconds
        }
    }
    
    private func loadDuration() {
        guard let item = playerItem else { return }
        
        Task {
            do {
                let duration = try await item.asset.load(.duration)
                await MainActor.run {
                    if duration.seconds.isFinite && !duration.seconds.isNaN {
                        self.duration = duration.seconds
                    }
                }
            } catch {
                print("Failed to load duration: \(error)")
            }
        }
    }

    func preload() {
        setupPlayerIfNeeded()
    }
    
    func syncMuteState() {
        isMuted = globalMuteManager.isGloballyMuted
        player?.isMuted = globalMuteManager.isGloballyMuted
    }
    
    private func cleanupObservers() {
        statusObserver?.invalidate()
        statusObserver = nil
        
        if let endObserver = endTimeObserver {
            NotificationCenter.default.removeObserver(endObserver)
            endTimeObserver = nil
        }
        
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }
    }
    
    deinit {
        cleanupObservers()
        player?.pause()
        player = nil
    }
}
