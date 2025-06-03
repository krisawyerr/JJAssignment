//
//  CreateView.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/3/25.
//

import SwiftUI
import CoreData

struct CreateView: View {
    var body: some View {
        NavigationView {
            Text("This is the Create View")
                .navigationTitle("Create")
        }
    }
}

#Preview {
    CreateView().environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
