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
    let persistenceController = PersistenceController.shared

    var body: some Scene {
        WindowGroup {
            if appState.isLoading {
                LoadingView()
            } else {
                ContentView()
                    .environmentObject(appState)
                    .environment(\.managedObjectContext, persistenceController.container.viewContext)
            }
        }
    }

}
