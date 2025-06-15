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
import Photos

struct LibraryView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject private var appState: AppState
    @StateObject private var cameraController = CameraController()

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \RecordedVideo.createdAt, ascending: false)],
        predicate: NSPredicate(format: "saved == YES"),
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
    @State private var videoToDelete: RecordedVideo? = nil
    @State private var showDeleteConfirmation = false
    @State private var showPhotoLibraryPermissionAlert = false
    @State private var isSavingVideo = false
    @State private var showSaveSuccess = false
    
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
                                navigationPath: $navigationPath,
                                videoToDelete: $videoToDelete,
                                showDeleteConfirmation: $showDeleteConfirmation,
                                onSaveVideo: saveVideoToPhotos
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
        .confirmationDialog(
            "Delete Video",
            isPresented: $showDeleteConfirmation,
            presenting: videoToDelete
        ) { video in
            Button("Delete", role: .destructive) {
                deleteVideo(video)
            }
            Button("Cancel", role: .cancel) {
                videoToDelete = nil
            }
        } message: { video in
            Text("Are you sure you want to delete this video? This action cannot be undone.")
        }
        .alert("Photo Library Access Required", isPresented: $showPhotoLibraryPermissionAlert) {
            Button("Open Settings", role: .none) {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please allow access to your photo library in Settings to save videos.")
        }
        .overlay {
            if isSavingVideo {
                ProgressView("Saving video...")
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 10)
            }
        }
        .overlay {
            if showSaveSuccess {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color("JellyPrimary"))
                        Text("Video saved to Photos")
                            .foregroundColor(.primary)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 10)
                    .padding(.bottom, 50)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut, value: showSaveSuccess)
            }
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

    private func deleteVideo(_ video: RecordedVideo) {
        Task {
            do {
                try await cameraController.deleteVideoFromFirebase(video: video)
                
                await MainActor.run {
                    if let videoURL = video.mergedVideoURL,
                       let lastComponent = videoURL.components(separatedBy: "/").last,
                       let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                        let fullURL = documentsURL.appendingPathComponent(lastComponent)
                        try? FileManager.default.removeItem(at: fullURL)
                    }
                    
                    viewContext.delete(video)
                    try? viewContext.save()
                }
            } catch {
                print("Error deleting video from Firebase: \(error.localizedDescription)")
                if let videoURL = video.mergedVideoURL,
                   let lastComponent = videoURL.components(separatedBy: "/").last,
                   let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                    let fullURL = documentsURL.appendingPathComponent(lastComponent)
                    try? FileManager.default.removeItem(at: fullURL)
                }
                
                viewContext.delete(video)
                try? viewContext.save()
            }
        }
    }

    private func saveVideoToPhotos(_ video: RecordedVideo) {
        guard let videoURL = video.mergedVideoURL,
              let lastComponent = videoURL.components(separatedBy: "/").last,
              let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let fullURL = documentsURL.appendingPathComponent(lastComponent)
        
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    isSavingVideo = true
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fullURL)
                    }) { success, error in
                        DispatchQueue.main.async {
                            isSavingVideo = false
                            if success {
                                showSaveSuccess = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    showSaveSuccess = false
                                }
                            } else if let error = error {
                                print("Error saving video: \(error.localizedDescription)")
                            }
                        }
                    }
                case .denied, .restricted:
                    showPhotoLibraryPermissionAlert = true
                case .notDetermined:
                    break
                @unknown default:
                    break
                }
            }
        }
    }
}
