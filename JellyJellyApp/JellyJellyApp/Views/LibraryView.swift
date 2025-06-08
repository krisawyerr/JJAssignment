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
    @EnvironmentObject private var appState: AppState

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \RecordedVideo.createdAt, ascending: false)],
        animation: .default)
    private var videos: FetchedResults<RecordedVideo>
    
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \LikedItem.createdAt, ascending: false)],
        animation: .default)
    private var likedVideos: FetchedResults<LikedItem>

    private let columns = [
        GridItem(.flexible(), spacing: 5),
        GridItem(.flexible(), spacing: 5),
        GridItem(.flexible(), spacing: 5)
    ]

    @State private var previewingURL: URL? = nil
    @State private var navigationPath = NavigationPath()
    @State private var thumbnails: [URL: UIImage] = [:]
    @State private var selectedLibraryTab: LibraryTab = .myVideos
    
    @Binding var selectedTab: Tab
    @State private var previousTab: Tab = .home
    
    enum LibraryTab {
        case myVideos
        case likedVideos
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                LibraryTabBar(selectedTab: $selectedLibraryTab)
                
                ScrollView(showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 5) {
                        if selectedLibraryTab == .myVideos {
                            MyVideosGrid(
                                videos: videos,
                                thumbnails: $thumbnails,
                                previewingURL: $previewingURL,
                                navigationPath: $navigationPath
                            )
                        } else {
                            LikedVideosGrid(
                                likedVideos: likedVideos,
                                thumbnails: $thumbnails,
                                previewingURL: $previewingURL,
                                navigationPath: $navigationPath
                            )
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("JellyRoll")
            .navigationDestination(for: VideoNavigation.self) { videoNav in
                LibraryVideoPlayerView(
                    videos: videoNav.videos,
                    currentIndex: videoNav.currentIndex,
                    selectedTab: $selectedTab,
                    navigationPath: $navigationPath
                )
                .navigationBarBackButtonHidden(true)
                .background(Color("Background"))
            }
            .navigationDestination(for: ShareableItem.self) { item in
                LikedItemsPlayerView(
                    videos: Array(likedVideos),
                    currentIndex: likedVideos.firstIndex(where: { $0.jellyId == item.id }) ?? 0,
                    selectedTab: $selectedTab,
                    navigationPath: $navigationPath
                )
                .navigationBarBackButtonHidden(true)
                .background(Color("Background"))
            }
            .background(Color("Background"))
        }
        .onChange(of: selectedTab) { _, newTab in
            if previousTab != newTab {
                navigationPath = NavigationPath()
            }
            previousTab = newTab
        }
        .onAppear {
            previousTab = selectedTab
            setupNavigationBarAppearance()
        }
    }
    
    private func setupNavigationBarAppearance() {
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(named: "Background")
        
        if let customFont = UIFont(name: "Ranchers-Regular", size: 30) {
            appearance.largeTitleTextAttributes = [
                .font: customFont,
                .foregroundColor: UIColor.white,
                .kern: 2 
            ]
            appearance.titleTextAttributes = [
                .font: customFont,
                .foregroundColor: UIColor.white,
                .kern: 2
            ]
        } else {
            print("Font not found: Ranchers-Regular")
        }

        appearance.shadowColor = .clear

        let navBar = UINavigationBar.appearance()
        navBar.standardAppearance = appearance
        navBar.scrollEdgeAppearance = appearance
        navBar.compactAppearance = appearance
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
