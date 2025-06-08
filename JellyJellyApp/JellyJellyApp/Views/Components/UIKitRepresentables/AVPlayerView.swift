//
//  AVPlayerView.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/6/25.
//

import SwiftUI
import AVFoundation

struct AVPlayerView: UIViewRepresentable {
    let player: AVPlayer
    
    func makeUIView(context: Context) -> PlayerUIView {
        let view = PlayerUIView()
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspectFill
        view.playerLayer = playerLayer
        view.layer.addSublayer(playerLayer)
        return view
    }
    
    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.playerLayer?.frame = uiView.bounds
    }
}

class PlayerUIView: UIView {
    var playerLayer: AVPlayerLayer?
    
    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer?.frame = bounds
    }
}
