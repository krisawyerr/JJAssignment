//
//  GenericPlayerManagerStore.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/6/25.
//

import SwiftUI
import AVFoundation
import UIKit
import Lottie

@MainActor
class GenericPlayerManagerStore<T: VideoPlayable>: ObservableObject {
    private var managers: [String: GenericVideoPlayerManager<T>] = [:]
    
    func getManager(for item: T) -> GenericVideoPlayerManager<T> {
        if let existing = managers[item.id] {
            return existing
        }
        
        let manager = GenericVideoPlayerManager(videoItem: item)
        managers[item.id] = manager
        return manager
    }
    
    func preloadManager(for item: T) {
        let manager = getManager(for: item)
        manager.preload()
    }
}
