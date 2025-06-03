//
//  AppState.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/3/25.
//

import Foundation
import Combine

@MainActor
class AppState: ObservableObject {
    @Published var shareableItems: [ShareableItem] = []
    @Published var isLoading = true

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
    }}


struct ShareableItem: Codable, Identifiable, Equatable {
    let id: String
    let createdAt: String
    let title: String
    let summary: String
    let numLikes: Int
    let userId: String
    let content: Content
    let mediaLinks: MediaLinks

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case title
        case summary
        case numLikes = "num_likes"
        case userId = "user_id"
        case content
        case mediaLinks = "media_links"
    }

    struct Content: Codable, Equatable {
        let url: String
        let thumbnails: [String]
    }

    struct MediaLinks: Codable, Equatable {
        let p144: String?
        let p240: String?
        let p360: String?
        let p540: String?
        let p720: String?
        let p1080: String?
        let audio: String?
        let master: String?

        enum CodingKeys: String, CodingKey {
            case p144 = "144p"
            case p240 = "240p"
            case p360 = "360p"
            case p540 = "540p"
            case p720 = "720p"
            case p1080 = "1080p"
            case audio
            case master
        }
    }
}


