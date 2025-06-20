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
    @EnvironmentObject var appState: AppState
    @ObservedObject var cameraController: CameraController
    @Environment(\.managedObjectContext) private var context
    @Binding var selectedTab: Tab
    @Binding var isProcessingVideo: Bool
    @State private var progress: CGFloat = 0.0
    @StateObject private var playerStore = GenericPlayerManagerStore<RecordedVideo>()
    @State private var showingPreview = false
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack {
            ZStack {
                Color.black
                CameraPreviewView(controller: cameraController, cameraLayoutMode: cameraController.cameraLayoutMode)
                
                VStack {
                    if !cameraController.isRecording {
                        HStack {
                            Spacer()
                            
                            Button(action: {
                                withAnimation {
                                    cameraController.cameraLayoutMode = cameraController.cameraLayoutMode.next
                                }
                            }) {
                                Image(systemName: cameraController.cameraLayoutMode.icon)
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(Color("JellyPrimary").opacity(0.8))
                                    .clipShape(Circle())
                            }
                            .padding(.trailing, 20)
                            .padding(.top, 25)
                        }
                    }

                    Spacer()
                    
                    if cameraController.cameraLayoutMode == .frontOnly {
                        HStack {
                            Spacer()
                            
                            Button(action: {
                                cameraController.flipCameraInFrontOnlyMode()
                            }) {
                                Image(systemName: "camera.rotate")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                            }
                            .padding(.trailing, 20)
                        }
                        .padding(.bottom, 20)
                    }

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
                    
                    if cameraController.isRecording {
                        Button(action: {
                            cameraController.undoRecording()
                            isProcessingVideo = false
                        }) {
                            Text("Undo")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 120, height: 44)
                                .background(Color.red)
                                .cornerRadius(22)
                        }
                        .padding(.bottom, 20)
                    }
                }
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
        .fullScreenCover(isPresented: $showingPreview) {
            if let frontURL = cameraController.frontPreviewURL, let backURL = cameraController.backPreviewURL {
                VideoPlayerPreviewView(
                    frontURL: frontURL,
                    backURL: backURL,
                    onSave: {
                        if let mergedURL = cameraController.mergedVideoURL {
                            let fetchRequest: NSFetchRequest<RecordedVideo> = RecordedVideo.fetchRequest()
                            fetchRequest.predicate = NSPredicate(format: "mergedVideoURL == %@", mergedURL.absoluteString)
                            
                            if let video = try? context.fetch(fetchRequest).first {
                                video.saved = true
                                try? context.save()
                                
                                withAnimation {
                                    showingPreview = false
//                                    cameraController.resetPreviewState()
                                }
                                selectedTab = .library
                            }
                        } else {
                            cameraController.onVideoProcessed = { [weak cameraController] in
                                guard let controller = cameraController else { return }
                                if let mergedURL = controller.mergedVideoURL {
                                    let fetchRequest: NSFetchRequest<RecordedVideo> = RecordedVideo.fetchRequest()
                                    fetchRequest.predicate = NSPredicate(format: "mergedVideoURL == %@", mergedURL.absoluteString)
                                    
                                    if let video = try? context.fetch(fetchRequest).first {
                                        video.saved = true
                                        try? context.save()
                                        
                                        withAnimation {
                                            showingPreview = false
//                                            controller.resetPreviewState()
                                        }
                                        selectedTab = .library
                                    }
                                }
                                controller.onVideoProcessed = nil
                            }
                        }
                    },
                    onBack: {
                        showingPreview = false
                         cameraController.retakeVideo()
                    },
                    isSideBySide: cameraController.cameraLayoutMode == .sideBySide,
                    isFrontOnly: cameraController.cameraLayoutMode == .frontOnly,
                    cameraSwitchTimestamps: cameraController.cameraSwitchTimestamps,
                    initialCameraPosition: cameraController.initialCameraPosition
                )
            }
        }
        .animation(nil, value: showingPreview)
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
