import Foundation
import AVKit
import Photos
import CoreData
import SwiftUI
import TikTokOpenShareSDK

class RecordingPreviewViewModel: ObservableObject {
    let mergedVideoURL: URL
    let onSave: () -> Void
    let onBack: () -> Void
    var context: NSManagedObjectContext

    @Published var player: AVPlayer
    @Published var playerLooper: Any?
    @Published var isSavingVideo = false
    @Published var showSaveSuccess = false
    @Published var showPhotoLibraryPermissionAlert = false
    @Published var watermarkedVideoURL: URL?
    @Published var isWatermarkingInProgress = false
    @Published var showShareSheet = false
    @Published var isSharingToInstagram = false
    @Published var showInstagramError = false
    @Published var instagramErrorMessage = ""

    private var scenePhase: ScenePhase = .active
    private var watermarkTimer: Timer?
    private var instagramTimer: Timer?

    init(mergedVideoURL: URL, onSave: @escaping () -> Void, onBack: @escaping () -> Void, context: NSManagedObjectContext) {
        self.mergedVideoURL = mergedVideoURL
        self.onSave = onSave
        self.onBack = onBack
        self.context = context
        self.player = AVPlayer(url: mergedVideoURL)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        watermarkTimer?.invalidate()
        instagramTimer?.invalidate()
    }

    func setupLooping() {
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { [weak self] _ in
            self?.player.seek(to: .zero)
            self?.player.play()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.player.play()
        }
    }

