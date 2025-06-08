
//
//  RecordedVideoExtension.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/6/25.
//

extension LikedItem: VideoPlayable {
    var videoURL: String { likedVideoURL ?? "" }
    public var id: String { objectID.uriRepresentation().absoluteString }
}
