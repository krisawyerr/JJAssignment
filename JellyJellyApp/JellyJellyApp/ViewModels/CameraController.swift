//
//  CameraController.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/4/25.
//

import SwiftUI
import AVFoundation
import CoreData
import FirebaseStorage

class BlurVideoCompositor: NSObject, AVVideoCompositing {
    nonisolated var sourcePixelBufferAttributes: [String : Any]? {
        return [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
    }
    
    nonisolated var requiredPixelBufferAttributesForRenderContext: [String : Any] {
        return [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
    }
    
    private var context: CIContext?
    private var blurFilter: CIFilter?
    
    override init() {
        super.init()
        context = CIContext()
        blurFilter = CIFilter(name: "CIGaussianBlur")
        blurFilter?.setValue(5.0, forKey: kCIInputRadiusKey)
    }
    
    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {
        context = CIContext()
    }
    
    func startRequest(_ asyncVideoCompositionRequest: AVAsynchronousVideoCompositionRequest) {
        guard let sourcePixelBuffer = asyncVideoCompositionRequest.sourceFrame(byTrackID: kCMPersistentTrackID_Invalid) else {
            if let blackPixelBuffer = createBlackPixelBuffer(size: asyncVideoCompositionRequest.renderContext.size) {
                asyncVideoCompositionRequest.finish(withComposedVideoFrame: blackPixelBuffer)
            } else {
                if let originalPixelBuffer = asyncVideoCompositionRequest.sourceFrame(byTrackID: kCMPersistentTrackID_Invalid) {
                    asyncVideoCompositionRequest.finish(withComposedVideoFrame: originalPixelBuffer)
                }
            }
            return
        }
        
        let ciImage = CIImage(cvPixelBuffer: sourcePixelBuffer)
        blurFilter?.setValue(ciImage, forKey: kCIInputImageKey)
        
        guard let outputImage = blurFilter?.outputImage,
              let context = context,
              let outputPixelBuffer = asyncVideoCompositionRequest.renderContext.newPixelBuffer() else {
            asyncVideoCompositionRequest.finish(withComposedVideoFrame: sourcePixelBuffer)
            return
        }
        
        context.render(outputImage, to: outputPixelBuffer)
        asyncVideoCompositionRequest.finish(withComposedVideoFrame: outputPixelBuffer)
    }
    
    private func createBlackPixelBuffer(size: CGSize) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs = [kCVPixelBufferCGImageCompatibilityKey: kCFBooleanTrue,
                    kCVPixelBufferCGBitmapContextCompatibilityKey: kCFBooleanTrue] as CFDictionary
        
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                       Int(size.width),
                                       Int(size.height),
                                       kCVPixelFormatType_32BGRA,
                                       attrs,
                                       &pixelBuffer)
        
        guard status == kCVReturnSuccess, let pixelBuffer = pixelBuffer else {
            return nil
        }
        
        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        
        let context = CGContext(data: CVPixelBufferGetBaseAddress(pixelBuffer),
                              width: Int(size.width),
                              height: Int(size.height),
                              bitsPerComponent: 8,
                              bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                              space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue)
        
        context?.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        context?.fill(CGRect(x: 0, y: 0, width: size.width, height: size.height))
        
        return pixelBuffer
    }
}

class CameraController: NSObject, ObservableObject {
    let session = AVCaptureMultiCamSession()
    private let frontOutput = AVCaptureMovieFileOutput()
    private let backOutput = AVCaptureMovieFileOutput()
    private let storage = Storage.storage()
    private let sessionQueue = DispatchQueue(label: "CameraSessionQueue")
    
    private weak var previewView: CameraPreviewUIView?
    private var frontURL: URL?
    private var backURL: URL?
    @Published var mergedVideoURL: URL?
    @Published var isRecording = false
    @Published var secondsRemaining = 15000
    @Published var isPreviewReady = false
    @Published var immediatePreviewURL: URL?
    @Published var frontPreviewURL: URL?
    @Published var backPreviewURL: URL?
    @Published var frontZoomFactor: CGFloat = 1.0
    @Published var backZoomFactor: CGFloat = 1.0
    @Published var isPaused = false
    
    enum CameraLayoutMode: CaseIterable {
        case topBottom
        case sideBySide
        case frontOnly
        
        var icon: String {
            switch self {
            case .topBottom:
                return "rectangle.split.1x2"
            case .sideBySide:
                return "rectangle.split.2x1"
            case .frontOnly:
                return "camera"
            }
        }
        
        var next: CameraLayoutMode {
            switch self {
            case .topBottom:
                return .sideBySide
            case .sideBySide:
                return .frontOnly
            case .frontOnly:
                return .topBottom
            }
        }
    }
    
    @Published var cameraLayoutMode: CameraLayoutMode = .topBottom
    
