//
//  AppLifecycleManager.swift
//  MessageAI
//
//  Created on 10/20/2025.
//

import SwiftUI
import FirebaseAuth

class AppLifecycleManager: ObservableObject {
    private let authService = AuthService()
    
    func onAppear() {
        Task {
            try? await authService.updateOnlineStatus(true)
        }
    }
    
    func onDisappear() {
        Task {
            try? await authService.updateOnlineStatus(false)
        }
    }
    
    func onBackground() {
        Task {
            try? await authService.updateOnlineStatus(false)
        }
    }
    
    func onForeground() {
        Task {
            try? await authService.updateOnlineStatus(true)
        }
    }
}

