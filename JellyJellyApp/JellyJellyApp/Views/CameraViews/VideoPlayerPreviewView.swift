import SwiftUI
import AVKit
import Photos
import CoreData

struct VideoPlayerPreviewView: View {
    let mergedVideoURL: URL
    let onSave: () -> Void
    let onBack: () -> Void
    
    @State private var player: AVPlayer
    @State private var playerLooper: Any?
    @State private var isSavingVideo = false
    @State private var showSaveSuccess = false
    @State private var showPhotoLibraryPermissionAlert = false
    @State private var watermarkedVideoURL: URL?
    @State private var isWatermarkingInProgress = false
    @State private var showShareSheet = false
    @State private var isSharingToInstagram = false
    @State private var showInstagramError = false
    @State private var instagramErrorMessage = ""
    @Environment(\.managedObjectContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    
    init(mergedVideoURL: URL, onSave: @escaping () -> Void, onBack: @escaping () -> Void) {
        self.mergedVideoURL = mergedVideoURL
        self.onSave = onSave
        self.onBack = onBack
        _player = State(initialValue: AVPlayer(url: mergedVideoURL))
    }
    
    var body: some View {
        ZStack {
            Color("Background").edgesIgnoringSafeArea(.all)
            
            VStack {
                ZStack {
                    VideoPlayerView(player: player)
                        .cornerRadius(16)
                        .onAppear {
                            setupLooping()
                            loadWatermarkedVideoURL()
                        }
                        .onDisappear {
                            player.pause()
                            player.replaceCurrentItem(with: nil)
                            NotificationCenter.default.removeObserver(self)
                            do {
                                try AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
                            } catch {
                                print("Failed to deactivate AVAudioSession: \(error)")
                            }
                        }
                    
                    VStack {
                        HStack(spacing: 20) {
                            Button(action: onBack) {
                                Image(systemName: "xmark")
                                    .font(.system(size: 24))
                                    .foregroundColor(.white)
                                    .frame(width: 50, height: 50)
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Circle())
                            }
                            Spacer()
                        }
                        Spacer()
                    }
                    .padding()
                    
                    VStack {
                        Spacer()
                        HStack(spacing: 20) {
                            Spacer()
                            VStack {
                                Button(action: { showShareSheet = true }) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                        .frame(width: 50, height: 50)
                                        .background(Color("JellyPrimary"))
                                        .clipShape(Circle())
                                }
                                Button(action: handleInstagramShareButton) {
                                    Image("instagram")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 24, height: 24)
                                        .padding(13)
                                        .background(
                                            LinearGradient(
                                                colors: [Color.purple, Color.pink],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .clipShape(Circle())
                                }
                            }
                        }
                    }
                    .padding()
                }
                
                VStack {
                    HStack(spacing: 10) {
                        Button(action: saveVideoToPhotos) {
                            Image(systemName: "arrow.down")
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                                .frame(width: 50, height: 50)
                                .background(Color.black.opacity(0.5))
                                .clipShape(Circle())
                        }
                                                
//                        if watermarkedVideoURL != nil {
//                            Button(action: { showShareSheet = true }) {
//                                Image(systemName: "square.and.arrow.up")
//                                    .font(.system(size: 24))
//                                    .foregroundColor(.white)
//                                    .frame(width: 50, height: 50)
//                                    .background(Color("JellyPrimary"))
//                                    .clipShape(Circle())
//                            }
//                            
//                            Button(action: shareToSocialMedia) {
//                                Image(systemName: "camera")
//                                    .font(.system(size: 24))
//                                    .foregroundColor(.white)
//                                    .frame(width: 50, height: 50)
//                                    .background(
//                                        LinearGradient(
//                                            colors: [Color.purple, Color.pink],
//                                            startPoint: .topLeading,
//                                            endPoint: .bottomTrailing
//                                        )
//                                    )
//                                    .clipShape(Circle())
//                            }
//                        }
                        
                        Button(action: onSave) {
                            Text("Save Jelly")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color.black.opacity(0.5))
                                .cornerRadius(22)
                        }
                        
                        Button(action: onSave) {
                            Text("Post Jelly")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 50)
                                .background(Color("JellyPrimary"))
                                .cornerRadius(22)
                        }

                    }
                }
            }
            .safeAreaInset(edge: .leading) { Spacer().frame(width: 8) }
            .safeAreaInset(edge: .trailing) { Spacer().frame(width: 8) }
        }
        .overlay {
            if isSavingVideo {
                ProgressView("Saving video...")
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 10)
            }
            
            if isSharingToInstagram {
                ProgressView("Sharing to social media...")
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 10)
            }
        }
        .overlay {
            if showSaveSuccess {
                VStack {
                    Spacer()
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(Color("JellyPrimary"))
                        Text("Video saved to Photos")
                            .foregroundColor(.primary)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 10)
                    .padding(.bottom, 100)
                }
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.easeInOut, value: showSaveSuccess)
            }
        }
        .alert("Photo Library Access Required", isPresented: $showPhotoLibraryPermissionAlert) {
            Button("Settings", role: .none) {
                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                    UIApplication.shared.open(settingsURL)
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Please allow access to your photo library to save videos.")
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                player.play()
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let watermarkedURL = watermarkedVideoURL {
                ActivityView(activityItems: [watermarkedURL])
            }
        }
        .alert("Social Media Sharing Error", isPresented: $showInstagramError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(instagramErrorMessage)
        }
    }
    
    private func setupLooping() {
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { _ in
            player.seek(to: .zero)
            player.play()
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            player.play()
        }
    }
    
    private func loadWatermarkedVideoURL() {
        let fetchRequest: NSFetchRequest<RecordedVideo> = RecordedVideo.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "mergedVideoURL == %@", mergedVideoURL.absoluteString)
        
        if let video = try? context.fetch(fetchRequest).first {
            if let watermarkedURLString = video.watermarkedVideoURL,
               let watermarkedURL = URL(string: watermarkedURLString) {
                self.watermarkedVideoURL = watermarkedURL
                self.isWatermarkingInProgress = false
            } else {
                self.isWatermarkingInProgress = true
                
                Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
                    let updatedFetchRequest: NSFetchRequest<RecordedVideo> = RecordedVideo.fetchRequest()
                    updatedFetchRequest.predicate = NSPredicate(format: "mergedVideoURL == %@", mergedVideoURL.absoluteString)
                    
                    if let updatedVideo = try? context.fetch(updatedFetchRequest).first,
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
    
    private func saveVideoToPhotos() {
        isSavingVideo = true
        
        if let watermarkedURL = watermarkedVideoURL,
           FileManager.default.fileExists(atPath: watermarkedURL.path) {
            proceedWithSaving(watermarkedURL: watermarkedURL)
        } else {
            waitForWatermarkedVideo()
        }
    }
    
    private func waitForWatermarkedVideo() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            let fetchRequest: NSFetchRequest<RecordedVideo> = RecordedVideo.fetchRequest()
            fetchRequest.predicate = NSPredicate(format: "mergedVideoURL == %@", mergedVideoURL.absoluteString)
            
            if let video = try? context.fetch(fetchRequest).first,
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
    
    private func shareToSocialMedia() {
        guard let watermarkedURL = watermarkedVideoURL else {
            instagramErrorMessage = "No watermarked video available"
            showInstagramError = true
            return
        }
        
        isSharingToInstagram = true
        
        InstagramSharingService.shared.shareToSocialMediaUniversal(videoURL: watermarkedURL) { success, message in
            DispatchQueue.main.async {
                self.isSharingToInstagram = false
                
                if success {
                } else {
                    self.instagramErrorMessage = message
                    self.showInstagramError = true
                }
            }
        }
    }
    
    private func handleInstagramShareButton() {
        isSharingToInstagram = true
        if let watermarkedURL = watermarkedVideoURL, FileManager.default.fileExists(atPath: watermarkedURL.path) {
            shareToSocialMedia()
        } else {
            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
                let fetchRequest: NSFetchRequest<RecordedVideo> = RecordedVideo.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "mergedVideoURL == %@", mergedVideoURL.absoluteString)
                if let video = try? context.fetch(fetchRequest).first,
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
} 
