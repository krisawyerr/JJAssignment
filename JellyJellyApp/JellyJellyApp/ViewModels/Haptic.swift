//
//  HapticManager.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/7/25.
//

import UIKit

func triggerHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
    let generator = UIImpactFeedbackGenerator(style: style)
    generator.prepare()
    generator.impactOccurred()
}
