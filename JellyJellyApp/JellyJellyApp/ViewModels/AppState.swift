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
    
    private let startTime = Date()
    let playerStore = GenericPlayerManagerStore<ShareableItem>()
    
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
                playerStore.preloadManager(for: items[0])
                
                if items.count > 1 {
                    playerStore.preloadManager(for: items[1])
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
}
