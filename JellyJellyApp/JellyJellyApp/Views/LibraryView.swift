//
//  LibraryView.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/3/25.
//

import SwiftUI
import CoreData
import AVFoundation
import AVKit

struct LibraryView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \RecordedVideo.createdAt, ascending: false)],
        animation: .default)
    private var videos: FetchedResults<RecordedVideo>

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    @State private var previewingURL: URL? = nil
    @State private var navigationPath = NavigationPath()
    
    @Binding var selectedTab: Tab
    @State private var previousTab: Tab = .home

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(Array(videos.enumerated()), id: \.element) { index, recording in
                        if let url = getVideoURL(from: recording.mergedVideoURL ?? "") {
                            ZStack {
                                if previewingURL == url {
                                    InlineVideoPlayerView(url: url, onDisappear: {
                                        previewingURL = nil
                                    })
                                        .frame(height: 200)
                                        .cornerRadius(12)
                                } else if let thumbnail = generateThumbnail(from: url) {
                                    Button {
                                        navigationPath.append(VideoNavigation(videos: Array(videos), currentIndex: index))
                                    } label: {
                                        Image(uiImage: thumbnail)
                                            .resizable()
                                            .aspectRatio(9/16, contentMode: .fill)
                                            .frame(height: 200)
                                            .clipped()
                                            .cornerRadius(12)
                                            .onLongPressGesture {
                                                previewingURL = url
                                            }
                                    }
                                }
                            }
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 200)
                                .cornerRadius(12)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Saved Recordings")
            .navigationDestination(for: VideoNavigation.self) { videoNav in
                LibraryVideoPlayerView(
                    videos: videoNav.videos,
                    currentIndex: videoNav.currentIndex,
                    selectedTab: $selectedTab
                )
            }
        }
        .onChange(of: selectedTab) { newTab in
            if previousTab != newTab {
                navigationPath = NavigationPath()
            }
            previousTab = newTab
        }
        .onAppear {
            previousTab = selectedTab
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

    private func generateThumbnail(from url: URL) -> UIImage? {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true

        do {
            let cgImage = try imageGenerator.copyCGImage(at: .zero, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            print("❌ Thumbnail error: \(error.localizedDescription)")
            return nil
        }
    }
}
