//
//  GlobalMuteManager.swift
//  JellyJellyApp
//
//  Created by Kris Sawyerr on 6/6/25.
//

import Foundation

class GlobalMuteManager: ObservableObject {
    @Published var isGloballyMuted = false
    
    static let shared = GlobalMuteManager()
    
    private init() {}
    
    func setMuted(_ muted: Bool) {
        isGloballyMuted = muted
    }
}
