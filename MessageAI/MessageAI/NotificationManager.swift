//
//  NotificationManager.swift
//  MessageAI
//
//  Manages push notifications and device tokens
//

import SwiftUI
import Combine
import UserNotifications
import UIKit

class NotificationManager: NSObject, ObservableObject {
    static let shared = NotificationManager()
    
    @Published var hasNotificationPermission = false
    @Published var deviceToken: String?
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
        checkNotificationPermission()
    }
    
    // Request notification permission
    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                self.hasNotificationPermission = granted
                if granted {
                    print("✅ Push notification permission granted")
                    self.registerForPushNotifications()
                } else {
                    print("❌ Push notification permission denied")
                }
                
                if let error = error {
                    print("❌ Error requesting notification permission: \(error)")
                }
            }
        }
    }
    
    // Check current notification permission status
    func checkNotificationPermission() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.hasNotificationPermission = settings.authorizationStatus == .authorized
                
                if self.hasNotificationPermission {
                    self.registerForPushNotifications()
                }
            }
        }
    }
    
    // Register for remote notifications
    private func registerForPushNotifications() {
        DispatchQueue.main.async {
            UIApplication.shared.registerForRemoteNotifications()
        }
    }
    
    // Handle device token registration
    func registerDeviceToken(_ deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("📱 Device Token: \(tokenString)")
        
        DispatchQueue.main.async {
            self.deviceToken = tokenString
            // Token will be sent when WebSocket connects
            print("📱 Device token stored, will send when WebSocket is available")
        }
    }
    
    // Send stored device token to backend when WebSocket becomes available
    func sendStoredTokenIfAvailable(webSocketService: WebSocketService) {
        if let token = self.deviceToken,
           let userId = UserDefaults.standard.string(forKey: "userId") {
            webSocketService.sendDeviceToken(userId: userId, token: token)
            print("✅ Sent stored device token to backend")
        }
    }
    
    // Send device token to backend
    func sendTokenToBackend(_ token: String, webSocketService: WebSocketService? = nil) {
        // Get current user ID
        guard let userId = UserDefaults.standard.string(forKey: "userId") else {
            print("❌ No user ID found, cannot register device token")
            return
        }
        
        // Store token for later sending if WebSocket not available
        self.deviceToken = token
        
        // Send token via WebSocket if available
        if let webSocketService = webSocketService {
            webSocketService.sendDeviceToken(userId: userId, token: token)
        } else {
            print("⚠️ WebSocket service not available, token stored for later sending")
        }
    }
    
    // Handle notification registration failure
    func registrationFailed(_ error: Error) {
        print("❌ Failed to register for push notifications: \(error)")
    }
    
    // Clear badge count
    func clearBadgeCount() {
        if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(0) { error in
                if let error = error {
                    print("❌ Error clearing badge count: \(error)")
                }
            }
        } else {
            DispatchQueue.main.async {
                UIApplication.shared.applicationIconBadgeNumber = 0
            }
        }
    }
    
    // Set badge count
    func setBadgeCount(_ count: Int) {
        if #available(iOS 16.0, *) {
            UNUserNotificationCenter.current().setBadgeCount(count) { error in
                if let error = error {
                    print("❌ Error setting badge count: \(error)")
                }
            }
        } else {
            DispatchQueue.main.async {
                UIApplication.shared.applicationIconBadgeNumber = count
            }
        }
    }
}

// MARK: - UNUserNotificationCenterDelegate
extension NotificationManager: UNUserNotificationCenterDelegate {
    
    // Handle notification when app is in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        print("📬 Received notification in foreground: \(notification.request.content.body)")
        
        // Update badge count if specified in notification
        if let badgeNumber = notification.request.content.badge {
            setBadgeCount(badgeNumber.intValue)
        }
        
        // Show notification banner even when app is in foreground
        completionHandler([.banner, .sound, .badge, .list])
    }
    
    // Handle notification tap
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        
        let userInfo = response.notification.request.content.userInfo
        print("📱 User tapped notification: \(userInfo)")
        
        // Extract conversation ID from notification
        if let conversationId = userInfo["conversationId"] as? String {
            // Post notification to open specific conversation
            NotificationCenter.default.post(
                name: Notification.Name("OpenConversation"),
                object: nil,
                userInfo: ["conversationId": conversationId]
            )
        }
        
        completionHandler()
    }
}
