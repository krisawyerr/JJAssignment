//
//  JellyJellyAppApp.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/3/25.
//

import SwiftUI
import FirebaseCore

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
                
                if isLoading {
                    LaunchScreenView()
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.5), value: isLoading)
                        .animation(.easeInOut(duration: 0.5), value: appState.cameraController.isPreviewReady)
                }
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    withAnimation(.easeInOut(duration: 0.5)) {
                        isLoading = false
                    }
                }
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
                } else {
                    cameraController.setupCamera()
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
