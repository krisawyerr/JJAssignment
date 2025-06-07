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
        let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]

        frontURL = docsDir.appendingPathComponent("front_\(timestamp).mov")
        backURL = docsDir.appendingPathComponent("back_\(timestamp).mov")

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
        print("🎬 Starting processVideos...")

        guard let frontURL = self.frontURL,
              let backURL = self.backURL else {
            print("❌ Missing video URLs")
            return
        }

        print("📁 Front URL: \(frontURL)")
        print("📁 Back URL: \(backURL)")

        guard FileManager.default.fileExists(atPath: frontURL.path),
              FileManager.default.fileExists(atPath: backURL.path) else {
            print("❌ Video files do not exist")
            return
        }

        do {
            let frontFileSize = try FileManager.default.attributesOfItem(atPath: frontURL.path)[.size] as? UInt64 ?? 0
            let backFileSize = try FileManager.default.attributesOfItem(atPath: backURL.path)[.size] as? UInt64 ?? 0
            print("📊 Front file size: \(frontFileSize) bytes")
            print("📊 Back file size: \(backFileSize) bytes")
        } catch {
            print("⚠️ Could not get file sizes: \(error)")
        }

        DispatchQueue.global().asyncAfter(deadline: .now() + 2.0) {
            print("⏳ Starting video processing after delay...")

            let docsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let croppedFrontURL = docsDir.appendingPathComponent("cropped_front_\(Date().timeIntervalSince1970).mp4")
            let croppedBackURL = docsDir.appendingPathComponent("cropped_back_\(Date().timeIntervalSince1970).mp4")

            let dispatchGroup = DispatchGroup()

            print("✂️ Starting front video crop...")
            dispatchGroup.enter()
            self.cropToMiddleThird(inputURL: frontURL, outputURL: croppedFrontURL) { success, error in
                if success {
                    print("✅ Front crop completed")
                } else {
                    print("❌ Front crop failed: \(error?.localizedDescription ?? "Unknown error")")
                }
                dispatchGroup.leave()
            }

            print("✂️ Starting back video crop...")
            dispatchGroup.enter()
            self.cropToMiddleThird(inputURL: backURL, outputURL: croppedBackURL) { success, error in
                if success {
                    print("✅ Back crop completed")
                } else {
                    print("❌ Back crop failed: \(error?.localizedDescription ?? "Unknown error")")
                }
                dispatchGroup.leave()
            }

            dispatchGroup.notify(queue: .main) {
                print("🔄 Both crops completed, starting merge...")
                let mergedOutputURL = docsDir.appendingPathComponent("merged_\(Date().timeIntervalSince1970).mp4")

                self.mergeVideosTopBottom(videoURL1: croppedFrontURL, videoURL2: croppedBackURL, outputURL: mergedOutputURL) { success, error in
                    if success {
                        print("✅ Video merge completed: \(mergedOutputURL)")
                        let finalMergedWithAudioURL = docsDir.appendingPathComponent("merged_with_audio_\(Date().timeIntervalSince1970).mp4")

                        print("🔊 Starting audio merge...")
                        self.mergeVideosWithAudio(frontVideoURL: mergedOutputURL, frontAudioURL: frontURL, outputURL: finalMergedWithAudioURL) { audioSuccess in
                            if audioSuccess {
                                DispatchQueue.main.async {
                                    print("✅ Final video with audio at \(finalMergedWithAudioURL)")
                                    self.mergedVideoURL = finalMergedWithAudioURL

                                    let newRecording = RecordedVideo(context: context)
                                    newRecording.createdAt = Date()
                                    newRecording.mergedVideoURL = finalMergedWithAudioURL.absoluteString
                                    newRecording.frontVideoURL = frontURL.absoluteString
                                    newRecording.backVideoURL = backURL.absoluteString

                                    do {
                                        try context.save()
                                        print("📦 Saved to Core Data")
                                        self.onVideoProcessed?()
                                    } catch {
                                        print("❌ Failed to save to Core Data: \(error.localizedDescription)")
                                    }
                                }
                            } else {
                                print("❌ Failed to merge with audio")
                            }
                        }
                    } else {
                        print("❌ Merge failed: \(error?.localizedDescription ?? "Unknown error")")
                    }
                }
            }
        }
    }

    func cropToMiddleThird(inputURL: URL, outputURL: URL, completion: @escaping (Bool, Error?) -> Void) {
        let asset = AVURLAsset(url: inputURL)

        asset.loadValuesAsynchronously(forKeys: ["tracks"]) {
            var error: NSError?
            let status = asset.statusOfValue(forKey: "tracks", error: &error)

            guard status == .loaded else {
                completion(false, error)
                return
            }

            guard let videoTrack = asset.tracks(withMediaType: .video).first else {
                completion(false, NSError(domain: "No video track found", code: -1))
                return
            }

            let composition = AVMutableComposition()
            guard let compositionTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
                completion(false, NSError(domain: "Track creation failed", code: -2))
                return
            }

            do {
                try compositionTrack.insertTimeRange(
                    CMTimeRange(start: .zero, duration: asset.duration),
                    of: videoTrack,
                    at: .zero
                )
            } catch {
                completion(false, error)
                return
            }

            let naturalSize = videoTrack.naturalSize
            let cropWidth = naturalSize.width / 2
            let cropX = naturalSize.width / 4
            let transform = CGAffineTransform(translationX: -cropX, y: 0)

            let transformer = AVMutableVideoCompositionLayerInstruction(assetTrack: compositionTrack)
            transformer.setTransform(transform, at: .zero)

            let instruction = AVMutableVideoCompositionInstruction()
            instruction.timeRange = CMTimeRange(start: .zero, duration: asset.duration)
            instruction.layerInstructions = [transformer]

            let videoComposition = AVMutableVideoComposition()
            videoComposition.instructions = [instruction]
            videoComposition.frameDuration = CMTime(value: 1, timescale: 30)
            videoComposition.renderSize = CGSize(width: cropWidth, height: naturalSize.height)

            guard let export = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
                completion(false, NSError(domain: "Export session failed", code: -3))
                return
            }

            export.outputURL = outputURL
            export.outputFileType = .mp4
            export.videoComposition = videoComposition
            export.exportAsynchronously {
                switch export.status {
                case .completed:
                    completion(true, nil)
                case .failed, .cancelled:
                    completion(false, export.error)
                default:
                    break
                }
            }
        }
    }

    func mergeVideosTopBottom(videoURL1: URL, videoURL2: URL, outputURL: URL, completion: @escaping (Bool, Error?) -> Void) {
        let asset1 = AVURLAsset(url: videoURL1)
        let asset2 = AVURLAsset(url: videoURL2)

        let composition = AVMutableComposition()
        guard let track1 = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let track2 = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid),
              let assetTrack1 = asset1.tracks(withMediaType: .video).first,
              let assetTrack2 = asset2.tracks(withMediaType: .video).first else {
            completion(false, NSError(domain: "MergeError", code: -1, userInfo: nil))
            return
        }

        let timeRange = CMTimeRange(start: .zero, duration: min(asset1.duration, asset2.duration))

        do {
            try track1.insertTimeRange(timeRange, of: assetTrack1, at: .zero)
            try track2.insertTimeRange(timeRange, of: assetTrack2, at: .zero)
        } catch {
            completion(false, error)
            return
        }

        let naturalSize = assetTrack1.naturalSize
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
            completion(false, NSError(domain: "ExportError", code: -2, userInfo: nil))
            return
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.videoComposition = videoComposition
        exportSession.shouldOptimizeForNetworkUse = true

        exportSession.exportAsynchronously {
            switch exportSession.status {
            case .completed:
                completion(true, nil)
            case .failed, .cancelled:
                completion(false, exportSession.error)
            default:
                break
            }
        }
    }

    func mergeVideosWithAudio(frontVideoURL: URL, frontAudioURL: URL, outputURL: URL, completion: @escaping (Bool) -> Void) {
        let mixComposition = AVMutableComposition()

        let videoAsset = AVAsset(url: frontVideoURL)
        let audioAsset = AVAsset(url: frontAudioURL)

        guard let videoTrack = videoAsset.tracks(withMediaType: .video).first else {
            completion(false)
            return
        }

        guard let audioTrack = audioAsset.tracks(withMediaType: .audio).first else {
            completion(false)
            return
        }

        let videoCompTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        do {
            try videoCompTrack?.insertTimeRange(CMTimeRange(start: .zero, duration: videoAsset.duration), of: videoTrack, at: .zero)
        } catch {
            completion(false)
            return
        }

        let audioCompTrack = mixComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        do {
            try audioCompTrack?.insertTimeRange(CMTimeRange(start: .zero, duration: videoAsset.duration), of: audioTrack, at: .zero)
        } catch {
            completion(false)
            return
        }

        guard let exportSession = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality) else {
            completion(false)
            return
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true

        exportSession.exportAsynchronously {
            DispatchQueue.main.async {
                completion(exportSession.status == .completed)
            }
        }
    }
}

extension CameraController: AVCaptureFileOutputRecordingDelegate {
    func fileOutput(_ output: AVCaptureFileOutput, didFinishRecordingTo outputFileURL: URL,
                    from connections: [AVCaptureConnection], error: Error?) {

        recordingCompletionCount += 1

        if let error = error {
            print("Recording error: \(error.localizedDescription)")
        } else {
            print("Recording saved to \(outputFileURL)")
        }

        if recordingCompletionCount >= 2 {
            DispatchQueue.main.async {
                if let context = self.storedContext {
                    print("✅ Both recordings complete, starting video processing...")
                    self.processVideos(context: context)
                } else {
                    print("❌ No context available for video processing")
                }
            }
        }
    }
}