    private var frontCamera: AVCaptureDevice?
    private var backCamera: AVCaptureDevice?
    private var frontInput: AVCaptureDeviceInput?
    private var backInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private var isSessionSetup = false
    private var frontInitialZoom: CGFloat = 1.0
    private var backInitialZoom: CGFloat = 1.0
    
    private var recordingTimer: Timer?
    private let maxRecordingTime = 15000
    
    private var recordingCompletionCount = 0
    private var storedContext: NSManagedObjectContext?
    private var processingStartTime: CFAbsoluteTime = 0
    private var lastRecordedVideo: RecordedVideo?
    var cameraSwitchTimestamps: [CFAbsoluteTime] = []
    private var recordingStartTime: CFAbsoluteTime = 0
    var initialCameraPosition: AVCaptureDevice.Position = .front
    
    var onVideoProcessed: (() -> Void)?
    
    func setPreviewView(_ view: CameraPreviewUIView) {
        self.previewView = view
        setupCamera()
    }
    
    func resetPreviewState() {
        frontURL = nil
        backURL = nil
        mergedVideoURL = nil
        frontPreviewURL = nil
        backPreviewURL = nil
        immediatePreviewURL = nil
        
        isRecording = false
        secondsRemaining = maxRecordingTime
        recordingCompletionCount = 0

        if session.isRunning, let previewView = previewView {
            DispatchQueue.main.async {
                previewView.setupPreviewLayers(with: self.session)
                self.isPreviewReady = true
            }
        }
    }
    
    func retakeVideo() {
        let frontURLToDelete = frontURL
        let backURLToDelete = backURL
        let mergedURLToDelete = mergedVideoURL
        let contextToUse = storedContext
        
        frontURL = nil
        backURL = nil
        mergedVideoURL = nil
        frontPreviewURL = nil
        backPreviewURL = nil
        immediatePreviewURL = nil
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            if let context = contextToUse {
                let fetchRequest: NSFetchRequest<RecordedVideo> = RecordedVideo.fetchRequest()
                
                if let mergedURL = mergedURLToDelete {
                    let videoURL = mergedURL.absoluteString
                    fetchRequest.predicate = NSPredicate(format: "mergedVideoURL == %@", videoURL)
                } else {
                    fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \RecordedVideo.createdAt, ascending: false)]
                    fetchRequest.fetchLimit = 1
                }
                
