//
//  MessageAIApp.swift
//  MessageAI
//
//  Created on 10/20/2025.
//

import SwiftUI
import SwiftData
import FirebaseCore

@main
struct MessageAIApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    
    init() {
        // Configure Firebase
        FirebaseApp.configure()
    }
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            CachedMessage.self,
            CachedChat.self,
            CachedUser.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .modelContainer(sharedModelContainer)
        }
    }
}

