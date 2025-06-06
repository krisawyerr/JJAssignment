//
//  RecordedVideoExtension.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/6/25.
//

extension RecordedVideo: VideoPlayable {
    var videoURL: String { mergedVideoURL ?? "" }
    public var id: String { objectID.uriRepresentation().absoluteString }
}
