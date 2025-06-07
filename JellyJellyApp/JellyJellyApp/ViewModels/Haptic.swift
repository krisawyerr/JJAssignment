//
//  HapticManager.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/7/25.
//

import UIKit

func triggerHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
    print("Triggering haptic feedback")
    let impactFeedback = UIImpactFeedbackGenerator(style: style)
    impactFeedback.prepare()
    impactFeedback.impactOccurred()
    print("Haptic feedback triggered")
}
