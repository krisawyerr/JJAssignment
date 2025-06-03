//
//  LibraryView.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/3/25.
//

import SwiftUI
import CoreData

struct LibraryView: View {
    var body: some View {
        NavigationView {
            Text("This is the Library View")
                .navigationTitle("Library")
        }
    }
}

#Preview {
    LibraryView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
