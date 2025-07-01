import Foundation
import Combine
import CoreData

@MainActor
class VideoPlaybackState: ObservableObject {
    enum VideoType {
        case shareable
        case liked
        case recorded
    }
    
    @Published var currentVideoIndex: Int = 0
    @Published var currentVideoType: VideoType = .shareable
    @Published var wasPlayingBeforeBackground = false
    
    let shareablePlayerStore = GenericPlayerManagerStore<ShareableItem>()
    let recordedPlayerStore = GenericPlayerManagerStore<RecordedVideo>()
    let likedPlayerStore = GenericPlayerManagerStore<LikedItem>()
    
    func updateCurrentVideoIndex(_ index: Int, type: VideoType = .shareable) {
        currentVideoIndex = index
        currentVideoType = type
    }
    
    func pauseVideoPlayback(shareableItems: [ShareableItem], likedItems: [LikedItem], recordedItems: [RecordedVideo]) {
        switch currentVideoType {
        case .shareable:
            for item in shareableItems {
                let manager = shareablePlayerStore.getManager(for: item)
                manager.pause()
            }
        case .liked:
            for item in likedItems {
                let manager = likedPlayerStore.getManager(for: item)
                manager.pause()
            }
        case .recorded:
            for item in recordedItems {
                let manager = recordedPlayerStore.getManager(for: item)
                manager.pause()
            }
        }
    }

    func resumeVideoPlayback(shareableItems: [ShareableItem], likedItems: [LikedItem], recordedItems: [RecordedVideo]) {
        switch currentVideoType {
        case .shareable:
            if currentVideoIndex < shareableItems.count {
                let manager = shareablePlayerStore.getManager(for: shareableItems[currentVideoIndex])
                manager.play()
            }
        case .liked:
            if currentVideoIndex < likedItems.count {
                let manager = likedPlayerStore.getManager(for: likedItems[currentVideoIndex])
                manager.play()
            }
        case .recorded:
            if currentVideoIndex < recordedItems.count {
                let manager = recordedPlayerStore.getManager(for: recordedItems[currentVideoIndex])
                manager.play()
            }
        }
    }
} 