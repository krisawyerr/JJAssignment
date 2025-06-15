//
//  CameraController.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/4/25.
//

import SwiftUI
import AVFoundation
import CoreData

class CameraController: NSObject, ObservableObject {
    private let session = AVCaptureMultiCamSession()
    private let frontOutput = AVCaptureMovieFileOutput()
    private let backOutput = AVCaptureMovieFileOutput()

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

    private var frontCamera: AVCaptureDevice?
    private var backCamera: AVCaptureDevice?
    private var frontInput: AVCaptureDeviceInput?
    private var backInput: AVCaptureDeviceInput?
    private var audioInput: AVCaptureDeviceInput?
    private var isSessionSetup = false

    private var recordingTimer: Timer?
    private let maxRecordingTime = 15000

    private var recordingCompletionCount = 0
    private var storedContext: NSManagedObjectContext?
    private var processingStartTime: CFAbsoluteTime = 0

    var onVideoProcessed: (() -> Void)?

    func setPreviewView(_ view: CameraPreviewUIView) {
        self.previewView = view
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

        DispatchQueue.global(qos: .userInitiated).async {
            if !self.session.isRunning {
                self.session.startRunning()
            }

            DispatchQueue.main.async {
                self.previewView?.setupPreviewLayers(with: self.session)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    self.isPreviewReady = true
                }
            }
        }
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
            DispatchQueue.global(qos: .userInitiated).async {
                self.session.stopRunning()
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

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            let tempDir = FileManager.default.temporaryDirectory
            let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let croppedFrontURL = tempDir.appendingPathComponent("cropped_front_\(Date().timeIntervalSince1970).mp4")
            let croppedBackURL = tempDir.appendingPathComponent("cropped_back_\(Date().timeIntervalSince1970).mp4")
            let mergedOutputURL = tempDir.appendingPathComponent("merged_\(Date().timeIntervalSince1970).mp4")
            let finalMergedWithAudioURL = docsDir.appendingPathComponent("merged_with_audio_\(Date().timeIntervalSince1970).mp4")

            Task {
                do {
                    async let frontCrop = self.cropToMiddleThird(inputURL: frontURL, outputURL: croppedFrontURL)
                    async let backCrop = self.cropToMiddleThird(inputURL: backURL, outputURL: croppedBackURL)
                    
                    try await (frontCrop, backCrop)
                    
                    try await self.mergeVideosTopBottom(videoURL1: croppedFrontURL, videoURL2: croppedBackURL, outputURL: mergedOutputURL)
                    
                    try? FileManager.default.removeItem(at: croppedFrontURL)
                    try? FileManager.default.removeItem(at: croppedBackURL)
                    
                    let newRecording = RecordedVideo(context: context)
                    newRecording.createdAt = Date()
                    newRecording.mergedVideoURL = mergedOutputURL.absoluteString
                    newRecording.frontVideoURL = frontURL.absoluteString
                    newRecording.backVideoURL = backURL.absoluteString
                    
                    try context.save()
                    
                    Task {
                        do {
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
                        } catch {
                            print("Audio merge failed: \(error.localizedDescription)")
                        }
                    }
                    
                    await MainActor.run {
                        self.mergedVideoURL = mergedOutputURL
                    }
                    
                } catch {
                    print("Video processing failed: \(error.localizedDescription)")
                }
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
        
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetMediumQuality) else {
            throw NSError(domain: "Export session failed", code: -3)
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
        
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetMediumQuality) else {
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
        
        guard let exportSession = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetMediumQuality) else {
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
                        await self.processVideos(context: context)
                    }
                } else {
                    print("No context available for video processing")
                }
            }
        }
    }
}
