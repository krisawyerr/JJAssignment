//
//  LibraryTabBar.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/8/25.
//

import SwiftUI

struct LibraryTabBar: View {
    @Binding var selectedTab: LibraryView.LibraryTab
    
    var body: some View {
        HStack(spacing: 0) {
            TabButton(title: "My Videos", isSelected: selectedTab == .myVideos) {
                selectedTab = .myVideos
            }
            
            TabButton(title: "Liked", isSelected: selectedTab == .likedVideos) {
                selectedTab = .likedVideos
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }
}
