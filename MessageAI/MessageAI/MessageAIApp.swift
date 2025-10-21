//
//  MessageAIApp.swift
//  MessageAI
//
//  Created by Alex Ho on 10/20/25.
//

import SwiftUI
import SwiftData

@main
struct MessageAIApp: App {
    // Configure SwiftData container
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            MessageData.self,
            ConversationData.self,
            ContactData.self,
            DraftData.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false
        )
        
        do {
            return try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
