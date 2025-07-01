//
//  AppState.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/3/25.
//

import Foundation
import Combine
import CoreData

@MainActor
class AppState: ObservableObject {
    @Published var selectedTab: Tab = .create
    @Published var isShowingPreview = false
    @Published var isLoading = true
    
    @Published var cameraState = CameraState()
    @Published var shareableItemsState = ShareableItemsState()
    @Published var videoPlaybackState = VideoPlaybackState()
    @Published var persistenceState = PersistenceState()
    
    init() {
        Task {
            await shareableItemsState.loadInitialData()
            self.isLoading = false
        }
    }
}
