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
    @State private var lastDragLocation: CGPoint = .zero
    @State private var isZooming = false
    @State private var initialZoomFactor: CGFloat = 1.0
    @State private var currentMagnification: CGFloat = 1.0
    @State private var pinchLocation: CGPoint = .zero

    var body: some View {
        mainContentView
            .safeAreaInset(edge: .top) { Spacer().frame(height: 0) }
            .safeAreaInset(edge: .leading) { Spacer().frame(width: 5) }
            .safeAreaInset(edge: .trailing) { Spacer().frame(width: 5) }
            .fullScreenCover(isPresented: $appState.isShowingPreview) {
                previewCover
            }
            .animation(nil, value: appState.isShowingPreview)
    }
    
    private var mainContentView: some View {
        VStack {
            ZStack {
                Color.black
                CameraPreviewView(controller: cameraController, cameraLayoutMode: cameraController.cameraLayoutMode)
                    .simultaneousGesture(
                        SimultaneousGesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { value in
                                    pinchLocation = value.location
                                },
                            MagnificationGesture()
                                .onChanged { value in
                                    handlePinchChanged(value)
                                }
                                .onEnded { value in
                                    handlePinchEnded(value)
                                }
                        )
                    )
                    .onTapGesture(count: 2) {
                        if cameraController.cameraLayoutMode == .frontOnly {
                            cameraController.flipCameraInFrontOnlyMode()
                        }
                    }
                
                VStack {
                    topControlsView
                    Spacer()
                    Spacer()
                    recordingButtonView
                }
            }
            .onChange(of: cameraController.isRecording) { _, isRecording in
                handleRecordingStateChange(isRecording)
            }
            .onChange(of: cameraController.secondsRemaining) { _, secondsRemaining in
                handleSecondsRemainingChange(secondsRemaining)
            }
            .onChange(of: cameraController.mergedVideoURL) { _, url in
                handleMergedVideoURLChange(url)
            }
            .cornerRadius(16)
        }
    }
    
    private var topControlsView: some View {
        HStack {
            Spacer()
            
            VStack(spacing: 10) {
                if !cameraController.isRecording {
                    layoutModeButton
                    flashButton
                }
                frontOnlyCameraButton
            }
            .padding(.top, 25)
            .padding(.horizontal, 12)
        }
    }
    
    private var layoutModeButton: some View {
        Button(action: {
            withAnimation {
                cameraController.cameraLayoutMode = cameraController.cameraLayoutMode.next
            }
        }) {
            Image(systemName: cameraController.cameraLayoutMode.icon)
                .font(.system(size: 30))
                .foregroundColor(.white)
        }
    }
    
    private var flashButton: some View {
        Group {
            if cameraController.isFlashAvailable {
                Button(action: {
                    cameraController.toggleFlash()
                }) {
                    Image(systemName: cameraController.isFlashOn ? "flashlight.off.fill" : "flashlight.slash")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                }
            }
        }
    }
    
    private var frontOnlyCameraButton: some View {
        Group {
            if cameraController.cameraLayoutMode == .frontOnly {
                Button(action: {
                    cameraController.flipCameraInFrontOnlyMode()
                }) {
                    Image(systemName: "camera.rotate")
                        .font(.system(size: 30))
                        .foregroundColor(.white)
                }
            }
        }
    }
    
    private var recordingButtonView: some View {
        ZStack {
            Color.clear
                .frame(width: 150, height: 120)
                .contentShape(Rectangle())
            
            jellyfishShapeView
        }
        .padding(.bottom, 50)
        .simultaneousGesture(recordingGesture)
    }
    
    private var jellyfishShapeView: some View {
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
    }
    
    private var recordingGesture: some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .global)
            .onChanged { value in
                handleDragChanged(value)
            }
            .onEnded { value in
                handleDragEnded(value)
            }
    }
    
    private var previewCover: some View {
        Group {
            if let mergedURL = cameraController.mergedVideoURL {
                VideoPlayerPreviewView(
                    mergedVideoURL: mergedURL,
                    onSave: {
                        handleVideoSave(mergedURL)
                    },
                    onBack: {
                        handleVideoBack()
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
    }
    
    private func handleDragChanged(_ value: DragGesture.Value) {
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
    
    private func handlePinchChanged(_ magnification: CGFloat) {
        if !isZooming {
            isZooming = true
            let targetCamera = getTargetCameraForPinch()
            initialZoomFactor = targetCamera == .front ? cameraController.frontZoomFactor : cameraController.backZoomFactor
        }
        
        currentMagnification = magnification
        let newZoomFactor = initialZoomFactor * magnification
        
        let targetCamera = getTargetCameraForPinch()
        cameraController.setZoomFactor(newZoomFactor, forCamera: targetCamera)
    }
    
    private func handlePinchEnded(_ magnification: CGFloat) {
        isZooming = false
        currentMagnification = 1.0
        
        let targetCamera = getTargetCameraForPinch()
        initialZoomFactor = targetCamera == .front ? cameraController.frontZoomFactor : cameraController.backZoomFactor
    }
    
    private func getTargetCameraForPinch() -> AVCaptureDevice.Position {
        if cameraController.cameraLayoutMode == .frontOnly {
            return cameraController.getCurrentActiveCameraPosition()
        } else if cameraController.cameraLayoutMode == .topBottom {
            let screenHeight = UIScreen.main.bounds.height
            return pinchLocation.y < screenHeight / 2 ? .front : .back
        } else { 
            let screenWidth = UIScreen.main.bounds.width
            return pinchLocation.x < screenWidth / 2 ? .front : .back
        }
    }
    
    private func handleDragEnded(_ value: DragGesture.Value) {
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
    
    private func handleRecordingStateChange(_ isRecording: Bool) {
        if isRecording {
            progress = 0.0
            
            if cameraController.isFlashOn && !(cameraController.cameraLayoutMode == .frontOnly && cameraController.getCurrentActiveCameraPosition() == .front) {
                cameraController.turnFlashOn()
            }
        } else {
            progress = 0.0
            isLongPressing = false
            isHoldMode = false
            pressStartTime = nil
            holdTimer?.invalidate()
            holdTimer = nil
            isProcessingRecordingAction = false
            
            cameraController.turnFlashOff()
        }
    }
    
    private func handleSecondsRemainingChange(_ secondsRemaining: Int) {
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
                
                cameraController.turnFlashOff()
            }
        }
    }
    
    private func handleMergedVideoURLChange(_ url: URL?) {
        if url != nil {
            withAnimation {
                appState.isShowingPreview = true
            }
        }
    }
    
    private func handleVideoSave(_ mergedURL: URL) {
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
    }
    
    private func handleVideoBack() {
        withAnimation { appState.isShowingPreview = false }
        cameraController.clearMergedVideo()
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