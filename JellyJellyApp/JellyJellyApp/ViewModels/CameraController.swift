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
    var sourcePixelBufferAttributes: [String : Any]? {
        return [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
    }
    
    var requiredPixelBufferAttributesForRenderContext: [String : Any] {
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
    private let session = AVCaptureMultiCamSession()
    private let frontOutput = AVCaptureMovieFileOutput()
    private let backOutput = AVCaptureMovieFileOutput()
    private let storage = Storage.storage()
    
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
    @Published var useTopBottomLayout: Bool = true
    
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
    
    var onVideoProcessed: (() -> Void)?
    
    func setPreviewView(_ view: CameraPreviewUIView) {
        self.previewView = view
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
    }
    
    func retakeVideo() {
        let frontURLToDelete = frontURL
        let backURLToDelete = backURL
        let mergedURLToDelete = mergedVideoURL
        let contextToUse = storedContext
        
        resetPreviewState()
        
        if session.isRunning {
            session.stopRunning()
        }
        
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
            
            DispatchQueue.main.async {
                self.resetSession()
                self.setupCamera()
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
        resetSession()
        
        guard AVCaptureMultiCamSession.isMultiCamSupported else {
            print("MultiCam not supported")
            return
        }
        
        session.beginConfiguration()
        
        if let front = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
           let frontDeviceInput = try? AVCaptureDeviceInput(device: front) {
            
            frontCamera = front
            frontInput = frontDeviceInput
            
            if session.canAddInput(frontDeviceInput) {
                session.addInput(frontDeviceInput)
            }
            
            for connection in frontOutput.connections {
                session.removeConnection(connection)
            }
            
            if session.canAddOutput(frontOutput) {
                session.addOutput(frontOutput)
            }
        }
        
        if let back = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
           let backDeviceInput = try? AVCaptureDeviceInput(device: back) {
            
            backCamera = back
            backInput = backDeviceInput
            
            if session.canAddInput(backDeviceInput) {
                session.addInput(backDeviceInput)
            }
            
            for connection in backOutput.connections {
                session.removeConnection(connection)
            }
            
            if session.canAddOutput(backOutput) {
                session.addOutput(backOutput)
            }
        }
        
        if let microphone = AVCaptureDevice.default(for: .audio),
           let micInput = try? AVCaptureDeviceInput(device: microphone) {
            audioInput = micInput
            if session.canAddInput(micInput) {
                session.addInput(micInput)
            }
        }
        
        session.commitConfiguration()
        isSessionSetup = true
        
        if !session.isRunning {
            session.startRunning()
        }
        
        previewView?.setupPreviewLayers(with: session)
        isPreviewReady = true
    }
    
    private func resetSession() {
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
    
    func startRecording(context: NSManagedObjectContext) {
        guard !isRecording else { return }
        
        storedContext = context
        
        recordingCompletionCount = 0
        secondsRemaining = maxRecordingTime
        
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
        guard isRecording else { return }
        
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
                
                async let frontCrop = self.cropToMiddleThird(inputURL: frontURL, outputURL: croppedFrontURL)
                async let backCrop = self.cropToMiddleThird(inputURL: backURL, outputURL: croppedBackURL)
                
                try await (frontCrop, backCrop)
                
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
        
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
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
        
        let transform1 = rotation.concatenating(move1)
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
        
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
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
        
        guard let exportSession = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality) else {
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
        guard let firebaseURL = video.firebaseStorageURL,
              let url = URL(string: firebaseURL) else {
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

                async let frontRotate = self.rotateVideo(inputURL: frontURL, outputURL: rotatedFrontURL)
                async let backRotate = self.rotateVideo(inputURL: backURL, outputURL: rotatedBackURL)
                
                try await (frontRotate, backRotate)
                
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
        
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
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
        frontLayerInstruction.setTransform(CGAffineTransform.identity, at: .zero)
        
        let backLayerInstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: backTrack)
        let backTransform = CGAffineTransform(translationX: frontSize.width, y: 0)
        backLayerInstruction.setTransform(backTransform, at: .zero)
        
        instruction.layerInstructions = [frontLayerInstruction, backLayerInstruction]
        
        let videoComposition = AVMutableVideoComposition()
        videoComposition.renderSize = finalSize
        videoComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
        videoComposition.instructions = [instruction]
        
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw NSError(domain: "ExportError", code: -2)
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = videoComposition
        exportSession.shouldOptimizeForNetworkUse = true
        
        try await exportSession.export(to: outputURL, as: .mp4)
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
                        if self.useTopBottomLayout {
                            await self.processVideos(context: context)
                        } else {
                            await self.processVideosSideBySide(context: context)
                        }
                    }
                } else {
                    print("No context available for video processing")
                }
            }
        }
    }
}
