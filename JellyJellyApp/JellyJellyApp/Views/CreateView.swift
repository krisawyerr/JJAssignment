//
//  CreateView.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/3/25.
//

import SwiftUI
import AVFoundation
import CoreData

struct CreateView: View {
    @StateObject private var cameraController = CameraController()
    @Environment(\.managedObjectContext) private var context
    @Binding var selectedTab: Tab
    @Binding var isProcessingVideo: Bool
    @State private var progress: CGFloat = 0.0
    @StateObject private var playerStore = GenericPlayerManagerStore<RecordedVideo>()
    @State private var showingPreview = false

    var body: some View {
        VStack {
            ZStack {
                if showingPreview, let frontURL = cameraController.frontPreviewURL, let backURL = cameraController.backPreviewURL {
                    DualVideoPlayerView(frontURL: frontURL, backURL: backURL)
                } else {
                    CameraPreviewView(controller: cameraController)
                }
                
                if cameraController.isPreviewReady && !showingPreview {
                    VStack {
                        Spacer()
                        
                        Button(action: {
                            if cameraController.isRecording {
                                isProcessingVideo = true
                                cameraController.stopRecording()
                            } else {
                                cameraController.startRecording(context: context)
                            }
                        }) {
                            ZStack {
                                JellyfishShape()
                                    .stroke(Color.white, lineWidth: 3)
                                    .frame(width: 100, height: 80)
                                
                                JellyfishShape()
                                    .trim(from: 0, to: progress)
                                    .stroke(Color("JellyPrimary"), lineWidth: 3)
                                    .frame(width: 100, height: 80)
                                    .animation(.linear(duration: 0.1), value: progress)
                                
                                if !cameraController.isRecording {
                                    JellyfishShape()
                                        .fill(Color("JellyPrimary").opacity(0.3))
                                        .frame(width: 100, height: 80)
                                }
                            }
                        }
                        .scaleEffect(cameraController.isRecording ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: cameraController.isRecording)
                        .padding(.bottom, 50)
                    }
                } else if !showingPreview {
                    LoadingView(text: "setting up camera...")
                }
                
//                if isProcessingVideo {
//                    Color.black.opacity(0.7)
//                        .ignoresSafeArea()
//                        .overlay(
//                            VStack {
//                                ProgressView()
//                                    .scaleEffect(1.5)
//                                    .tint(.white)
//                                Text("Processing video...")
//                                    .foregroundColor(.white)
//                                    .padding(.top)
//                            }
//                        )
//                }
            }
            .onAppear {
                pauseAllVideos()
                cameraController.setupCamera()

//                cameraController.onVideoProcessed = {
//                    isProcessingVideo = false
//                    selectedTab = .library
//                }
            }
            .onDisappear {
                cameraController.stopCamera()
            }
            .onChange(of: cameraController.isRecording) { _, isRecording in
                if isRecording {
                    progress = 0.0
                } else {
                    progress = 0.0
                }
            }
            .onChange(of: cameraController.secondsRemaining) { _, secondsRemaining in
                if cameraController.isRecording {
                    progress = CGFloat(15000 - secondsRemaining) / 15000.0
                    if secondsRemaining <= 0 {
                        isProcessingVideo = true
                    }
                }
            }
            .onChange(of: cameraController.frontPreviewURL) { _, url in
                if url != nil && cameraController.backPreviewURL != nil {
                    withAnimation {
                        showingPreview = true
                    }
                }
            }
            .cornerRadius(16)
        }
        .safeAreaInset(edge: .top) { Spacer().frame(height: 0) }
        .safeAreaInset(edge: .leading) { Spacer().frame(height: 5) }
        .safeAreaInset(edge: .trailing) { Spacer().frame(height: 5) }
    }

    private func pauseAllVideos() {
        let fetchRequest: NSFetchRequest<RecordedVideo> = RecordedVideo.fetchRequest()
        if let videos = try? context.fetch(fetchRequest) {
            for video in videos {
                let manager = playerStore.getManager(for: video)
                manager.pause()
            }
        }
        
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
    }
}

#Preview {
    CreateView(selectedTab: .constant(.create), isProcessingVideo: .constant(false))
        .environmentObject(AppState())
}
