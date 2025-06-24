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
    @Environment(\.scenePhase) private var scenePhase
    @State private var isLongPressing = false
    @State private var pressStartTime: Date?
    @State private var isHoldMode = false
    @State private var holdTimer: Timer?
    @State private var isProcessingRecordingAction = false

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
                    
                    ZStack {
                        Color.clear
                            .frame(width: 150, height: 120)
                            .contentShape(Rectangle())
                        
                        ZStack {
                            JellyfishShape()
                                .stroke(Color.white, lineWidth: 3)
                                .frame(width: 100, height: 80)
                            
                            JellyfishShape()
                                .trim(from: 0, to: progress)
                                .stroke(Color("JellyPrimary"), lineWidth: 3)
                                .frame(width: 100, height: 80)
                                .animation(.linear(duration: 0.1), value: progress)
                            
                            if !cameraController.isRecording && !isLongPressing {
                                JellyfishShape()
                                    .fill(Color("JellyPrimary").opacity(0.3))
                                    .frame(width: 100, height: 80)
                            }
                        }
                        .scaleEffect(cameraController.isRecording || isLongPressing ? 1.1 : 1.0)
                        .animation(.easeInOut(duration: 0.2), value: cameraController.isRecording || isLongPressing)
                    }
                    .padding(.bottom, 50)
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { _ in
                                if pressStartTime == nil && !isProcessingRecordingAction {
                                    pressStartTime = Date()
                                    isLongPressing = true
                                    
                                    holdTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: false) { _ in
                                        if !cameraController.isRecording && !isProcessingRecordingAction {
                                            isHoldMode = true
                                            isProcessingRecordingAction = true
                                            cameraController.startRecording(context: context)
                                            
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                                isProcessingRecordingAction = false
                                            }
                                        }
                                    }
                                }
                            }
                            .onEnded { _ in
                                let pressDuration = pressStartTime?.timeIntervalSinceNow ?? 0
                                let absoluteDuration = abs(pressDuration)
                                
                                holdTimer?.invalidate()
                                holdTimer = nil
                                
                                isLongPressing = false
                                pressStartTime = nil
                                
                                if isHoldMode {
                                    if cameraController.isRecording && !isProcessingRecordingAction {
                                        isProcessingRecordingAction = true
                                        isProcessingVideo = true
                                        cameraController.stopRecording()
                                        
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                            isProcessingRecordingAction = false
                                        }
                                    }
                                    isHoldMode = false
                                } else if absoluteDuration < 1.0 && !isProcessingRecordingAction {
                                    isProcessingRecordingAction = true
                                    if cameraController.isRecording {
                                        isProcessingVideo = true
                                        cameraController.stopRecording()
                                    } else {
                                        cameraController.startRecording(context: context)
                                    }
                                    
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                        isProcessingRecordingAction = false
                                    }
                                }
                            }
                    )
                }
            }
            .onChange(of: cameraController.isRecording) { _, isRecording in
                if isRecording {
                    progress = 0.0
                } else {
                    progress = 0.0
                    isLongPressing = false
                    isHoldMode = false
                    pressStartTime = nil
                    holdTimer?.invalidate()
                    holdTimer = nil
                    isProcessingRecordingAction = false
                }
            }
            .onChange(of: cameraController.secondsRemaining) { _, secondsRemaining in
                if cameraController.isRecording {
                    progress = CGFloat(15000 - secondsRemaining) / 15000.0
                    if secondsRemaining <= 0 {
                        isProcessingVideo = true
                        isLongPressing = false
                        isHoldMode = false
                        pressStartTime = nil
                        holdTimer?.invalidate()
                        holdTimer = nil
                        isProcessingRecordingAction = false
                    }
                }
            }
            .onChange(of: cameraController.mergedVideoURL) { _, url in
                if url != nil {
                    withAnimation {
                        appState.isShowingPreview = true
                    }
                }
            }
            .cornerRadius(16)
        }
        .safeAreaInset(edge: .top) { Spacer().frame(height: 0) }
        .safeAreaInset(edge: .leading) { Spacer().frame(width: 5) }
        .safeAreaInset(edge: .trailing) { Spacer().frame(width: 5) }
        .fullScreenCover(isPresented: $appState.isShowingPreview) {
            if let mergedURL = cameraController.mergedVideoURL {
                VideoPlayerPreviewView(
                    mergedVideoURL: mergedURL,
                    onSave: {
                        let fetchRequest: NSFetchRequest<RecordedVideo> = RecordedVideo.fetchRequest()
                        fetchRequest.predicate = NSPredicate(format: "mergedVideoURL == %@", mergedURL.absoluteString)
                        if let video = try? context.fetch(fetchRequest).first {
                            video.saved = true
                            try? context.save()
                            
                            Task {
                                do {
                                    try await cameraController.uploadVideoToFirebase(video: video, context: context)
                                } catch {
                                    print("Error uploading video to Firebase: \(error.localizedDescription)")
                                }
                            }
                            
                            withAnimation { appState.isShowingPreview = false }
                            selectedTab = .library
                        }
                    },
                    onBack: {
                        withAnimation { appState.isShowingPreview = false }
                        cameraController.clearMergedVideo()
                    }
                )
                .onAppear {
                    cameraController.pauseCamera()
                }
                .onDisappear {
                    cameraController.resumeCamera()
                }
            }
        }
        .animation(nil, value: appState.isShowingPreview)
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