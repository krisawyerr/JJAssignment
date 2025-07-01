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
    @Published var shareableItems: [ShareableItem] = []
    @Published var wasInitiallySetup = false
    @Published var isLoading = true
    
    @Published var cameraController = CameraController()
    
    @Published var selectedTab: Tab = .create
    @Published var isShowingPreview = false
    
    private let startTime = Date()
    let shareablePlayerStore = GenericPlayerManagerStore<ShareableItem>()
    let recordedPlayerStore = GenericPlayerManagerStore<RecordedVideo>()
    let likedPlayerStore = GenericPlayerManagerStore<LikedItem>()
    
    private var currentVideoIndex: Int = 0
    private var wasPlayingBeforeBackground = false
    private var currentVideoType: VideoType = .shareable
    
    enum VideoType {
        case shareable
        case liked
        case recorded
    }
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "JellyJellyApp")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
        })
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()
    
    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    init() {
        cameraController.setupCamera()
        Task {
            await loadInitialData()
        }
    }
    
    func loadInitialData() async {
        do {
            let items = try await fetchShareableItems()
            let endTime = Date()
            let timeInterval = endTime.timeIntervalSince(startTime)
            print("Time from app start to fetchShareableItems response: \(timeInterval) seconds")
            self.shareableItems = items
            
            if !items.isEmpty {
                shareablePlayerStore.preloadManager(for: items[0])
                
                if items.count > 1 {
                    shareablePlayerStore.preloadManager(for: items[1])
                }
            }
        } catch {
            print("Error fetching shareable item:", error)
        }
        self.isLoading = false
    }
    
    private func fetchShareableItems() async throws -> [ShareableItem] {
        let url = URL(string: "https://playwright-proxy.fly.dev/data")!
        let (data, _) = try await URLSession.shared.data(from: url)
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([ShareableItem].self, from: data)
    }
    
    func handleInitialSetup() {
        self.wasInitiallySetup = true
    }
    
    func saveContext() {
        let context = persistentContainer.viewContext
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
        }
    }
    
    func likeItem(_ item: ShareableItem) {
        let context = persistentContainer.viewContext
        
        let fetchRequest: NSFetchRequest<LikedItem> = LikedItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "jellyId == %@", item.id)
        
        do {
            let existingItems = try context.fetch(fetchRequest)
            if let existingItem = existingItems.first {
                context.delete(existingItem)
            } else {
                let likedItem = LikedItem(context: context)
                likedItem.jellyId = item.id
                likedItem.createdAt = ISO8601DateFormatter().date(from: item.createdAt)
                likedItem.title = item.title
                likedItem.summary = item.summary
                likedItem.numLikes = Int32(item.numLikes)
                likedItem.userId = item.userId
                likedItem.likedVideoURL = item.content.url
                likedItem.thumbnails = item.content.thumbnails
            }
            
            try context.save()
        } catch {
            print("Error handling like: \(error)")
        }
    }
    
    func isItemLiked(_ itemId: String) -> Bool {
        let context = persistentContainer.viewContext
        let fetchRequest: NSFetchRequest<LikedItem> = LikedItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "jellyId == %@", itemId)
        
        do {
            let count = try context.count(for: fetchRequest)
            return count > 0
        } catch {
            print("Error checking if item is liked: \(error)")
            return false
        }
    }
        
    func updateCurrentVideoIndex(_ index: Int, type: VideoType = .shareable) {
        currentVideoIndex = index
        currentVideoType = type
    }
    
    func pauseVideoPlayback() {
        switch currentVideoType {
        case .shareable:
            pauseShareableVideos()
        case .liked:
            pauseLikedVideos()
        case .recorded:
            pauseRecordedVideos()
        }
    }
    
    func resumeVideoPlayback() {
        switch currentVideoType {
        case .shareable:
            resumeShareableVideos()
        case .liked:
            resumeLikedVideos()
        case .recorded:
            resumeRecordedVideos()
        }
    }
    
    private func pauseShareableVideos() {
        guard !shareableItems.isEmpty else { return }
        
        if currentVideoIndex < shareableItems.count {
            let currentItem = shareableItems[currentVideoIndex]
            let manager = shareablePlayerStore.getManager(for: currentItem)
            wasPlayingBeforeBackground = manager.isPlaying
            
            for item in shareableItems {
                let manager = shareablePlayerStore.getManager(for: item)
                manager.pause()
            }
        }
        
        print("Paused shareable video playback - was playing: \(wasPlayingBeforeBackground)")
    }
    
    private func resumeShareableVideos() {
        guard !shareableItems.isEmpty else { return }
        
        if currentVideoIndex < shareableItems.count && wasPlayingBeforeBackground {
            let currentItem = shareableItems[currentVideoIndex]
            let manager = shareablePlayerStore.getManager(for: currentItem)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                manager.play()
                print("Resumed shareable video playback for index: \(self.currentVideoIndex)")
            }
        }
    }
    
    private func pauseLikedVideos() {
        let fetchRequest: NSFetchRequest<LikedItem> = LikedItem.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \LikedItem.createdAt, ascending: false)]
        
        do {
            let likedVideos = try viewContext.fetch(fetchRequest)
            guard !likedVideos.isEmpty else { return }
            
            if currentVideoIndex < likedVideos.count {
                let currentItem = likedVideos[currentVideoIndex]
                let manager = likedPlayerStore.getManager(for: currentItem)
                wasPlayingBeforeBackground = manager.isPlaying
                
                for item in likedVideos {
                    let manager = likedPlayerStore.getManager(for: item)
                    manager.pause()
                }
            }
            
            print("Paused liked video playback - was playing: \(wasPlayingBeforeBackground)")
        } catch {
            print("Error fetching liked videos: \(error)")
        }
    }
    
    private func resumeLikedVideos() {
        let fetchRequest: NSFetchRequest<LikedItem> = LikedItem.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \LikedItem.createdAt, ascending: false)]
        
        do {
            let likedVideos = try viewContext.fetch(fetchRequest)
            guard !likedVideos.isEmpty else { return }
            
            if currentVideoIndex < likedVideos.count && wasPlayingBeforeBackground {
                let currentItem = likedVideos[currentVideoIndex]
                let manager = likedPlayerStore.getManager(for: currentItem)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    manager.play()
                    print("Resumed liked video playback for index: \(self.currentVideoIndex)")
                }
            }
        } catch {
            print("Error fetching liked videos: \(error)")
        }
    }
    
    private func pauseRecordedVideos() {
        let fetchRequest: NSFetchRequest<RecordedVideo> = RecordedVideo.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "saved == YES")
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \RecordedVideo.createdAt, ascending: false)]
        
        do {
            let recordedVideos = try viewContext.fetch(fetchRequest)
            guard !recordedVideos.isEmpty else { return }
            
            if currentVideoIndex < recordedVideos.count {
                let currentItem = recordedVideos[currentVideoIndex]
                let manager = recordedPlayerStore.getManager(for: currentItem)
                wasPlayingBeforeBackground = manager.isPlaying
                
                for item in recordedVideos {
                    let manager = recordedPlayerStore.getManager(for: item)
                    manager.pause()
                }
            }
            
            print("Paused recorded video playback - was playing: \(wasPlayingBeforeBackground)")
        } catch {
            print("Error fetching recorded videos: \(error)")
        }
    }
    
    private func resumeRecordedVideos() {
        let fetchRequest: NSFetchRequest<RecordedVideo> = RecordedVideo.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "saved == YES")
        fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \RecordedVideo.createdAt, ascending: false)]
        
        do {
            let recordedVideos = try viewContext.fetch(fetchRequest)
            guard !recordedVideos.isEmpty else { return }
            
            if currentVideoIndex < recordedVideos.count && wasPlayingBeforeBackground {
                let currentItem = recordedVideos[currentVideoIndex]
                let manager = recordedPlayerStore.getManager(for: currentItem)
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    manager.play()
                    print("Resumed recorded video playback for index: \(self.currentVideoIndex)")
                }
            }
        } catch {
            print("Error fetching recorded videos: \(error)")
        }
    }
}
