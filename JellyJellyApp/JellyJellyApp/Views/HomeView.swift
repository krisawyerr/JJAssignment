//
//  HomeView.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/3/25.
//

import SwiftUI
import CoreData

struct HomeView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        NavigationView {
            if appState.isLoading {
                ProgressView("Loading...")
            } else {
                List(appState.shareableItems) { item in
                    VStack(alignment: .leading) {
                        Text(item.title).font(.headline)
                        Text(item.summary).font(.subheadline)
                        if let thumbnail = item.content.thumbnails.first,
                           let url = URL(string: thumbnail) {
                            AsyncImage(url: url) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(height: 200)
                                        .clipped()
                                case .failure:
                                    Color.gray
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8)
                }
                .navigationTitle("Library")
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AppState())
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
