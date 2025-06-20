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

    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            if isLoading {
                LaunchScreenView()
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            withAnimation(.easeInOut(duration: 0.5)) {
                                isLoading = false
                            }
                        }
                    }
            } else {
                ContentView()
                    .environmentObject(appState)
                    .environment(\.managedObjectContext, appState.viewContext)
            }
        }
        .onChange(of: scenePhase) {
            print(scenePhase)
            let cameraController = appState.cameraController
            if scenePhase == .active {
                cameraController.setupCamera()
            }
        }
    }
}