    func loadWatermarkedVideoURL() {
        let fetchRequest: NSFetchRequest<RecordedVideo> = RecordedVideo.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "mergedVideoURL == %@", mergedVideoURL.absoluteString)
        if let video = try? context.fetch(fetchRequest).first {
            if let watermarkedURLString = video.watermarkedVideoURL,
               let watermarkedURL = URL(string: watermarkedURLString) {
                self.watermarkedVideoURL = watermarkedURL
                self.isWatermarkingInProgress = false
            } else {
                self.isWatermarkingInProgress = true
                watermarkTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
                    guard let self = self else { timer.invalidate(); return }
                    let updatedFetchRequest: NSFetchRequest<RecordedVideo> = RecordedVideo.fetchRequest()
                    updatedFetchRequest.predicate = NSPredicate(format: "mergedVideoURL == %@", self.mergedVideoURL.absoluteString)
                    if let updatedVideo = try? self.context.fetch(updatedFetchRequest).first,
                       let watermarkedURLString = updatedVideo.watermarkedVideoURL,
                       let watermarkedURL = URL(string: watermarkedURLString) {
                        self.watermarkedVideoURL = watermarkedURL
                        self.isWatermarkingInProgress = false
                        timer.invalidate()
                    }
                }
            }
        }
    }

    func saveVideoToPhotos() {
        isSavingVideo = true
        if let watermarkedURL = watermarkedVideoURL,
           FileManager.default.fileExists(atPath: watermarkedURL.path) {
            proceedWithSaving(watermarkedURL: watermarkedURL)
        } else {
            waitForWatermarkedVideo()
        }
    }

    private func waitForWatermarkedVideo() {
        watermarkTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            let fetchRequest: NSFetchRequest<RecordedVideo> = RecordedVideo.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "mergedVideoURL == %@", self.mergedVideoURL.absoluteString)
            if let video = try? self.context.fetch(fetchRequest).first,
               let watermarkedURLString = video.watermarkedVideoURL,
               let watermarkedURL = URL(string: watermarkedURLString),
               FileManager.default.fileExists(atPath: watermarkedURL.path) {
                timer.invalidate()
                self.watermarkedVideoURL = watermarkedURL
                self.isWatermarkingInProgress = false
                self.proceedWithSaving(watermarkedURL: watermarkedURL)
            }
        }
    }

    private func proceedWithSaving(watermarkedURL: URL) {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: watermarkedURL)
                    }) { success, error in
                        DispatchQueue.main.async {
                            self.isSavingVideo = false
                            if success {
                                self.showSaveSuccess = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    self.showSaveSuccess = false
                                }
                            } else if let error = error {
                                print("Error saving video: \(error.localizedDescription)")
                            }
                        }
                    }
                case .denied, .restricted:
                    self.isSavingVideo = false
                    self.showPhotoLibraryPermissionAlert = true
                case .notDetermined:
                    self.isSavingVideo = false
                    break
                @unknown default:
                    self.isSavingVideo = false
                    break
                }
            }
        }
    }

    func shareToTikTok() {
        guard let watermarkedURL = watermarkedVideoURL, FileManager.default.fileExists(atPath: watermarkedURL.path) else {
            instagramErrorMessage = "No watermarked video available"
            showInstagramError = true
            isSharingToInstagram = false
            return
        }
        TikTokSharingService.shared.shareToTikTok(videoURL: watermarkedURL, redriectURI: "your-redirect-uri") { [weak self] state, message in
            DispatchQueue.main.async {
                self?.isSharingToInstagram = false
                switch state {
                case .postedWithSuccess:
                    break
                case .failedToPost:
                    self?.instagramErrorMessage = message
                    self?.showInstagramError = true
                }
            }
        }
    }

    func shareToSocialMedia() {
        guard let watermarkedURL = watermarkedVideoURL else {
            instagramErrorMessage = "No watermarked video available"
            showInstagramError = true
            return
        }
        isSharingToInstagram = true
        InstagramSharingService.shared.shareToSocialMediaUniversal(videoURL: watermarkedURL) { [weak self] success, message in
            DispatchQueue.main.async {
                self?.isSharingToInstagram = false
                if !success {
                    self?.instagramErrorMessage = message
                    self?.showInstagramError = true
                }
            }
        }
    }

    func handleInstagramShareButton() {
        isSharingToInstagram = true
        if let watermarkedURL = watermarkedVideoURL, FileManager.default.fileExists(atPath: watermarkedURL.path) {
            shareToSocialMedia()
        } else {
            instagramTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
                guard let self = self else { timer.invalidate(); return }
                let fetchRequest: NSFetchRequest<RecordedVideo> = RecordedVideo.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "mergedVideoURL == %@", self.mergedVideoURL.absoluteString)
                if let video = try? self.context.fetch(fetchRequest).first,
                   let watermarkedURLString = video.watermarkedVideoURL,
                   let watermarkedURL = URL(string: watermarkedURLString),
                   FileManager.default.fileExists(atPath: watermarkedURL.path) {
                    timer.invalidate()
                    self.watermarkedVideoURL = watermarkedURL
                    self.isWatermarkingInProgress = false
                    self.shareToSocialMedia()
                }
            }
        }
    }
    
    func handleTikTokShareButton() {
        isSharingToInstagram = true
        if let watermarkedURL = watermarkedVideoURL, FileManager.default.fileExists(atPath: watermarkedURL.path) {
            shareToTikTok()
        } else {
            instagramTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] timer in
                guard let self = self else { timer.invalidate(); return }
                let fetchRequest: NSFetchRequest<RecordedVideo> = RecordedVideo.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "mergedVideoURL == %@", self.mergedVideoURL.absoluteString)
                if let video = try? self.context.fetch(fetchRequest).first,
                   let watermarkedURLString = video.watermarkedVideoURL,
                   let watermarkedURL = URL(string: watermarkedURLString),
                   FileManager.default.fileExists(atPath: watermarkedURL.path) {
                    timer.invalidate()
                    self.watermarkedVideoURL = watermarkedURL
                    self.isWatermarkingInProgress = false
                    self.shareToTikTok()
                }
            }
        }
    }

    func saveVideoToPhotosAndGetIdentifier(video: URL) async throws -> String {
        return try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                switch status {
                case .authorized, .limited:
                    PHPhotoLibrary.shared().performChanges({
                        let request = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: video)
                        let placeholder = request?.placeholderForCreatedAsset
                        let localIdentifier = placeholder?.localIdentifier
                        continuation.resume(returning: localIdentifier ?? "")
                    }) { success, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        }
                    }
                default:
                    continuation.resume(throwing: NSError(domain: "PhotoLibrary", code: 1, userInfo: [NSLocalizedDescriptionKey: "Not authorized"]))
                }
            }
        }
    }

    func onAppear() {
        setupLooping()
        loadWatermarkedVideoURL()
    }

    func onDisappear() {
        player.pause()
        player.replaceCurrentItem(with: nil)
        NotificationCenter.default.removeObserver(self)
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        } catch {
            print("Failed to deactivate AVAudioSession: \(error)")
        }
    }

    func onScenePhaseChange(_ newPhase: ScenePhase) {
        scenePhase = newPhase
        if newPhase == .active {
            player.play()
        }
    }
} 
