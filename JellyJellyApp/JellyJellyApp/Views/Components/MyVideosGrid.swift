//
//  MyVideosGrid.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/8/25.
//

import SwiftUI

struct MyVideosGrid: View {
    let videos: FetchedResults<RecordedVideo>
    @Binding var thumbnails: [URL: UIImage]
    @Binding var previewingURL: URL?
    @Binding var navigationPath: NavigationPath
    @Binding var videoToDelete: RecordedVideo?
    @Binding var showDeleteConfirmation: Bool
    var onSaveVideo: (RecordedVideo) -> Void
    
    var body: some View {
        ForEach(Array(videos.enumerated()), id: \.element) { index, recording in
            ZStack(alignment: .topTrailing) {
                VideoThumbnailView(
                    url: getVideoURL(from: recording.mergedVideoURL ?? ""),
                    thumbnails: $thumbnails,
                    previewingURL: $previewingURL,
                    onTap: {
                        navigationPath.append(VideoNavigation(videos: Array(videos), currentIndex: index))
                    }
                )
                
                Menu {
                    Button(action: {
                        onSaveVideo(recording)
                    }) {
                        Label("Save to Photos", systemImage: "arrow.down.circle")
                    }
                    
                    if let firebaseURL = recording.firebaseStorageURL,
                       let url = URL(string: firebaseURL) {
                        Button(action: {
                            UIApplication.shared.open(url)
                        }) {
                            Label("Open in Browser", systemImage: "safari")
                        }
                    }
                    
                    Button(role: .destructive, action: {
                        videoToDelete = recording
                        showDeleteConfirmation = true
                    }) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                }
                .padding(8)
            }
        }
    }
    
    private func getVideoURL(from path: String) -> URL? {
        guard let lastComponent = path.components(separatedBy: "/").last,
              let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let fullURL = documentsURL.appendingPathComponent(lastComponent)
        return FileManager.default.fileExists(atPath: fullURL.path) ? fullURL : nil
    }
}
