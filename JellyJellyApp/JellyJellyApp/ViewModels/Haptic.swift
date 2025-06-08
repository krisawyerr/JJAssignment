//
//  HapticManager.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/7/25.
//

import UIKit

func triggerHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
    let impactFeedback = UIImpactFeedbackGenerator(style: style)
    impactFeedback.prepare()
    impactFeedback.impactOccurred()
}
