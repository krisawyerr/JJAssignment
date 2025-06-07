//
//  MuteLottieView.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/6/25.
//

import Lottie
import SwiftUI

struct MuteLottieView: UIViewRepresentable {
    let animationName: String
    @Binding var isPlaying: Bool
    let shouldReverse: Bool
    @State private var animationLoaded = false
    
    func makeUIView(context: Context) -> UIView {
        let containerView = UIView()
        containerView.backgroundColor = UIColor.clear
        
        let animationView = LottieAnimationView(name: animationName)
        animationView.contentMode = .scaleAspectFit
        animationView.loopMode = .playOnce
        animationView.backgroundColor = UIColor.clear
        
        if animationView.animation != nil {
            print("✅ Lottie animation '\(animationName)' loaded successfully")
            animationView.translatesAutoresizingMaskIntoConstraints = false
            containerView.addSubview(animationView)
            
            let colorProvider = ColorValueProvider(UIColor.white.lottieColorValue)
            animationView.setValueProvider(colorProvider, keypath: AnimationKeypath(keypath: "**.Fill 1.Color"))
            animationView.setValueProvider(colorProvider, keypath: AnimationKeypath(keypath: "**.Stroke 1.Color"))
            
            NSLayoutConstraint.activate([
                animationView.topAnchor.constraint(equalTo: containerView.topAnchor),
                animationView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
                animationView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
                animationView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor)
            ])
            
            containerView.tag = 1 
        } else {
            print("❌ Lottie animation '\(animationName)' failed to load - using fallback")
            
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFit
            imageView.tintColor = UIColor.white 
            imageView.image = UIImage(systemName: "speaker.slash.fill")
            imageView.translatesAutoresizingMaskIntoConstraints = false
            
            containerView.addSubview(imageView)
            NSLayoutConstraint.activate([
                imageView.centerXAnchor.constraint(equalTo: containerView.centerXAnchor),
                imageView.centerYAnchor.constraint(equalTo: containerView.centerYAnchor),
                imageView.widthAnchor.constraint(equalToConstant: 24),
                imageView.heightAnchor.constraint(equalToConstant: 24)
            ])
            
            containerView.tag = 2 
        }
        
        return containerView
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if uiView.tag == 1, let lottieView = uiView.subviews.first as? LottieAnimationView {
            guard lottieView.animation != nil else { return }
            
            if isPlaying {
                triggerHaptic(.soft)
                if shouldReverse {
                    print("🔄 Playing animation in reverse")
                    lottieView.play(fromProgress: 1.0, toProgress: 0.0, loopMode: .playOnce) { _ in
                        lottieView.currentProgress = 0.0
                    }
                } else {
                    print("▶️ Playing animation forward")
                    lottieView.play(fromProgress: 0.0, toProgress: 1.0, loopMode: .playOnce) { _ in
                        lottieView.currentProgress = 1.0
                    }
                }
            } else {
                lottieView.stop()
                lottieView.currentProgress = shouldReverse ? 0.0 : 1.0
            }
        } else if uiView.tag == 2, let imageView = uiView.subviews.first as? UIImageView {
            let symbolName = shouldReverse ? "speaker.fill" : "speaker.slash.fill"
            imageView.image = UIImage(systemName: symbolName)
            imageView.tintColor = UIColor.white
        }
    }
}
