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
    
    init() {
        // LOUD console output to verify console is working
        print("🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨")
        print("🚨 MESSAGEAI APP STARTED - CONSOLE IS WORKING! 🚨")
        print("🚨 IF YOU SEE THIS, YOUR CONSOLE IS OPEN! 🚨")
        print("🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨🚨")
    }
    
    var body: some View {
        let _ = print("👁️ ContentView body rendered")
        return Group {
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
