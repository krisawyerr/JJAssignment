//
//  ContentView.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/3/25.
//

import SwiftUI
import CoreData

enum Tab {
    case home
    case create
    case library
}

struct ContentView: View {
    @State private var selectedTab: Tab = .home
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView(selectedTab: $selectedTab)
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(Tab.home)

            CreateView(selectedTab: $selectedTab)
                .tabItem {
                    Image(systemName: "camera.fill")
                    Text("Create")
                }
                .tag(Tab.create)
            
            LibraryView(selectedTab: $selectedTab)
                .tabItem {
                    Image(systemName: "photo.fill")
                    Text("Library")
                }
                .tag(Tab.library)
        }
    }
}
#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
