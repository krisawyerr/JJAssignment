//
//  AppState.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/6/25.
//

struct ShareableItem: Codable, Identifiable, Equatable {
    let id: String
    let createdAt: String
    let title: String
    let summary: String
    let numLikes: Int
    let userId: String
    let content: Content

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt = "created_at"
        case title
        case summary
        case numLikes = "num_likes"
        case userId = "user_id"
        case content
    }

    struct Content: Codable, Equatable {
        let url: String
        let thumbnails: [String]
    }
}

extension ShareableItem: VideoPlayable {
    var videoURL: String { content.url }
}
