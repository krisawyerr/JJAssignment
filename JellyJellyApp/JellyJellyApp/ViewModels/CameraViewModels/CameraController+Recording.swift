import Foundation
import CoreData

extension CameraController {
    func startRecording(context: NSManagedObjectContext) {
        guard !isRecording else {
            return
        }
        cleanupWriter()
        do {
            try configureAudioSessionForFrontCameraRecording()
        } catch {
            print("Failed to configure audio session for front camera recording: \(error)")
        }
        storedContext = context
        recordingCompletionCount = 0
        secondsRemaining = maxRecordingTime
        cameraSwitchTimestamps.removeAll()
        recordingStartTime = CFAbsoluteTimeGetCurrent()
        if cameraLayoutMode == .frontOnly {
            initialCameraPosition = activeCameraInFrontOnlyMode
        } else {
            initialCameraPosition = .front
        }
        let timestamp = Date().timeIntervalSince1970
        let tempDir = FileManager.default.temporaryDirectory
        outputURL = tempDir.appendingPathComponent("merged_realtime_\(timestamp).mp4")
        setupWriter()
        DispatchQueue.main.async {
            self.isRecording = true
        }
        startTimer()
    }
    func stopRecording() {
        guard isRecording else {
            return
        }
        stopTimer()
        finishWriter()
        do {
            try deactivateAudioSession()
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
        DispatchQueue.main.async {
            self.isRecording = false
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
        do {
            try deactivateAudioSession()
        } catch {
            print("Failed to deactivate audio session: \(error)")
        }
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
                self.applyInitialZoomSettings()
                self.preWarmWriter()
            }
        }
    }
    func startTimer() {
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
    func stopTimer() {
        recordingTimer?.invalidate()
        recordingTimer = nil
    }
    func recordCameraSwitch() {
        if isRecording {
            let switchTime = CFAbsoluteTimeGetCurrent() - recordingStartTime
            cameraSwitchTimestamps.append(switchTime)
            print("Camera switch recorded at: \(switchTime)s")
        }
    }
} 
