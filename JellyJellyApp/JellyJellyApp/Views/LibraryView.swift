//
//  LibraryView.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/3/25.
//

import SwiftUI
import CoreData
import AVKit

struct LibraryView: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \RecordedVideo.createdAt, ascending: false)],
        animation: .default)
    private var videos: FetchedResults<RecordedVideo>

    var body: some View {
        NavigationView {
            List {
                ForEach(videos, id: \.self) { recording in
                    NavigationLink(destination: LibraryVideoPlayerView(
                        mergedVideoPath: recording.mergedVideoURL ?? ""
                    )) {
                        Text("Video: \(recording.createdAt!, formatter: itemFormatter)")
                    }
                }
            }
            .navigationTitle("Saved Recordings")
        }
    }
}

struct LibraryVideoPlayerView: View {
    let mergedVideoPath: String
    @State private var player: AVPlayer?

    private func url(for path: String) -> URL? {
        guard let lastComponent = path.components(separatedBy: "/").last,
              let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let fullURL = documentsURL.appendingPathComponent(lastComponent)
        return FileManager.default.fileExists(atPath: fullURL.path) ? fullURL : nil
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let videoURL = url(for: mergedVideoPath) {
                    LibraryVideoPlayerContainer(videoURL: videoURL)
                } else {
                    Text("Video not found")
                        .foregroundColor(.white)
                }
            }
        }
        .edgesIgnoringSafeArea(.all)
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct LibraryVideoPlayerContainer: UIViewControllerRepresentable {
    let videoURL: URL
    private let player = AVPlayer()
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        let playerItem = AVPlayerItem(url: videoURL)
        player.replaceCurrentItem(with: playerItem)
        controller.player = player
        controller.showsPlaybackControls = false
        controller.entersFullScreenWhenPlaybackBegins = true
        controller.exitsFullScreenWhenPlaybackEnds = true
        
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.playerItemDidReachEnd(notification:)),
            name: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem)
        
        player.play()
        
        return controller
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(player: player)
    }
    
    class Coordinator: NSObject {
        var player: AVPlayer
        
        init(player: AVPlayer) {
            self.player = player
        }
        
        @objc func playerItemDidReachEnd(notification: Notification) {
            player.seek(to: .zero)
            player.play()
        }
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {

    }
}

private let itemFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateStyle = .short
    formatter.timeStyle = .medium
    return formatter
}()

#Preview {
    LibraryView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
