import SwiftUI
import AVKit
import Photos
import CoreData
import TikTokOpenShareSDK

struct RecordingPreviewView: View {
    let mergedVideoURL: URL
    let onSave: () -> Void
    let onBack: () -> Void
    
    @Environment(\.managedObjectContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    
    @StateObject private var viewModel: RecordingPreviewViewModel
    
    init(mergedVideoURL: URL, onSave: @escaping () -> Void, onBack: @escaping () -> Void) {
        self.mergedVideoURL = mergedVideoURL
        self.onSave = onSave
        self.onBack = onBack
        _viewModel = StateObject(wrappedValue: RecordingPreviewViewModel(
            mergedVideoURL: mergedVideoURL,
            onSave: onSave,
            onBack: onBack,
            context: NSManagedObjectContext(concurrencyType: .mainQueueConcurrencyType)
        ))
    }
    
    var body: some View {
        let _ = { if viewModel.context !== context { viewModel.context = context } }()
        ZStack {
            Color("Background").edgesIgnoringSafeArea(.all)
            
            VStack {
                ZStack {
                    VideoPlayerView(player: viewModel.player)
                        .cornerRadius(16)
                        .onAppear { viewModel.onAppear() }
                        .onDisappear { viewModel.onDisappear() }
                    
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
                                Button(action: { viewModel.showShareSheet = true }) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.system(size: 24))
                                        .foregroundColor(.white)
                                        .frame(width: 50, height: 50)
                                        .background(Color("JellyPrimary").opacity(0.8))
                                        .clipShape(Circle())
                                }
                                Button(action: viewModel.handleInstagramShareButton) {
                                    Image("instagram")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 24, height: 24)
                                        .padding(13)
                                        .background(
                                            LinearGradient(
                                                colors: [Color.purple.opacity(0.8), Color.pink.opacity(0.8)],
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        )
                                        .clipShape(Circle())
                                }
                                Button(action: viewModel.shareToTikTok) {
                                    Image("tiktok")
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 24, height: 24)
                                        .padding(13)
                                        .background(
                                            Color.black.opacity(0.8)
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
                        Button(action: viewModel.saveVideoToPhotos) {
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
            if viewModel.isSavingVideo {
                ProgressView("Saving video...")
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 10)
            }
            
            if viewModel.isSharingToInstagram {
                ProgressView("Sharing to social media...")
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(10)
                    .shadow(radius: 10)
            }
        }
        .overlay {
            if viewModel.showSaveSuccess {
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
                .animation(.easeInOut, value: viewModel.showSaveSuccess)
            }
        }
        .alert("Photo Library Access Required", isPresented: $viewModel.showPhotoLibraryPermissionAlert) {
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
            viewModel.onScenePhaseChange(newPhase)
        }
        .sheet(isPresented: $viewModel.showShareSheet) {
            if let watermarkedURL = viewModel.watermarkedVideoURL {
                ActivityView(activityItems: [watermarkedURL])
            }
        }
        .alert("Social Media Sharing Error", isPresented: $viewModel.showInstagramError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(viewModel.instagramErrorMessage)
        }
    }
} 
