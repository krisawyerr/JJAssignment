//
//  JellyJellyAppApp.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/3/25.
//

import SwiftUI
import FirebaseCore
import UIKit
import CoreData

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        return true
    }
    
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return .portrait
    }
}

@main
struct JellyJellyAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject var appState = AppState()
    @State private var isLoading = true
    @State private var wasInBackground = false

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(appState)
                    .environment(\.managedObjectContext, appState.persistenceState.viewContext)
                
                // if isLoading {
                //     LaunchScreenView()
                //         .transition(.opacity)
                //         .animation(.easeInOut(duration: 0.5), value: isLoading)
                //         .animation(.easeInOut(duration: 0.5), value: appState.cameraController.isPreviewReady)
                // }
            }
            .onAppear {
                prewarmShareSheet()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            print("Scene phase changed to: \(newPhase)")
            let cameraController = appState.cameraState.cameraController
            switch newPhase {
            case .active:
                if wasInBackground {
                    if appState.selectedTab == .create && !appState.isShowingPreview {
                        cameraController.resumeCamera()
                    }
                    appState.videoPlaybackState.resumeVideoPlayback(
                        shareableItems: appState.shareableItemsState.shareableItems,
                        likedItems: fetchLikedItems(context: appState.persistenceState.viewContext),
                        recordedItems: fetchRecordedVideos(context: appState.persistenceState.viewContext)
                    )
                }
                wasInBackground = false
            case .inactive:
                break
            case .background:
                wasInBackground = true
                cameraController.pauseCamera()
                appState.videoPlaybackState.pauseVideoPlayback(
                    shareableItems: appState.shareableItemsState.shareableItems,
                    likedItems: fetchLikedItems(context: appState.persistenceState.viewContext),
                    recordedItems: fetchRecordedVideos(context: appState.persistenceState.viewContext)
                )
            @unknown default:
                break
            }
        }
    }
}

func prewarmShareSheet() {
    guard let url = Bundle.main.url(forResource: "heart", withExtension: "svg") else { return }
    let activityVC = UIActivityViewController(activityItems: [url], applicationActivities: nil)

    let window = UIWindow(frame: UIScreen.main.bounds)
    window.windowLevel = .alert + 1
    window.isHidden = false
    let dummyVC = UIViewController()
    window.rootViewController = dummyVC

    dummyVC.present(activityVC, animated: false) {
        activityVC.dismiss(animated: false) {
            window.isHidden = true
        }
    }
}

fileprivate func fetchLikedItems(context: NSManagedObjectContext) -> [LikedItem] {
    let fetchRequest: NSFetchRequest<LikedItem> = LikedItem.fetchRequest()
    fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \LikedItem.createdAt, ascending: false)]
    do {
        return try context.fetch(fetchRequest)
    } catch {
        print("Error fetching liked videos: \(error)")
        return []
    }
}

fileprivate func fetchRecordedVideos(context: NSManagedObjectContext) -> [RecordedVideo] {
    let fetchRequest: NSFetchRequest<RecordedVideo> = RecordedVideo.fetchRequest()
    fetchRequest.predicate = NSPredicate(format: "saved == YES")
    fetchRequest.sortDescriptors = [NSSortDescriptor(keyPath: \RecordedVideo.createdAt, ascending: false)]
    do {
        return try context.fetch(fetchRequest)
    } catch {
        print("Error fetching recorded videos: \(error)")
        return []
    }
}
