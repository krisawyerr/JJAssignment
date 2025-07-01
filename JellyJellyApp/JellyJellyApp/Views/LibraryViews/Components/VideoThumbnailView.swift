//
//  VideoThumbnailView.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/8/25.
//

import SwiftUI
import AVFoundation

struct VideoThumbnailView: View {
    let url: URL?
    @Binding var thumbnails: [URL: UIImage]
    @Binding var previewingURL: URL?
    let onTap: () -> Void
    @State private var isLongPressing = false
    
    var body: some View {
        if let url = url {
            ZStack {
                if previewingURL == url {
                    InlineVideoPlayerView(url: url, onDisappear: {
                        previewingURL = nil
                    })
                        .frame(height: 200)
                        .cornerRadius(5)
                } else {
                    Button(action: {
                        if !isLongPressing {
                            onTap()
                        }
                    }) {
                        if let thumbnail = thumbnails[url] {
                            Image(uiImage: thumbnail)
                                .resizable()
                                .aspectRatio(9/16, contentMode: .fill)
                                .frame(height: 200)
                                .clipped()
                                .cornerRadius(5)
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 200)
                                .cornerRadius(5)
                                .task {
                                    if let thumbnail = await generateThumbnail(from: url) {
                                        thumbnails[url] = thumbnail
                                    }
                                }
                        }
                    }
                }
            }
            .simultaneousGesture(
                LongPressGesture(minimumDuration: 0.5)
                    .onEnded { _ in
                        isLongPressing = true
                        previewingURL = url
                    }
            )
            .onTapGesture {
                isLongPressing = false
            }
        } else {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 200)
                .cornerRadius(5)
        }
    }
    
    private func generateThumbnail(from url: URL) async -> UIImage? {
        let asset = AVURLAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        do {
            let cgImage = try await imageGenerator.image(at: .zero).image
            return UIImage(cgImage: cgImage)
        } catch {
            print("Error: \(error.localizedDescription)")
            return nil
        }
    }
}