                if let video = try? context.fetch(fetchRequest).first {
                    self.lastRecordedVideo = video
                    
                    Task {
                        do {
                            try await self.deleteVideoFromFirebase(video: video)
                        } catch {
                            print("Error deleting video from Firebase: \(error.localizedDescription)")
                        }
                    }
                    
                    context.delete(video)
                    try? context.save()
                }
            }
            
            if let frontURL = frontURLToDelete {
                try? FileManager.default.removeItem(at: frontURL)
            }
            if let backURL = backURLToDelete {
                try? FileManager.default.removeItem(at: backURL)
            }
            if let mergedURL = mergedURLToDelete {
                try? FileManager.default.removeItem(at: mergedURL)
            }
        }
    }
    
    func undoRecording() {
        if isRecording {
            frontOutput.stopRecording()
            backOutput.stopRecording()
            isRecording = false
        }
        
        if let frontURL = frontURL {
            try? FileManager.default.removeItem(at: frontURL)
        }
        if let backURL = backURL {
            try? FileManager.default.removeItem(at: backURL)
        }
        
        frontURL = nil
        backURL = nil
        frontPreviewURL = nil
        backPreviewURL = nil
        
        secondsRemaining = maxRecordingTime
        recordingCompletionCount = 0
        
        stopTimer()
    }
    
    func setupCamera() {
        sessionQueue.async { [weak self] in
            guard let self = self else { return }
            if self.previewView == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    self.setupCamera()
                }
                return
            }
            if self.isSessionSetup && self.session.isRunning { return }
            self.resetSession()
            guard AVCaptureMultiCamSession.isMultiCamSupported else {
                print("MultiCam not supported")
                return
            }
            self.session.beginConfiguration()
            do {
                if let front = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
                    let frontDeviceInput = try AVCaptureDeviceInput(device: front)
                    self.frontCamera = front
                    self.frontInput = frontDeviceInput
                    if self.session.canAddInput(frontDeviceInput) {
                        self.session.addInput(frontDeviceInput)
                    } else {
                        print("Cannot add front camera input")
                    }
                    for connection in self.frontOutput.connections {
                        self.session.removeConnection(connection)
                    }
                    if self.session.canAddOutput(self.frontOutput) {
                        self.session.addOutput(self.frontOutput)
                    } else {
                        print("Cannot add front output")
                    }
                }
                if let back = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                    let backDeviceInput = try AVCaptureDeviceInput(device: back)
                    self.backCamera = back
                    self.backInput = backDeviceInput
                    if self.session.canAddInput(backDeviceInput) {
                        self.session.addInput(backDeviceInput)
                    } else {
                        print("Cannot add back camera input")
                    }
                    for connection in self.backOutput.connections {
                        self.session.removeConnection(connection)
                    }
                    if self.session.canAddOutput(self.backOutput) {
                        self.session.addOutput(self.backOutput)
                    } else {
                        print("Cannot add back output")
                    }
                }
                if let microphone = AVCaptureDevice.default(for: .audio) {
                    let micInput = try AVCaptureDeviceInput(device: microphone)
                    self.audioInput = micInput
                    if self.session.canAddInput(micInput) {
                        self.session.addInput(micInput)
                    } else {
                        print("Cannot add mic input")
                    }
                }
            } catch {
                print(error)
            }
            self.session.commitConfiguration()
            self.isSessionSetup = true
            if !self.session.isRunning {
                self.session.startRunning()
            }
            DispatchQueue.main.async {
                self.previewView?.setupPreviewLayers(with: self.session)
                self.isPreviewReady = true
            }
        }
    }
    
    private func resetSession() {
        if !Thread.isMainThread {
            DispatchQueue.main.sync { self.resetSession() }
            return
        }
        
        stopTimer()
        isPreviewReady = false
        
        if isRecording {
            frontOutput.stopRecording()
            backOutput.stopRecording()
            isRecording = false
        }
        
        recordingCompletionCount = 0
        
        previewView?.cleanupPreviewLayers()
        
        session.beginConfiguration()
        
        session.inputs.forEach { input in
            session.removeInput(input)
        }
        
        session.outputs.forEach { output in
            session.removeOutput(output)
        }
        
        session.commitConfiguration()
        
        isSessionSetup = false
        secondsRemaining = maxRecordingTime
    }
    
    func stopCamera() {
        previewView?.cleanupPreviewLayers()
        
        stopTimer()
        
        if isRecording {
            frontOutput.stopRecording()
            backOutput.stopRecording()
            isRecording = false
        }
        
        if session.isRunning {
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else { return }
                do {
                    self.session.beginConfiguration()
                    self.session.commitConfiguration()
                    self.session.stopRunning()
                } catch {
                    print("Error stopping camera session: \(error.localizedDescription)")
                }
            }
        }
    }
    
    func pauseCamera() {
        guard session.isRunning && !isPaused else { return }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            self.session.stopRunning()
            
            DispatchQueue.main.async {
                self.isPaused = true
                print("Camera paused")
            }
        }
    }
    
    func resumeCamera() {
        guard !session.isRunning && isPaused else { return }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }
            
            self.session.startRunning()
            
            DispatchQueue.main.async {
                self.isPaused = false
                print("Camera resumed")
            }
        }
    }
    
    func startRecording(context: NSManagedObjectContext) {
        guard !isRecording else { 
            return 
        }
        
        storedContext = context
        
        recordingCompletionCount = 0
        secondsRemaining = maxRecordingTime
        cameraSwitchTimestamps.removeAll()
        recordingStartTime = CFAbsoluteTimeGetCurrent()
        
        if cameraLayoutMode == .frontOnly {
            initialCameraPosition = previewView?.activeCameraInFrontOnlyMode ?? .front
        } else {
            initialCameraPosition = .front 
        }
        
        let timestamp = Date().timeIntervalSince1970
        let tempDir = FileManager.default.temporaryDirectory
        
        frontURL = tempDir.appendingPathComponent("front_\(timestamp).mov")
        backURL = tempDir.appendingPathComponent("back_\(timestamp).mov")
        
        DispatchQueue.main.async {
            self.isRecording = true
        }
        
        startTimer()
        
        if let frontURL = frontURL {
            frontOutput.startRecording(to: frontURL, recordingDelegate: self)
        }
        
        if let backURL = backURL {
            backOutput.startRecording(to: backURL, recordingDelegate: self)
        }
    }
    
    func stopRecording() {
        guard isRecording else { 
            return 
        }
        
        stopTimer()
        
        frontOutput.stopRecording()
        backOutput.stopRecording()
        
        DispatchQueue.main.async {
            self.isRecording = false
        }
    }
    
    private func startTimer() {
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.01, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                self.secondsRemaining -= 10
                
                if self.secondsRemaining <= 0 {
                    self.stopRecording()
                }
            }
        }
    }
    
    private func stopTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    
    private func processVideos(context: NSManagedObjectContext) {
        guard let frontURL = self.frontURL,
              let backURL = self.backURL else {
            return
        }
        
        guard FileManager.default.fileExists(atPath: frontURL.path),
              FileManager.default.fileExists(atPath: backURL.path) else {
            print("Video files do not exist")
            return
        }
        
        let tempDir = FileManager.default.temporaryDirectory
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let croppedFrontURL = tempDir.appendingPathComponent("cropped_front_\(Date().timeIntervalSince1970).mp4")
        let croppedBackURL = tempDir.appendingPathComponent("cropped_back_\(Date().timeIntervalSince1970).mp4")
        let mergedOutputURL = tempDir.appendingPathComponent("merged_\(Date().timeIntervalSince1970).mp4")
        let finalMergedWithAudioURL = docsDir.appendingPathComponent("merged_with_audio_\(Date().timeIntervalSince1970).mp4")
        
        Task {
            do {
                let newRecording = RecordedVideo(context: context)
                newRecording.createdAt = Date()
                newRecording.frontVideoURL = frontURL.absoluteString
                newRecording.backVideoURL = backURL.absoluteString
                try context.save()
                
                try await self.cropToMiddleThird(inputURL: frontURL, outputURL: croppedFrontURL)
                try await self.cropToMiddleThird(inputURL: backURL, outputURL: croppedBackURL)
                
                try await self.mergeVideosTopBottom(videoURL1: croppedFrontURL, videoURL2: croppedBackURL, outputURL: mergedOutputURL)
                
                try? FileManager.default.removeItem(at: croppedFrontURL)
                try? FileManager.default.removeItem(at: croppedBackURL)
                
                newRecording.mergedVideoURL = mergedOutputURL.absoluteString
                try context.save()
                
                try await self.mergeVideosWithAudio(frontVideoURL: mergedOutputURL, frontAudioURL: frontURL, outputURL: finalMergedWithAudioURL)
                
                newRecording.mergedVideoURL = finalMergedWithAudioURL.absoluteString
                try context.save()
                
                try? FileManager.default.removeItem(at: frontURL)
                try? FileManager.default.removeItem(at: backURL)
                try? FileManager.default.removeItem(at: mergedOutputURL)
                
                let endTime = CFAbsoluteTimeGetCurrent()
                let totalProcessingTime = (endTime - self.processingStartTime) * 1000
                print("Total processing time: \(String(format: "%.1f", totalProcessingTime))ms")
                
                await MainActor.run {
                    self.mergedVideoURL = finalMergedWithAudioURL
                    self.onVideoProcessed?()
                }
                
                try await self.uploadVideoToFirebase(video: newRecording, context: context)
                
            } catch {
                print("Video processing failed: \(error.localizedDescription)")
                try? FileManager.default.removeItem(at: croppedFrontURL)
                try? FileManager.default.removeItem(at: croppedBackURL)
                try? FileManager.default.removeItem(at: mergedOutputURL)
                try? FileManager.default.removeItem(at: finalMergedWithAudioURL)
            }
        }
    }
    
    func cropToMiddleThird(inputURL: URL, outputURL: URL) async throws {
        let asset = AVURLAsset(url: inputURL)
        
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = tracks.first else {
            throw NSError(domain: "No video track found", code: -1)
        }
        
        let composition = AVMutableComposition()
        guard let compositionTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw NSError(domain: "Track creation failed", code: -2)
        }
        
        let duration = try await asset.load(.duration)
        try compositionTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: duration),
            of: videoTrack,
            at: .zero
        )
        
        let naturalSize = try await videoTrack.load(.naturalSize)
        let cropWidth = naturalSize.width / 2
        let cropX = naturalSize.width / 4
        let transform = CGAffineTransform(translationX: -cropX, y: 0)
        
        let transformer = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionTrack)
        transformer.setTransform(transform, at: .zero)
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: duration)
        instruction.layerInstructions = [transformer]
        
        let videoComposition = AVMutableVideoComposition()
        videoComposition.instructions = [instruction]
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.renderSize = CGSize(width: cropWidth, height: naturalSize.height)
        
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPreset640x480) else {
            throw NSError(domain: "Export session failed", code: -3)
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = videoComposition
        exportSession.shouldOptimizeForNetworkUse = true
        
        try await exportSession.export(to: outputURL, as: .mp4)
    }
    
    func mergeVideosTopBottom(videoURL1: URL, videoURL2: URL, outputURL: URL) async throws {
        let asset1 = AVURLAsset(url: videoURL1)
        let asset2 = AVURLAsset(url: videoURL2)
        
        let composition = AVMutableComposition()
        guard let track1 = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let track2 = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw NSError(domain: "MergeError", code: -1)
        }
        
        let tracks1 = try await asset1.loadTracks(withMediaType: .video)
        let tracks2 = try await asset2.loadTracks(withMediaType: .video)
        
        guard let assetTrack1 = tracks1.first,
              let assetTrack2 = tracks2.first else {
            throw NSError(domain: "MergeError", code: -1)
        }
        
        let duration1 = try await asset1.load(.duration)
        let duration2 = try await asset2.load(.duration)
        let timeRange = CMTimeRange(start: .zero, duration: min(duration1, duration2))
        
        try track1.insertTimeRange(timeRange, of: assetTrack1, at: .zero)
        try track2.insertTimeRange(timeRange, of: assetTrack2, at: .zero)
        
        let naturalSize = try await assetTrack1.load(.naturalSize)
        let finalSize = CGSize(width: naturalSize.height, height: naturalSize.width * 2)
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = timeRange
        
        let videoWidth = naturalSize.width
        let videoHeight = naturalSize.height
        
        let rotation = CGAffineTransform(rotationAngle: .pi / 2)
        let move1 = CGAffineTransform(translationX: videoHeight, y: 0)
        let move2 = CGAffineTransform(translationX: videoHeight, y: videoWidth)
        let flip = CGAffineTransform(scaleX: -1, y: 1).translatedBy(x: -videoHeight, y: 0)
        
        let transform1 = rotation.concatenating(move1).concatenating(flip)
        let transform2 = rotation.concatenating(move2)
        
        let layerInstruction1 = AVMutableVideoCompositionLayerInstruction(assetTrack: track1)
        layerInstruction1.setTransform(transform1, at: .zero)
        
        let layerInstruction2 = AVMutableVideoCompositionLayerInstruction(assetTrack: track2)
        layerInstruction2.setTransform(transform2, at: .zero)
        
        instruction.layerInstructions = [layerInstruction1, layerInstruction2]
        
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = finalSize
        videoComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
        videoComposition.instructions = [instruction]
        
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPreset640x480) else {
            throw NSError(domain: "ExportError", code: -2)
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = videoComposition
        exportSession.shouldOptimizeForNetworkUse = true
        
        do {
            try await exportSession.export(to: outputURL, as: .mp4)
        } catch {
            throw error
        }
    }
    
    func mergeVideosWithAudio(frontVideoURL: URL, frontAudioURL: URL, outputURL: URL) async throws {
        let mixComposition = AVMutableComposition()
        
        let videoAsset = AVURLAsset(url: frontVideoURL)
        let audioAsset = AVURLAsset(url: frontAudioURL)
        
        let videoTracks = try await videoAsset.loadTracks(withMediaType: .video)
        let audioTracks = try await audioAsset.loadTracks(withMediaType: .audio)
        
        guard let videoTrack = videoTracks.first,
              let audioTrack = audioTracks.first else {
            throw NSError(domain: "MergeError", code: -1)
        }
        
        let videoCompTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        let audioCompTrack = mixComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        
        let videoDuration = try await videoAsset.load(.duration)
        try videoCompTrack?.insertTimeRange(CMTimeRange(start: .zero, duration: videoDuration), of: videoTrack, at: .zero)
        try audioCompTrack?.insertTimeRange(CMTimeRange(start: .zero, duration: videoDuration), of: audioTrack, at: .zero)
        
        guard let exportSession = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPreset640x480) else {
            throw NSError(domain: "ExportError", code: -2)
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        do {
            try await exportSession.export(to: outputURL, as: .mp4)
        } catch {
            throw error
        }
    }
    
    func setZoomFactor(_ factor: CGFloat, forCamera position: AVCaptureDevice.Position) {
        guard let device = position == .front ? frontCamera : backCamera else { return }
        
        do {
            try device.lockForConfiguration()
            let maxZoom = device.activeFormat.videoMaxZoomFactor
            let clampedFactor = min(max(factor, 1.0), maxZoom)
            
            if position == .front {
                frontZoomFactor = clampedFactor
                device.videoZoomFactor = clampedFactor
            } else {
                backZoomFactor = clampedFactor
                device.videoZoomFactor = clampedFactor
            }
            
            device.unlockForConfiguration()
        } catch {
            print("Error setting zoom factor: \(error.localizedDescription)")
        }
    }
    
    func uploadVideoToFirebase(video: RecordedVideo, context: NSManagedObjectContext) async throws {
        guard let mergedVideoURL = video.mergedVideoURL,
              let videoURL = URL(string: mergedVideoURL) else {
            throw NSError(domain: "VideoError", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid video URL"])
        }
        
        let timestamp = Date().timeIntervalSince1970
        let storageRef = storage.reference().child("videos/\(timestamp).mp4")
        
        let metadata = StorageMetadata()
        metadata.contentType = "video/mp4"
        
        _ = try await storageRef.putFileAsync(from: videoURL, metadata: metadata)
        let downloadURL = try await storageRef.downloadURL()
        
        await MainActor.run {
            video.firebaseStorageURL = downloadURL.absoluteString
            try? context.save()
        }
    }
    
    func deleteVideoFromFirebase(video: RecordedVideo) async throws {
        guard let firebaseURL = video.firebaseStorageURL else {
            return
        }
        
        let storageRef = storage.reference(forURL: firebaseURL)
        try await storageRef.delete()
    }
    
    private func processVideosSideBySide(context: NSManagedObjectContext) {
        guard let frontURL = self.frontURL,
              let backURL = self.backURL else {
            return
        }

        guard FileManager.default.fileExists(atPath: frontURL.path),
              FileManager.default.fileExists(atPath: backURL.path) else {
            print("Video files do not exist")
            return
        }

        let tempDir = FileManager.default.temporaryDirectory
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let rotatedFrontURL = tempDir.appendingPathComponent("rotated_front_\(Date().timeIntervalSince1970).mp4")
        let rotatedBackURL = tempDir.appendingPathComponent("rotated_back_\(Date().timeIntervalSince1970).mp4")
        let mergedOutputURL = tempDir.appendingPathComponent("merged_sidebyside_\(Date().timeIntervalSince1970).mp4")
        let finalMergedWithAudioURL = docsDir.appendingPathComponent("merged_sidebyside_with_audio_\(Date().timeIntervalSince1970).mp4")

        Task {
            do {
                let newRecording = RecordedVideo(context: context)
                newRecording.createdAt = Date()
                newRecording.frontVideoURL = frontURL.absoluteString
                newRecording.backVideoURL = backURL.absoluteString
                newRecording.isSideBySide = true
                try context.save()

                try await self.rotateVideo(inputURL: frontURL, outputURL: rotatedFrontURL)
                try await self.rotateVideo(inputURL: backURL, outputURL: rotatedBackURL)
                
                try await self.mergeVideosSideBySide(frontVideoURL: rotatedFrontURL, backVideoURL: rotatedBackURL, outputURL: mergedOutputURL)
                
                try? FileManager.default.removeItem(at: rotatedFrontURL)
                try? FileManager.default.removeItem(at: rotatedBackURL)
                
                newRecording.mergedVideoURL = mergedOutputURL.absoluteString
                try context.save()
                
                try await self.mergeVideosWithAudio(frontVideoURL: mergedOutputURL, frontAudioURL: frontURL, outputURL: finalMergedWithAudioURL)
                
                newRecording.mergedVideoURL = finalMergedWithAudioURL.absoluteString
                try context.save()
                
                try? FileManager.default.removeItem(at: frontURL)
                try? FileManager.default.removeItem(at: backURL)
                try? FileManager.default.removeItem(at: mergedOutputURL)
                
                let endTime = CFAbsoluteTimeGetCurrent()
                let totalProcessingTime = (endTime - self.processingStartTime) * 1000
                print("Total side-by-side processing time: \(String(format: "%.1f", totalProcessingTime))ms")
                
                await MainActor.run {
                    self.mergedVideoURL = finalMergedWithAudioURL
                    self.onVideoProcessed?()
                }
                
                try await self.uploadVideoToFirebase(video: newRecording, context: context)
                
            } catch {
                print("Side-by-side video processing failed: \(error.localizedDescription)")
                try? FileManager.default.removeItem(at: rotatedFrontURL)
                try? FileManager.default.removeItem(at: rotatedBackURL)
                try? FileManager.default.removeItem(at: mergedOutputURL)
                try? FileManager.default.removeItem(at: finalMergedWithAudioURL)
            }
        }
    }

    func rotateVideo(inputURL: URL, outputURL: URL) async throws {
        let asset = AVURLAsset(url: inputURL)
        
        let tracks = try await asset.loadTracks(withMediaType: .video)
        guard let videoTrack = tracks.first else {
            throw NSError(domain: "No video track found", code: -1)
        }
        
        let composition = AVMutableComposition()
        guard let compositionTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw NSError(domain: "Track creation failed", code: -2)
        }
        
        let duration = try await asset.load(.duration)
        try compositionTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: duration),
            of: videoTrack,
            at: .zero
        )
        
        let naturalSize = try await videoTrack.load(.naturalSize)
        
        let rotation = CGAffineTransform(rotationAngle: .pi / 2)
        let translation = CGAffineTransform(translationX: naturalSize.height, y: 0)
        let transform = rotation.concatenating(translation)
        
        let transformer = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionTrack)
        transformer.setTransform(transform, at: .zero)
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRange(start: .zero, duration: duration)
        instruction.layerInstructions = [transformer]
        
        let videoComposition = AVMutableVideoComposition()
        videoComposition.instructions = [instruction]
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        videoComposition.renderSize = CGSize(width: naturalSize.height, height: naturalSize.width)
        
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPreset640x480) else {
            throw NSError(domain: "Export session failed", code: -3)
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = videoComposition
        exportSession.shouldOptimizeForNetworkUse = true
        
        try await exportSession.export(to: outputURL, as: .mp4)
    }

    func mergeVideosSideBySide(frontVideoURL: URL, backVideoURL: URL, outputURL: URL) async throws {
        let frontAsset = AVURLAsset(url: frontVideoURL)
        let backAsset = AVURLAsset(url: backVideoURL)
        
        let composition = AVMutableComposition()
        guard let frontTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let backTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw NSError(domain: "MergeError", code: -1)
        }
        
        let frontTracks = try await frontAsset.loadTracks(withMediaType: .video)
        let backTracks = try await backAsset.loadTracks(withMediaType: .video)
        
        guard let frontAssetTrack = frontTracks.first,
              let backAssetTrack = backTracks.first else {
            throw NSError(domain: "MergeError", code: -1)
        }
        
        let frontDuration = try await frontAsset.load(.duration)
        let backDuration = try await backAsset.load(.duration)
        let timeRange = CMTimeRange(start: .zero, duration: min(frontDuration, backDuration))
        
        try frontTrack.insertTimeRange(timeRange, of: frontAssetTrack, at: .zero)
        try backTrack.insertTimeRange(timeRange, of: backAssetTrack, at: .zero)
        
        let frontSize = try await frontAssetTrack.load(.naturalSize)
        let backSize = try await backAssetTrack.load(.naturalSize)
        
        let finalSize = CGSize(width: frontSize.width + backSize.width, height: max(frontSize.height, backSize.height))
        
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = timeRange
        
        let frontLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: frontTrack)
        let flip = CGAffineTransform(scaleX: -1, y: 1).translatedBy(x: -frontSize.width, y: 0)
        frontLayerInstruction.setTransform(flip, at: .zero)
        
        let backLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: backTrack)
        let backTransform = CGAffineTransform(translationX: frontSize.width, y: 0)
        backLayerInstruction.setTransform(backTransform, at: .zero)
        
        instruction.layerInstructions = [frontLayerInstruction, backLayerInstruction]
        
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = finalSize
        videoComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
        videoComposition.instructions = [instruction]
        
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPreset640x480) else {
            throw NSError(domain: "ExportError", code: -2)
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = videoComposition
        exportSession.shouldOptimizeForNetworkUse = true
        
        try await exportSession.export(to: outputURL, as: .mp4)
    }

    private func processFrontOnlyVideo(context: NSManagedObjectContext) {
        guard let frontURL = self.frontURL,
              let backURL = self.backURL else {
            return
        }
        
        guard FileManager.default.fileExists(atPath: frontURL.path),
              FileManager.default.fileExists(atPath: backURL.path) else {
            print("Video files do not exist")
            return
        }
        
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let finalOutputURL = docsDir.appendingPathComponent("front_only_with_flips_\(Date().timeIntervalSince1970).mp4")
        
        Task {
            do {
                let newRecording = RecordedVideo(context: context)
                newRecording.createdAt = Date()
                newRecording.frontVideoURL = frontURL.absoluteString
                newRecording.backVideoURL = backURL.absoluteString
                newRecording.isFrontOnly = true
                try context.save()
                
                try await self.createFrontOnlyVideoWithFlips(frontVideoURL: frontURL, backVideoURL: backURL, outputURL: finalOutputURL)
                
                newRecording.mergedVideoURL = finalOutputURL.absoluteString
                try context.save()
                
                try? FileManager.default.removeItem(at: frontURL)
                try? FileManager.default.removeItem(at: backURL)
                
                let endTime = CFAbsoluteTimeGetCurrent()
                let totalProcessingTime = (endTime - self.processingStartTime) * 1000
                print("Total front-only processing time: \(String(format: "%.1f", totalProcessingTime))ms")
                
                await MainActor.run {
                    self.mergedVideoURL = finalOutputURL
                    self.onVideoProcessed?()
                }
                
                try await self.uploadVideoToFirebase(video: newRecording, context: context)
                
            } catch {
                print("Front-only video processing failed: \(error.localizedDescription)")
                try? FileManager.default.removeItem(at: finalOutputURL)
            }
        }
    }
    
    private func createFrontOnlyVideoWithFlips(frontVideoURL: URL, backVideoURL: URL, outputURL: URL) async throws {
        let frontAsset = AVURLAsset(url: frontVideoURL)
        let backAsset = AVURLAsset(url: backVideoURL)
        
        let composition = AVMutableComposition()
        guard let frontTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let backTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw NSError(domain: "CompositionError", code: -1)
        }
        
        let frontTracks = try await frontAsset.loadTracks(withMediaType: .video)
        let backTracks = try await backAsset.loadTracks(withMediaType: .video)
        
        guard let frontAssetTrack = frontTracks.first,
              let backAssetTrack = backTracks.first else {
            throw NSError(domain: "TrackError", code: -1)
        }
        
        let frontDuration = try await frontAsset.load(.duration)
        let backDuration = try await backAsset.load(.duration)
        let totalDuration = min(frontDuration, backDuration)
        
        var switchTimes: [CMTime] = []
        
        if !cameraSwitchTimestamps.isEmpty {
            for timestamp in cameraSwitchTimestamps {
                let cmTime = CMTime(seconds: timestamp, preferredTimescale: 600)
                if cmTime < totalDuration {
                    switchTimes.append(cmTime)
                }
            }
        }
        
        var allTimes: [CMTime] = [.zero]
        allTimes.append(contentsOf: switchTimes)
        allTimes.append(totalDuration)
        
        try frontTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: totalDuration),
            of: frontAssetTrack,
            at: .zero
        )
        
        try backTrack.insertTimeRange(
            CMTimeRange(start: .zero, duration: totalDuration),
            of: backAssetTrack,
            at: .zero
        )
        
        let audioTracks = try await frontAsset.loadTracks(withMediaType: .audio)
        if let audioTrack = audioTracks.first {
            let audioCompTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            try audioCompTrack?.insertTimeRange(
                CMTimeRange(start: .zero, duration: totalDuration),
                of: audioTrack,
                at: .zero
            )
        }
        
        let videoComposition = AVMutableVideoComposition()
        let naturalSize = try await frontAssetTrack.load(.naturalSize)
        videoComposition.renderSize = CGSize(width: naturalSize.height, height: naturalSize.width)
        videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
        
        var instructions: [AVMutableVideoCompositionInstruction] = []
        
        for i in 0..<(allTimes.count - 1) {
            let startTime = allTimes[i]
            let endTime = allTimes[i + 1]
            let segmentDuration = endTime - startTime
            
            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRange(start: startTime, duration: segmentDuration)
            
            let frontLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: frontTrack)
            let backLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: backTrack)
            
            let rotation = CGAffineTransform(rotationAngle: .pi / 2)
            let translation = CGAffineTransform(translationX: naturalSize.height, y: 0)
            let transform = rotation.concatenating(translation)
            
            frontLayerInstruction.setTransform(transform, at: startTime)
            backLayerInstruction.setTransform(transform, at: startTime)
            
            let isFrontSegment: Bool
            if initialCameraPosition == .front {
                isFrontSegment = i % 2 == 0
            } else {
                isFrontSegment = i % 2 == 1
            }
            
            if isFrontSegment {
                let flip = CGAffineTransform(scaleX: -1, y: 1).translatedBy(x: -naturalSize.height, y: 0)
                let frontTransformWithFlip = transform.concatenating(flip)
                frontLayerInstruction.setTransform(frontTransformWithFlip, at: startTime)
                frontLayerInstruction.setOpacity(1.0, at: startTime)
                backLayerInstruction.setOpacity(0.0, at: startTime)
            } else {
                frontLayerInstruction.setOpacity(0.0, at: startTime)
                backLayerInstruction.setOpacity(1.0, at: startTime)
            }
            
            instruction.layerInstructions = [frontLayerInstruction, backLayerInstruction]
            instructions.append(instruction)
        }
        
        videoComposition.instructions = instructions
        
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPreset640x480) else {
            throw NSError(domain: "ExportError", code: -2)
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = videoComposition
        exportSession.shouldOptimizeForNetworkUse = true
        
        try await exportSession.export(to: outputURL, as: .mp4)
    }
    
    func recordCameraSwitch() {
        if isRecording {
            let switchTime = CFAbsoluteTimeGetCurrent() - recordingStartTime
            cameraSwitchTimestamps.append(switchTime)
            print("Camera switch recorded at: \(switchTime)s")
        }
    }
    
    func flipCameraInFrontOnlyMode() {
        previewView?.flipCameraInFrontOnlyMode()
    }
}

extension CameraController: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection], error: Error?) {

        recordingCompletionCount += 1

        if let error = error {
            print("Recording error: \(error.localizedDescription)")
        } 

        if recordingCompletionCount >= 2 {
            DispatchQueue.main.async {
                if let frontURL = self.frontURL, let backURL = self.backURL {
                    self.frontPreviewURL = frontURL
                    self.backPreviewURL = backURL
                }
                
                if let context = self.storedContext {
                    self.processingStartTime = CFAbsoluteTimeGetCurrent()
                    print("Starting video processing at: \(self.processingStartTime)")
                    Task {
                        switch self.cameraLayoutMode {
                        case .topBottom:
                            self.processVideos(context: context)
                        case .sideBySide:
                            self.processVideosSideBySide(context: context)
                        case .frontOnly:
                            self.processFrontOnlyVideo(context: context)
                        }
                    }
                } else {
                    print("No context available for video processing")
                }
            }
        }
    }
}
