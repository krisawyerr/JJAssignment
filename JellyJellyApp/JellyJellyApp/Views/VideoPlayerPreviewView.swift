import SwiftUI
import AVKit
import Photos

struct VideoPlayerPreviewView: View {
    let mergedVideoURL: URL
    let onSave: () -> Void
    let onBack: () -> Void
    
    @State private var player: AVPlayer
    @State private var playerLooper: Any?
    @State private var isSavingVideo = false
    @State private var showSaveSuccess = false
    @State private var showPhotoLibraryPermissionAlert = false
    
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
    }
    
    private func setupLooping() {
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { _ in
            player.seek(to: .zero)
            player.play()
        }
        player.play()
    }
    
    private func saveVideoToPhotos() {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized, .limited:
                    isSavingVideo = true
                    PHPhotoLibrary.shared().performChanges({
                        PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: mergedVideoURL)
                    }) { success, error in
                        DispatchQueue.main.async {
                            isSavingVideo = false
                            if success {
                                showSaveSuccess = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    showSaveSuccess = false
                                }
                            } else if let error = error {
                                print("Error saving video: \(error.localizedDescription)")
                            }
                        }
                    }
                case .denied, .restricted:
                    showPhotoLibraryPermissionAlert = true
                case .notDetermined:
                    break
                @unknown default:
                    break
                }
            }
        }
    }
} 