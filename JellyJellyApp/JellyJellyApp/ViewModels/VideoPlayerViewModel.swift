//
//  VideoPlayerViewModel.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/3/25.
//

import SwiftUI
import AVKit
import AVFoundation

class VideoPlayerViewModel: ObservableObject {
    @Published var isPlaying = true
    @Published var isMuted = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 1

    let player = AVPlayer()
    private var timeObserverToken: Any?
    private var videoURLs: [URL] = []
    private var currentIndex = 0

    init() {
        configureAudioSession()
        addPeriodicTimeObserver()
    }

    deinit {
        if let token = timeObserverToken {
            player.removeTimeObserver(token)
        }
    }

    func setVideoURLs(_ urls: [URL]) {
        self.videoURLs = urls
        currentIndex = 0
        playCurrent()
    }
    
    private func configureAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Failed to set audio session: \(error)")
        }
    }

    private func playCurrent() {
        guard videoURLs.indices.contains(currentIndex) else { return }
        let item = AVPlayerItem(url: videoURLs[currentIndex])
        player.replaceCurrentItem(with: item)

        player.currentItem?.asset.loadValuesAsynchronously(forKeys: ["duration"]) {
            DispatchQueue.main.async {
                let duration = self.player.currentItem?.asset.duration.seconds ?? 1
                self.duration = duration
            }
        }

        player.play()
        isPlaying = true
    }

    func togglePlayPause() {
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
    }

    func toggleMute() {
        player.isMuted.toggle()
        isMuted = player.isMuted
    }

    func nextVideo() {
        guard !videoURLs.isEmpty else { return }
        currentIndex = (currentIndex + 1) % videoURLs.count
        playCurrent()
    }

    func previousVideo() {
        guard !videoURLs.isEmpty else { return }
        currentIndex = (currentIndex - 1 + videoURLs.count) % videoURLs.count
        playCurrent()
    }

    func seek(to time: Double) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player.seek(to: cmTime)
        currentTime = time
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

    private func addPeriodicTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserverToken = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self = self, self.isPlaying == false else { return }
            self.currentTime = time.seconds
        }
    }
}
