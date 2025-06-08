//
//  TabButton.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/8/25.
//

import SwiftUI

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.custom("Ranchers-Regular", size: 20))
                .foregroundColor(isSelected ? .white : .gray)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(
                    VStack {
                        Spacer()
                        if isSelected {
                            Rectangle()
                                .fill(Color.white)
                                .frame(height: 2)
                        }
                    }
                )
        }
    }
}
