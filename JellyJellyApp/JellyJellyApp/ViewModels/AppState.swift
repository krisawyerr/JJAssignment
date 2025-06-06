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
            self.shareableItems = items
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
}
