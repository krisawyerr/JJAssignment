//
//  TabbarLottieView.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/6/25.
//

import SwiftUI
import Lottie

struct TabbarLottieView: UIViewRepresentable {
    let animationName: String
    var play: Bool
    var loopMode: LottieLoopMode = .playOnce
    var strokeColor: UIColor = .gray
    var fillColor: UIColor = .gray

    class Coordinator {
        var animationView: LottieAnimationView?

        init(animationView: LottieAnimationView?) {
            self.animationView = animationView
        }
    }

    func makeCoordinator() -> Coordinator {
        return Coordinator(animationView: nil)
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        let animationView = LottieAnimationView(name: animationName)
        animationView.loopMode = loopMode
        animationView.contentMode = .scaleAspectFit
        animationView.translatesAutoresizingMaskIntoConstraints = false

        view.addSubview(animationView)
        NSLayoutConstraint.activate([
            animationView.widthAnchor.constraint(equalTo: view.widthAnchor),
            animationView.heightAnchor.constraint(equalTo: view.heightAnchor),
        ])

        context.coordinator.animationView = animationView

        applyColors(to: animationView, strokeColor: strokeColor, fillColor: fillColor)
 
        animationView.currentProgress = 0

        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        guard let animationView = context.coordinator.animationView else { return }
        
        applyColors(to: animationView, strokeColor: strokeColor, fillColor: fillColor)
        
        if play {
            animationView.play(fromProgress: 0, toProgress: 1, loopMode: loopMode)
        } else {
            animationView.stop()
            animationView.currentProgress = 0
        }
    }
    
    private func applyColors(to animationView: LottieAnimationView, strokeColor: UIColor, fillColor: UIColor) {
        let strokeColorProvider = ColorValueProvider(strokeColor.lottieColorValue)
        let fillColorProvider = ColorValueProvider(fillColor.lottieColorValue)

        let strokeKeypaths = [
            "**.Stroke 1.Color",
            "**.Stroke.Color",
            "**.Border.Color"
        ]

        let fillKeypaths = [
            "**.Fill 1.Color",
            "**.Fill.Color",
            "**.Shape.Color"
        ]

        for keypath in strokeKeypaths {
            animationView.setValueProvider(strokeColorProvider, keypath: AnimationKeypath(keypath: keypath))
        }
        
        for keypath in fillKeypaths {
            animationView.setValueProvider(fillColorProvider, keypath: AnimationKeypath(keypath: keypath))
        }
    }
}
