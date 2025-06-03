//
//  ContentView.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/3/25.
//

import SwiftUI
import CoreData

struct HomeView: View {
    var body: some View {
        NavigationView {
            Text("This is the Home View")
                .navigationTitle("Home")
        }
    }
}

struct CreateView: View {
    var body: some View {
        NavigationView {
            Text("This is the Create View")
                .navigationTitle("Create")
        }
    }
}

struct LibraryView: View {
    var body: some View {
        NavigationView {
            Text("This is the Library View")
                .navigationTitle("Library")
        }
    }
}

struct ContentView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }

            CreateView()
                .tabItem {
                    Image(systemName: "camera.fill")
                    Text("Create")
                }
            
            LibraryView()
                .tabItem {
                    Image(systemName: "photo.fill")
                    Text("Library")
                }
        }
    }
}

#Preview {
    ContentView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
