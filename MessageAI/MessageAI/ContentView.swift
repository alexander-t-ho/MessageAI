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
                    // Reset in-memory dedupe on foreground so session remains fresh
                    .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                        print("🔄 App to foreground - ready to receive messages")
                    }
                    .onAppear {
                        // Connect to WebSocket when user is authenticated
                        if let userId = authViewModel.currentUser?.id {
                            // Reload user preferences for this user
                            UserPreferences.shared.reloadForCurrentUser()
                            print("🔄 Reloaded preferences for user: \(userId)")
                            
                            if webSocketService.simulateOffline {
                                print("⛔️ Simulated offline is ON; skipping initial WebSocket connect")
                            } else {
                                print("🔌 Connecting to WebSocket with userId: \(userId)")
                                webSocketService.connect(userId: userId)
                            }
                            
                            // Request notification permission after authentication
                            NotificationManager.shared.requestNotificationPermission()
                            
                            // Send stored device token if available (after WebSocket connects)
                            NotificationManager.shared.sendStoredTokenIfAvailable(webSocketService: webSocketService)
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
