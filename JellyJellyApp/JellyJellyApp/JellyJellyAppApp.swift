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

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environment(\.managedObjectContext, appState.viewContext)
        }
    }

}
