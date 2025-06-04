//
//  VideoNavigation.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/4/25.
//

struct VideoNavigation: Hashable {
    let videos: [RecordedVideo]
    let currentIndex: Int
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(currentIndex)
        hasher.combine(videos.count)
    }
    
    static func == (lhs: VideoNavigation, rhs: VideoNavigation) -> Bool {
        return lhs.currentIndex == rhs.currentIndex && lhs.videos.count == rhs.videos.count
    }
}
