//
//  LibraryVideoPlayerView.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/4/25.
//

import SwiftUI

struct LibraryVideoPlayerView: View {
    let videos: [RecordedVideo]
    @State private var currentIndex: Int
    @StateObject private var viewModel = LibraryVideoPlayerViewModel()
    @Binding var selectedTab: Tab
    
    init(videos: [RecordedVideo], currentIndex: Int, selectedTab: Binding<Tab>) {
        self.videos = videos
        self._currentIndex = State(initialValue: currentIndex)
        self._selectedTab = selectedTab
    }

    private func url(for path: String) -> URL? {
        guard let lastComponent = path.components(separatedBy: "/").last,
              let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let fullURL = documentsURL.appendingPathComponent(lastComponent)
        return FileManager.default.fileExists(atPath: fullURL.path) ? fullURL : nil
    }
    
    private func nextVideo() {
        if currentIndex < videos.count - 1 {
            currentIndex += 1
            loadCurrentVideo()
        }
    }
    
    private func previousVideo() {
        if currentIndex > 0 {
            currentIndex -= 1
            loadCurrentVideo()
        }
    }
    
    private func loadCurrentVideo() {
        guard currentIndex < videos.count,
              let videoURL = url(for: videos[currentIndex].mergedVideoURL ?? "") else {
            return
        }
        viewModel.loadVideo(url: videoURL)
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if currentIndex < videos.count,
                   let videoURL = url(for: videos[currentIndex].mergedVideoURL ?? "") {
                    LibraryVideoPlayerContainer(
                        videoURL: videoURL,
                        player: viewModel.player
                    )
                    .gesture(
                        DragGesture(minimumDistance: 50)
                            .onEnded { value in
                                if value.translation.height < 0 {
                                    nextVideo()
                                    
                                    print("Swiped up - previous video")
                                } else if value.translation.height > 0 {
                                    previousVideo()
                                    
                                    print("Swiped down - next video")
                                }
                            }
                    )
                    .onTapGesture {
                        viewModel.togglePlayPause()
                    }
                    .onTapGesture(count: 2) {
                        viewModel.toggleMute()
                    }
                } else {
                    Text("Video not found")
                        .foregroundColor(.white)
                }
                
                if !viewModel.isPlaying && viewModel.duration > 0 {
                    VStack {
                        Spacer()
                        Slider(value: $viewModel.currentTime, in: 0...viewModel.duration, onEditingChanged: { editing in
                            if !editing {
                                viewModel.seek(to: viewModel.currentTime)
                            }
                        })
                        .padding()
                    }
                }
            }
        }
        .onChange(of: selectedTab) { _, newTab in
            if newTab != .library {
                viewModel.stop()
            } else {
                viewModel.start()
            }
        }
        .ignoresSafeArea(edges: [.top, .trailing, .leading])
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadCurrentVideo()
        }
    }
}
