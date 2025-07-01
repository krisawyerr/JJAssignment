//
//  JellyJellyAppApp.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/3/25.
//

import SwiftUI
import FirebaseCore
import UIKit

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
                    .environment(\.managedObjectContext, appState.viewContext)
                
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
            let cameraController = appState.cameraController
            switch newPhase {
            case .active:
                if wasInBackground {
                    if appState.selectedTab == .create && !appState.isShowingPreview {
                        cameraController.resumeCamera()
                    }
                    appState.resumeVideoPlayback()
                }
                wasInBackground = false
            case .inactive:
                break
            case .background:
                wasInBackground = true
                cameraController.pauseCamera()
                appState.pauseVideoPlayback()
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
