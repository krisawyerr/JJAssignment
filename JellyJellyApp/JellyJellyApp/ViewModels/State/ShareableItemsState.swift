import Foundation
import Combine

class ShareableItemsState: ObservableObject {
    @Published var shareableItems: [ShareableItem] = []
    
    private let startTime = Date()
    
    private func fetchShareableItems() async throws -> [ShareableItem] {
        let url = URL(string: "https://playwright-proxy.fly.dev/data")!
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([ShareableItem].self, from: data)
    }
    
    func loadInitialData() async {
        do {
            let items = try await fetchShareableItems()
            let endTime = Date()
            let timeInterval = endTime.timeIntervalSince(startTime)
            print("Time from app start to fetchShareableItems response: \(timeInterval) seconds")
            self.shareableItems = items
        } catch {
            print("Error fetching shareable item:", error)
        }
    }
} 