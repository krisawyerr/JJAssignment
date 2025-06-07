//
//  JellyJellyAppApp.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/3/25.
//

import SwiftUI

@main
struct JellyJellyAppApp: App {
    @StateObject var appState = AppState()
    @State private var isLoading = true

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
    }
}
