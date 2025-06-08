//
//  LikedVideosGrid.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/8/25.
//

import SwiftUI

struct LikedVideosGrid: View {
    let likedVideos: FetchedResults<LikedItem>
    @Binding var thumbnails: [URL: UIImage]
    @Binding var previewingURL: URL?
    @Binding var navigationPath: NavigationPath
    
    var body: some View {
        ForEach(Array(likedVideos.enumerated()), id: \.element) { index, likedItem in
            if let url = URL(string: likedItem.likedVideoURL ?? "") {
                VideoThumbnailView(
                    url: url,
                    thumbnails: $thumbnails,
                    previewingURL: $previewingURL,
                    onTap: {
                        let shareableItem = ShareableItem(
                            id: likedItem.jellyId ?? "",
                            createdAt: ISO8601DateFormatter().string(from: likedItem.createdAt ?? Date()),
                            title: likedItem.title,
                            summary: likedItem.summary,
                            numLikes: Int(likedItem.numLikes),
                            userId: likedItem.userId ?? "",
                            content: ShareableItem.Content(
                                url: likedItem.likedVideoURL ?? "",
                                thumbnails: likedItem.thumbnails ?? []
                            )
                        )
                        navigationPath.append(shareableItem)
                    }
                )
            }
        }
    }
}
