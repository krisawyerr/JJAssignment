//
//  HomeView.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/3/25.
//

import SwiftUI
import AVKit
import AVFoundation

struct HomeView: View {
    @EnvironmentObject var appState: AppState
    @Binding var selectedTab: Tab
    @StateObject private var viewModel = VideoPlayerViewModel()

    var body: some View {
        ZStack {
            if appState.isLoading {
                LoadingView()
            } else if appState.shareableItems.isEmpty {
                Text("No videos found")
            } else {
                VideoPlayerContainer(player: viewModel.player)
                    .ignoresSafeArea(edges: [.top, .leading, .trailing])
                    .gesture(
                        DragGesture(minimumDistance: 50)
                            .onEnded { val in
                                if val.translation.height < 0 {
                                    viewModel.previousVideo()
                                    print("Swiped up")
                                } else if val.translation.height > 0 {
                                    viewModel.nextVideo()
                                    print("Swiped down")  
                                }
                            }
                    )
                    .onTapGesture {
                        viewModel.togglePlayPause()
                    }
                    .onTapGesture(count: 2) {
                        viewModel.toggleMute()
                    }
                    .onDisappear {
                        DispatchQueue.main.async {
                            viewModel.player.pause()
                            viewModel.player.seek(to: .zero)
                        }
                    }
                if !viewModel.isPlaying {
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
            if newTab != .home {
                viewModel.stop() 
            } else {
                viewModel.start()
            }
        }
        .onChange(of: appState.shareableItems) { _, items in
            let urls = items.compactMap { URL(string: $0.content.url) }
            viewModel.setVideoURLs(urls)
        }
    }
}


#Preview {
    ContentView()
        .environmentObject(AppState())
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
