import SwiftUI
import AVKit

struct VideoPlayerPreviewView: View {
    let frontURL: URL
    let backURL: URL
    let onSave: () -> Void
    let onBack: () -> Void
    @State var isSideBySide: Bool
    @State var isFrontOnly: Bool
    let cameraSwitchTimestamps: [Double]
    let initialCameraPosition: AVCaptureDevice.Position
    
    var body: some View {
        ZStack {
            Color("Background").edgesIgnoringSafeArea(.all)
            
            VStack {
                ZStack {
                    if isFrontOnly {
                        FrontOnlyVideoPlayerView(frontURL: frontURL, backURL: backURL, cameraSwitchTimestamps: cameraSwitchTimestamps, initialCameraPosition: initialCameraPosition)
                            .cornerRadius(16)
                    } else if isSideBySide {
                        SideBySideVideoPlayerView(frontURL: frontURL, backURL: backURL)
                            .cornerRadius(16)
                    } else {
                        DualVideoPlayerView(frontURL: frontURL, backURL: backURL)
                            .cornerRadius(16)
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
} 
