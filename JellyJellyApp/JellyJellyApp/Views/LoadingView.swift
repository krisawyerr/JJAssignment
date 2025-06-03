//
//  LibraryView.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/3/25.
//

import SwiftUI
import CoreData

struct LoadingView: View {
    var body: some View {
        Text("Loading...")
    }
}

#Preview {
    LoadingView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
