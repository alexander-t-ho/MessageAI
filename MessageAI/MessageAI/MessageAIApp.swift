//
//  MessageAIApp.swift
//  MessageAI
//
//  Created by Alex Ho on 10/20/25.
//

import SwiftUI
import SwiftData
import UIKit

// App Delegate for handling push notifications
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Initialize notification manager
        _ = NotificationManager.shared
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        NotificationManager.shared.registerDeviceToken(deviceToken)
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        NotificationManager.shared.registrationFailed(error)
    }
}

@main
struct MessageAIApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var notificationManager = NotificationManager.shared
    @Environment(\.scenePhase) var scenePhase
    
    init() {
        // EXTREMELY LOUD console output - THIS RUNS FIRST!
        print("\n\n")
        print("=" .appending(String(repeating: "=", count: 60)))
        print("🚨🚨🚨 MessageAI APP IS STARTING! 🚨🚨🚨")
        print("🚨🚨🚨 IF YOU SEE THIS, CONSOLE WORKS! 🚨🚨🚨")
        print("=" .appending(String(repeating: "=", count: 60)))
        print("\n\n")
    }
    
    // Configure SwiftData container
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            MessageData.self,
            ConversationData.self,
            ContactData.self,
            DraftData.self,
            PendingMessageData.self,
            UserCustomizationData.self
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
            // If migration fails during development, try to recreate container
            print("⚠️ ModelContainer creation failed: \(error)")
            print("🔄 Attempting to recreate database...")
            
            // Delete old database files
            let url = modelConfiguration.url
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: url.deletingPathExtension().appendingPathExtension("sqlite-shm"))
            try? FileManager.default.removeItem(at: url.deletingPathExtension().appendingPathExtension("sqlite-wal"))
            
            // Try creating container again
            do {
                let newContainer = try ModelContainer(
                    for: schema,
                    configurations: [modelConfiguration]
                )
                print("✅ Database recreated successfully!")
                return newContainer
            } catch {
                fatalError("❌ Could not create ModelContainer even after cleanup: \(error)")
            }
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onChange(of: scenePhase) { oldPhase, newPhase in
                    switch newPhase {
                    case .active:
                        print("📱 App became ACTIVE")
                        // Request notification permissions if not granted
                        NotificationManager.shared.requestNotificationPermission()
                    case .inactive:
                        print("📱 App became INACTIVE")
                    case .background:
                        print("📱 App entered BACKGROUND")
                        // Note: WebSocket will remain connected for ~30 seconds
                        // Local notifications can still be triggered during this time
                    @unknown default:
                        print("📱 Unknown scene phase")
                    }
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
