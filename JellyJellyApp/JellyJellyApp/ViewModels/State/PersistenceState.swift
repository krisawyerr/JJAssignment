import Foundation
import CoreData

class PersistenceState: ObservableObject {
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