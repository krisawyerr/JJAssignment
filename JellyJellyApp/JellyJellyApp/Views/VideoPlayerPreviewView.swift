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
            Color.black.edgesIgnoringSafeArea(.all)
            
            if isFrontOnly {
                FrontOnlyVideoPlayerView(frontURL: frontURL, backURL: backURL, cameraSwitchTimestamps: cameraSwitchTimestamps, initialCameraPosition: initialCameraPosition)
            } else if isSideBySide {
                SideBySideVideoPlayerView(frontURL: frontURL, backURL: backURL)
            } else {
                DualVideoPlayerView(frontURL: frontURL, backURL: backURL)
            }
            
            VStack {
                Spacer()
                
                HStack(spacing: 20) {
                    Spacer()
                    Button(action: onBack) {
                        Image(systemName: "arrow.left")
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
                            .frame(width: 200, height: 50)
                            .background(Color("JellyPrimary"))
                            .cornerRadius(22)
                    }
                    Spacer()
                }
                .padding()
            }
        }
    }
} 
