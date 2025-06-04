//
//  LibraryVideoPlayerContainer.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/4/25.
//

import SwiftUI
import AVKit

struct LibraryVideoPlayerContainer: UIViewControllerRepresentable {
    let videoURL: URL
    let player: AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = false
        controller.entersFullScreenWhenPlaybackBegins = false
        controller.exitsFullScreenWhenPlaybackEnds = false
        controller.videoGravity = .resizeAspectFill
        
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.playerItemDidReachEnd(notification:)),
            name: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem)
        
        return controller
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(player: player)
    }
    
    class Coordinator: NSObject {
        var player: AVPlayer
        
        init(player: AVPlayer) {
            self.player = player
        }
        
        @objc func playerItemDidReachEnd(notification: Notification) {
            player.seek(to: .zero)
            player.play()
        }
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {

    }
}
