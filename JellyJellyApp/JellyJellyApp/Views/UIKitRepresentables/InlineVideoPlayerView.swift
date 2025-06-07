//
//  InlineVideoPlayerView.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/4/25.
//

import SwiftUI
import AVKit

struct InlineVideoPlayerView: UIViewControllerRepresentable {
    let url: URL
    let onDisappear: () -> Void

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let player = AVPlayer(url: url)
        player.isMuted = true
        player.play()

        let controller = InlineAVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.videoGravity = .resizeAspectFill
        controller.onDisappear = onDisappear

        return controller
    }

    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {}
}

class InlineAVPlayerViewController: AVPlayerViewController {
    var onDisappear: (() -> Void)?

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        onDisappear?()

        DispatchQueue.main.async { [weak self] in
            self?.player?.pause()
            self?.player?.seek(to: .zero)
        }
    }
}

