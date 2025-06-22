import SwiftUI
import AVKit

struct VideoPlayerPreviewView: View {
    let mergedVideoURL: URL
    let onSave: () -> Void
    let onBack: () -> Void
    
    @State private var player: AVPlayer
    @State private var playerLooper: Any?
    
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
                        Button(action: onSave) {
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
    }
    
    private func setupLooping() {
        NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player.currentItem, queue: .main) { _ in
            player.seek(to: .zero)
            player.play()
        }
        player.play()
    }
} 