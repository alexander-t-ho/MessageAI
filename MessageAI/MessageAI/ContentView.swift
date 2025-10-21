//
//  ContentView.swift
//  MessageAI
//
//  Created by Alex Ho on 10/20/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var webSocketService = WebSocketService()
    
    var body: some View {
        Group {
            if authViewModel.isAuthenticated {
                HomeView()
                    .environmentObject(authViewModel)
                    .environmentObject(webSocketService)
                    .onAppear {
                        // Connect to WebSocket when user is authenticated
                        if let userId = authViewModel.currentUser?.id {
                            print("🔌 Connecting to WebSocket with userId: \(userId)")
                            webSocketService.connect(userId: userId)
                        }
                    }
                    .onDisappear {
                        // Disconnect when leaving
                        webSocketService.disconnect()
                    }
            } else {
                AuthenticationView()
                    .environmentObject(authViewModel)
            }
        }
    }
}

#Preview {
    ContentView()
}
