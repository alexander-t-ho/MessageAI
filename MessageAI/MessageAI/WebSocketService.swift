//
//  WebSocketService.swift
//  MessageAI
//
//  Real-time WebSocket connection manager
//  Handles connection, message sending/receiving, and reconnection
//

import Foundation
import Combine

/// WebSocket connection states
enum WebSocketState: Equatable {
    case disconnected
    case connecting
    case connected
    case error(Error)
    
    static func == (lhs: WebSocketState, rhs: WebSocketState) -> Bool {
        switch (lhs, rhs) {
        case (.disconnected, .disconnected),
             (.connecting, .connecting),
             (.connected, .connected):
            return true
        case (.error, .error):
            return true
        default:
            return false
        }
    }
}

/// Received message types
enum WebSocketMessageType {
    case newMessage(MessagePayload)
    case statusUpdate(String, String) // messageId, status
    case error(String)
}

/// Message payload structure
struct MessagePayload: Codable {
    let messageId: String
    let conversationId: String
    let senderId: String
    let senderName: String
    let content: String
    let timestamp: String
    let status: String
    let conversationName: String? // Group chat name or nil for direct messages
    let replyToMessageId: String?
    let replyToContent: String?
    let replyToSenderName: String?
    let isEdited: Bool?
    let editedAt: String?
}

struct DeletePayload: Codable {
    let messageId: String
    let conversationId: String
}

struct EditPayload: Codable {
    let messageId: String
    let conversationId: String
    let newContent: String
    let editedAt: String
}

struct MessageStatusPayload: Codable {
    let messageId: String
    let conversationId: String
    let status: String // delivered | read
    let readerId: String?
    let readerName: String?
    let readAt: String?
    let isGroupChat: Bool?
    // Group chat read receipts - arrays of users who have read
    let readByUserIds: [String]?
    let readByUserNames: [String]?
    let readTimestamps: [String: String]?
}

/// WebSocket Service - Manages real-time messaging connection
@MainActor
class WebSocketService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var connectionState: WebSocketState = .disconnected
    @Published var receivedMessages: [MessagePayload] = []
    @Published var deletedMessages: [DeletePayload] = []
    @Published var editedMessages: [EditPayload] = []
    @Published var statusUpdates: [MessageStatusPayload] = []
    @Published var userPresence: [String: Bool] = [:] // userId -> online
    @Published var simulateOffline: Bool = false // if true, never connect/send
    @Published var catchUpCounter: Int = 0 // increments when catch-up completes
    @Published var typingUsers: [String: String] = [:] // conversationId -> userName who is typing
    private var typingTimers: [String: Timer] = [:] // conversationId -> timer for clearing typing status
    
    // Group chat events
    @Published var groupCreatedEvents: [[String: Any]] = []
    @Published var groupUpdateEvents: [[String: Any]] = []
    @Published var groupMembersAddedEvents: [[String: Any]] = []
    @Published var groupMemberLeftEvents: [[String: Any]] = []
    
    // MARK: - Private Properties
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var userId: String?
    private var reconnectTimer: Timer?
    private var heartbeatTimer: Timer?
    private var shouldReconnect = true
    private let maxReconnectAttempts = 5
    private var reconnectAttempt = 0
    private var seenMessageIds = Set<String>()
    
    // WebSocket URL from config
    private let webSocketURL: String
    
    // MARK: - Initialization
    
    init() {
        // Load WebSocket URL from file or use config
        if let url = try? String(contentsOfFile: "/Users/alexho/MessageAI/websocket-url.txt", encoding: .utf8) {
            self.webSocketURL = url.trimmingCharacters(in: .whitespacesAndNewlines)
        } else {
            // Fallback to hardcoded URL from Config
            self.webSocketURL = Config.webSocketURL
        }
        
        print("💡 WebSocketService initialized with URL: \(webSocketURL)")
    }
    
    // MARK: - Public Methods
    
    /// Connect to WebSocket with user ID
    func connect(userId: String) {
        guard !simulateOffline else {
            print("⛔️ Simulated offline is ON; skipping connect")
            return
        }
        guard connectionState != .connected && connectionState != .connecting else {
            print("⚠️ Already connected or connecting")
            return
        }
        
        self.userId = userId
        self.shouldReconnect = true
        self.reconnectAttempt = 0
        
        performConnection()
    }
    
    /// Disconnect from WebSocket
    func disconnect() {
        print("🔌 Disconnecting from WebSocket...")
        
        // Send offline presence before disconnecting
        sendPresence(isOnline: false)
        
        // Stop heartbeat
        stopHeartbeat()
        
        shouldReconnect = false
        reconnectTimer?.invalidate()
        reconnectTimer = nil
        
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        
        connectionState = .disconnected
        print("✅ Disconnected")
    }
    
    /// Send a message via WebSocket
    func sendMessage(
        messageId: String,
        conversationId: String,
        senderId: String,
        senderName: String,
        recipientId: String,
        recipientIds: [String]? = nil,  // For group chats
        isGroupChat: Bool = false,
        content: String,
        timestamp: Date,
        replyToMessageId: String? = nil,
        replyToContent: String? = nil,
        replyToSenderName: String? = nil
    ) {
        guard connectionState == .connected else {
            print("❌ Cannot send message - not connected")
            return
        }
        
        // Create message payload
        var payload: [String: Any] = [
            "action": "sendMessage",
            "messageId": messageId,
            "conversationId": conversationId,
            "senderId": senderId,
            "senderName": senderName,
            "recipientId": recipientId,
            "content": content,
            "timestamp": ISO8601DateFormatter().string(from: timestamp),
            "replyToMessageId": replyToMessageId as Any,
            "replyToContent": replyToContent as Any,
            "replyToSenderName": replyToSenderName as Any
        ]
        
        // Add group chat specific fields
        if isGroupChat, let recipientIds = recipientIds {
            payload["isGroupChat"] = true
            payload["recipientIds"] = recipientIds
            print("📤 Sending GROUP message to \(recipientIds.count) recipients")
        } else {
            print("📤 Sending DIRECT message to \(recipientId)")
        }
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: payload)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                print("❌ Failed to convert payload to string")
                return
            }
            
            let message = URLSessionWebSocketTask.Message.string(jsonString)
            
            webSocketTask?.send(message) { error in
                Task { @MainActor in
                    if let error = error {
                        print("❌ Error sending message: \(error.localizedDescription)")
                    } else {
                        print("✅ Message sent via WebSocket: \(messageId)")
                    }
                }
            }
        } catch {
            print("❌ Error serializing message: \(error.localizedDescription)")
        }
    }
    
    /// Send a delete-message event via WebSocket
    func sendDeleteMessage(
        messageId: String,
        conversationId: String,
        senderId: String,
        recipientId: String,
        recipientIds: [String]? = nil,
        isGroupChat: Bool = false
    ) {
        guard connectionState == .connected else {
            print("❌ Cannot send delete - not connected")
            return
        }
        var payload: [String: Any] = [
            "action": "deleteMessage",
            "messageId": messageId,
            "conversationId": conversationId,
            "senderId": senderId,
            "recipientId": recipientId,
            "isGroupChat": isGroupChat
        ]
        
        // For group chats, include all recipient IDs
        if let recipientIds = recipientIds {
            payload["recipientIds"] = recipientIds
        }
        do {
            let data = try JSONSerialization.data(withJSONObject: payload)
            guard let json = String(data: data, encoding: .utf8) else { return }
            let message = URLSessionWebSocketTask.Message.string(json)
            webSocketTask?.send(message) { error in
                Task { @MainActor in
                    if let error = error { print("❌ Error sending delete: \(error.localizedDescription)") }
                    else { print("✅ Delete sent via WebSocket: \(messageId)") }
                }
            }
        } catch {
            print("❌ Error serializing delete: \(error.localizedDescription)")
        }
    }
    
    /// Send device token for push notifications
    func sendDeviceToken(userId: String, token: String) {
        guard connectionState == .connected else {
            print("❌ Cannot send device token - not connected")
            return
        }
        
        let payload: [String: Any] = [
            "action": "registerDevice",
            "userId": userId,
            "deviceToken": token,
            "platform": "ios"
        ]
        
        do {
            let data = try JSONSerialization.data(withJSONObject: payload)
            guard let json = String(data: data, encoding: .utf8) else { return }
            let message = URLSessionWebSocketTask.Message.string(json)
            webSocketTask?.send(message) { error in
                if let error = error {
                    print("❌ Error sending device token: \(error)")
                } else {
                    print("✅ Device token sent to backend")
                }
            }
        } catch {
            print("❌ Error serializing device token payload: \(error)")
        }
    }
    
    /// Send edit message notification
    func sendEditMessage(
        messageId: String,
        conversationId: String,
        senderId: String,
        senderName: String,
        newContent: String,
        recipientIds: [String],
        isGroupChat: Bool
    ) {
        print("🔵 sendEditMessage called")
        print("   Connection state: \(connectionState)")
        print("   WebSocket task: \(webSocketTask != nil ? "exists" : "nil")")
        
        guard connectionState == .connected else {
            print("❌ Cannot send edit - not connected (state: \(connectionState))")
            return
        }
        
        guard webSocketTask != nil else {
            print("❌ Cannot send edit - webSocketTask is nil")
            return
        }
        
        let editedAt = ISO8601DateFormatter().string(from: Date())
        
        let payload: [String: Any] = [
            "action": "editMessage",
            "messageId": messageId,
            "conversationId": conversationId,
            "senderId": senderId,
            "senderName": senderName,
            "newContent": newContent,
            "recipientIds": recipientIds,
            "isGroupChat": isGroupChat,
            "editedAt": editedAt
        ]
        
        print("📤 Sending edit for message: \(messageId)")
        print("   New content: \(newContent)")
        print("   Recipients: \(recipientIds)")
        print("   Payload: \(payload)")
        
        do {
            let data = try JSONSerialization.data(withJSONObject: payload)
            guard let json = String(data: data, encoding: .utf8) else { 
                print("❌ Failed to convert data to JSON string")
                return 
            }
            print("   JSON: \(json)")
            let message = URLSessionWebSocketTask.Message.string(json)
            webSocketTask?.send(message) { error in
                Task { @MainActor in
                    if let error = error { 
                        print("❌ Error sending edit: \(error.localizedDescription)")
                        print("   Error details: \(error)")
                    }
                    else { 
                        print("✅ Edit sent via WebSocket: \(messageId)")
                        print("   Successfully sent to API Gateway")
                    }
                }
            }
        } catch {
            print("❌ Error serializing edit: \(error.localizedDescription)")
            print("   Error details: \(error)")
        }
    }
    
    // MARK: - Group Chat Methods
    
    /// Send group created notification
    func sendGroupCreated(
        conversationId: String,
        groupName: String,
        participantIds: [String],
        participantNames: [String],
        createdBy: String,
        createdByName: String
    ) {
        guard connectionState == .connected else {
            print("❌ Cannot send groupCreated - not connected")
            print("   Connection state: \(connectionState)")
            return
        }
        
        print("📤 SENDING GROUP CREATED NOTIFICATION:")
        print("   Group Name: \(groupName)")
        print("   Participants: \(participantIds.count)")
        print("   Participant IDs: \(participantIds)")
        print("   Participant Names: \(participantNames)")
        print("   Conversation ID: \(conversationId)")
        print("   Created By: \(createdByName) (\(createdBy))")
        
        let payload: [String: Any] = [
            "action": "groupCreated",
            "conversationId": conversationId,
            "groupName": groupName,
            "participantIds": participantIds,
            "participantNames": participantNames,
            "createdBy": createdBy,
            "createdByName": createdByName,
            "groupAdmins": [createdBy], // Creator is initial admin
            "createdAt": ISO8601DateFormatter().string(from: Date()),
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        
        print("📤 Payload: \(payload)")
        sendWebSocketPayload(payload)
        print("✅ groupCreated notification sent via WebSocket")
    }
    
    /// Send group update notification
    func sendGroupUpdate(
        conversationId: String,
        groupName: String,
        updatedBy: String,
        updatedByName: String,
        participantIds: [String]
    ) {
        guard connectionState == .connected else { return }
        
        let payload: [String: Any] = [
            "action": "groupUpdate",
            "conversationId": conversationId,
            "groupName": groupName,
            "updatedBy": updatedBy,
            "updatedByName": updatedByName,
            "participantIds": participantIds,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        
        sendWebSocketPayload(payload)
    }
    
    /// Send group members added notification
    func sendGroupMembersAdded(
        conversationId: String,
        newMemberIds: [String],
        newMemberNames: [String],
        addedBy: String,
        addedByName: String,
        allMemberIds: [String]
    ) {
        guard connectionState == .connected else { return }
        
        let payload: [String: Any] = [
            "action": "groupMembersAdded",
            "conversationId": conversationId,
            "newMemberIds": newMemberIds,
            "newMemberNames": newMemberNames,
            "addedBy": addedBy,
            "addedByName": addedByName,
            "allMemberIds": allMemberIds,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        
        sendWebSocketPayload(payload)
    }
    
    /// Send group member left notification
    func sendGroupMemberLeft(
        conversationId: String,
        userId: String,
        userName: String,
        remainingMemberIds: [String]
    ) {
        guard connectionState == .connected else { return }
        
        let payload: [String: Any] = [
            "action": "groupMemberLeft",
            "conversationId": conversationId,
            "userId": userId,
            "userName": userName,
            "remainingMemberIds": remainingMemberIds,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        
        sendWebSocketPayload(payload)
    }
    
    /// Helper method to send WebSocket payload
    private func sendWebSocketPayload(_ payload: [String: Any]) {
        do {
            let data = try JSONSerialization.data(withJSONObject: payload)
            guard let json = String(data: data, encoding: .utf8) else { return }
            let message = URLSessionWebSocketTask.Message.string(json)
            webSocketTask?.send(message) { error in
                if let error = error {
                    print("❌ Error sending payload: \(error.localizedDescription)")
                } else {
                    print("✅ Payload sent successfully")
                }
            }
        } catch {
            print("❌ Error serializing payload: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Private Methods
    
    /// Perform the actual WebSocket connection
    private func performConnection() {
        guard !simulateOffline else {
            print("⛔️ Simulated offline is ON; not performing connection")
            connectionState = .disconnected
            return
        }
        guard let userId = userId else {
            print("❌ Cannot connect - no user ID")
            return
        }
        
        // Construct WebSocket URL with userId query parameter
        guard let url = URL(string: "\(webSocketURL)?userId=\(userId)") else {
            print("❌ Invalid WebSocket URL")
            connectionState = .error(NSError(domain: "WebSocket", code: -1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"]))
            return
        }
        
        print("🔌 Connecting to WebSocket...")
        print("   URL: \(url.absoluteString)")
        
        connectionState = .connecting
        
        // Create WebSocket task
        let session = URLSession(configuration: .default)
        webSocketTask = session.webSocketTask(with: url)
        
        // Start receiving messages
        receiveMessage()
        
        // Resume the task to connect
        webSocketTask?.resume()
        
        connectionState = .connected
        reconnectAttempt = 0
        
        print("✅ Connected to WebSocket")
        
        // Start heartbeat timer (every 30 seconds)
        startHeartbeat()
        
        // Send online presence after a small delay to ensure connection is fully established
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second delay
            print("🚀 Sending initial presence after connection established")
            sendPresence(isOnline: true)
        }
        
        // Announce a lightweight ping so backend can record/refresh latest connection
        let pingPayload: [String: Any] = [
            "action": "ping",
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        if let data = try? JSONSerialization.data(withJSONObject: pingPayload),
           let json = String(data: data, encoding: .utf8) {
            webSocketTask?.send(.string(json)) { error in
                if let error = error { print("❌ ping send error: \(error.localizedDescription)") }
            }
        }

        // Force catch-up on reconnect to ensure missed messages are delivered
        if let uid = self.userId {
            let payload: [String: Any] = [
                "action": "catchUp",
                "userId": uid
            ]
            if let data = try? JSONSerialization.data(withJSONObject: payload),
               let json = String(data: data, encoding: .utf8) {
                webSocketTask?.send(.string(json)) { error in
                    if let error = error { print("❌ catchUp send error: \(error.localizedDescription)") }
                    else { print("📦 catchUp requested for userId: \(uid)") }
                }
            }
        }
    }
    
    /// Receive messages from WebSocket
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                switch result {
                case .success(let message):
                    // Handle received message
                    self.handleReceivedMessage(message)
                    
                    // Continue receiving
                    self.receiveMessage()
                    
                case .failure(let error):
                    print("❌ WebSocket receive error: \(error.localizedDescription)")
                    self.handleDisconnection(error: error)
                }
            }
        }
    }
    
    /// Handle a received WebSocket message
    private func handleReceivedMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .data(let data):
            handleMessageData(data)
            
        case .string(let text):
            if let data = text.data(using: .utf8) {
                handleMessageData(data)
            }
            
        @unknown default:
            print("⚠️ Unknown message type")
        }
    }
    
    /// Parse and handle message data
    private func handleMessageData(_ data: Data) {
        do {
            // Parse JSON
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                print("📥 Received WebSocket message: \(json)")
                
                // Check message type
                if let type = json["type"] as? String, type == "message",
                   let messageData = json["data"] as? [String: Any] {
                    
                    // Parse message payload
                    let payload = try JSONDecoder().decode(MessagePayload.self, from: JSONSerialization.data(withJSONObject: messageData))
                    
                    // De-duplicate by messageId
                    if self.seenMessageIds.contains(payload.messageId) {
                        return
                    }
                    self.seenMessageIds.insert(payload.messageId)
                    
                    print("✅ New message received: \(payload.messageId)")
                    print("   From: \(payload.senderName)")
                    print("   Content: \(payload.content)")
                    
                    // Add to received messages
                    receivedMessages.append(payload)
                    
                } else if let type = json["type"] as? String, type == "messageDeleted",
                          let deleteData = json["data"] as? [String: Any] {
                    let payload = try JSONDecoder().decode(DeletePayload.self, from: JSONSerialization.data(withJSONObject: deleteData))
                    deletedMessages.append(payload)
                } else if let type = json["type"] as? String, type == "messageEdited",
                          let editData = json["data"] as? [String: Any] {
                    print("✏️ Edit event received: \(editData)")
                    let payload = try JSONDecoder().decode(EditPayload.self, from: JSONSerialization.data(withJSONObject: editData))
                    print("✏️ Decoded edit: messageId=\(payload.messageId) newContent=\(payload.newContent)")
                    editedMessages.append(payload)
                } else if let type = json["type"] as? String, type == "messageStatus",
                          let statusData = json["data"] as? [String: Any] {
                    print("📬 Raw status data received: \(statusData)")
                    let payload = try JSONDecoder().decode(MessageStatusPayload.self, from: JSONSerialization.data(withJSONObject: statusData))
                    print("📬 Status update decoded: id=\(payload.messageId) status=\(payload.status) readAt=\(payload.readAt ?? "nil")")
                    statusUpdates.append(payload)
                } else if let type = json["type"] as? String, type == "catchUpComplete" {
                    // Signal catch-up completion
                    catchUpCounter += 1
        } else if let type = json["type"] as? String, type == "presence",
                  let presence = json["data"] as? [String: Any],
                  let userId = presence["userId"] as? String,
                  let isOnline = presence["isOnline"] as? Bool {
            Task { @MainActor in
                // Don't update our own presence
                if userId != self.userId {
                    userPresence[userId] = isOnline
                    print("👥 Presence update received: \(userId) is now \(isOnline ? "ONLINE ✅" : "OFFLINE ⭕")")
                    print("👥 All online users: \(userPresence.filter { $0.value }.keys.joined(separator: ", "))")
                } else {
                    print("👥 Ignoring own presence update for \(userId)")
                }
            }
        } else if let type = json["type"] as? String, type == "typing",
                  let typingData = json["data"] as? [String: Any],
                  let conversationId = typingData["conversationId"] as? String,
                  let senderName = typingData["senderName"] as? String,
                  let isTyping = typingData["isTyping"] as? Bool {
            // Handle typing indicator with persistence
            Task { @MainActor in
                if isTyping {
                    // Cancel any existing timer for this conversation
                    typingTimers[conversationId]?.invalidate()
                    typingTimers[conversationId] = nil
                    
                    // Set typing user
                    typingUsers[conversationId] = senderName
                    print("⌨️ \(senderName) is typing in conversation \(conversationId)")
                    print("⌨️ Current typing users: \(typingUsers)")
                } else {
                    // Keep indicator visible for 1.5 seconds after user stops typing
                    print("⌨️ \(senderName) stopped typing, keeping indicator for 1.5 seconds")
                    
                    // Cancel any existing timer
                    typingTimers[conversationId]?.invalidate()
                    
                    // Start new timer to clear after 1.5 seconds
                    typingTimers[conversationId] = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: false) { [weak self] _ in
                        Task { @MainActor [weak self] in
                            self?.typingUsers.removeValue(forKey: conversationId)
                            self?.typingTimers[conversationId] = nil
                            print("⌨️ Typing indicator cleared for conversation \(conversationId)")
                            print("⌨️ Current typing users: \(self?.typingUsers ?? [:])")
                        }
                    }
                }
            }
            } else if let type = json["type"] as? String, type == "groupCreated",
                      let groupData = json["data"] as? [String: Any] {
                // Handle group creation notification
                Task { @MainActor in
                    print("👥👥👥 GROUP CREATED NOTIFICATION RECEIVED 👥👥👥")
                    print("   Group Name: \(groupData["groupName"] ?? "unknown")")
                    print("   Conversation ID: \(groupData["conversationId"] ?? "unknown")")
                    print("   Participants: \(groupData["participantIds"] ?? [])")
                    groupCreatedEvents.append(groupData)
                    print("✅ Added to groupCreatedEvents (count: \(groupCreatedEvents.count))")
                }
            } else if let type = json["type"] as? String, type == "groupUpdate",
                  let updateData = json["data"] as? [String: Any] {
            // Handle group update notification
            Task { @MainActor in
                print("👥 Group update notification received")
                groupUpdateEvents.append(updateData)
            }
        } else if let type = json["type"] as? String, type == "groupMembersAdded",
                  let memberData = json["data"] as? [String: Any] {
            // Handle group members added notification
            Task { @MainActor in
                print("👥 Group members added notification received")
                groupMembersAddedEvents.append(memberData)
            }
        } else if let type = json["type"] as? String, type == "groupMemberLeft",
                  let memberData = json["data"] as? [String: Any] {
            // Handle group member left notification
            Task { @MainActor in
                print("👥 Group member left notification received")
                groupMemberLeftEvents.append(memberData)
            }
        } else {
                    print("⚠️ Unknown message format: \(json)")
                }
            }
        } catch {
            print("❌ Error parsing message: \(error.localizedDescription)")
        }
    }

    // Send markRead for a batch of messages in a conversation
    func sendMarkRead(conversationId: String, readerId: String, readerName: String, messageReads: [[String: String]], isGroupChat: Bool = false) {
        guard connectionState == .connected else { return }
        guard !messageReads.isEmpty else { return }
        let messageIds = messageReads.compactMap { $0["messageId"] }
        let payload: [String: Any] = [
            "action": "markRead",
            "conversationId": conversationId,
            "readerId": readerId,
            "readerName": readerName,
            "reads": messageReads,
            "messageIds": messageIds,
            "readAt": ISO8601DateFormatter().string(from: Date()),
            "isGroupChat": isGroupChat
        ]
        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let json = String(data: data, encoding: .utf8) {
            print("📤 Sending markRead for \(messageReads.count) messages (ids=\(messageIds)) in convo \(conversationId)")
            if isGroupChat {
                print("   👥 Group chat - tracking read by \(readerName)")
            }
            webSocketTask?.send(.string(json)) { error in
                if let error = error { print("❌ markRead send error: \(error.localizedDescription)") }
            }
        }
    }

    // Send typing indicator
    func sendTyping(conversationId: String, senderId: String, senderName: String, recipientId: String, isTyping: Bool) {
        guard connectionState == .connected else { return }
        
        let payload: [String: Any] = [
            "action": "typing",
            "conversationId": conversationId,
            "senderId": senderId,
            "senderName": senderName,
            "recipientId": recipientId,
            "isTyping": isTyping
        ]
        
        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let json = String(data: data, encoding: .utf8) {
            webSocketTask?.send(.string(json)) { error in
                if let error = error { 
                    print("❌ Typing send error: \(error.localizedDescription)")
                }
            }
        }
    }
    
    // Presence broadcast
    func sendPresence(isOnline: Bool) {
        // Re-enable presence with proper error handling
        guard connectionState == .connected else { return }
        guard let uid = userId else { return }
        
        let payload: [String: Any] = [
            "action": "presenceUpdate",
            "userId": uid,
            "isOnline": isOnline
        ]
        
        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let json = String(data: data, encoding: .utf8) {
            print("📡 Sending presence update: userId=\(uid), isOnline=\(isOnline)")
            webSocketTask?.send(.string(json)) { error in
                if let error = error { 
                    print("❌ Presence send error: \(error.localizedDescription)")
                } else {
                    print("✅ Presence sent successfully: userId=\(uid), isOnline=\(isOnline)")
                }
            }
        }
    }
    
    // Start heartbeat timer
    private func startHeartbeat() {
        stopHeartbeat() // Clear any existing timer
        heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.sendHeartbeat()
            }
        }
        print("💓 Heartbeat started (every 30 seconds)")
    }
    
    // Stop heartbeat timer
    private func stopHeartbeat() {
        heartbeatTimer?.invalidate()
        heartbeatTimer = nil
        print("💓 Heartbeat stopped")
    }
    
    // Send heartbeat
    private func sendHeartbeat() {
        guard connectionState == .connected else { return }
        guard let uid = userId else { return }
        
        let payload: [String: Any] = [
            "action": "ping",
            "userId": uid,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        
        if let data = try? JSONSerialization.data(withJSONObject: payload),
           let json = String(data: data, encoding: .utf8) {
            webSocketTask?.send(.string(json)) { error in
                if let error = error {
                    print("❌ Heartbeat error: \(error.localizedDescription)")
                } else {
                    print("💓 Heartbeat sent")
                    // Also send presence with heartbeat to ensure online status is maintained
                    Task { @MainActor [weak self] in
                        self?.sendPresence(isOnline: true)
                    }
                }
            }
        }
    }
    
    /// Handle disconnection and attempt reconnect
    private func handleDisconnection(error: Error) {
        print("🔌 WebSocket disconnected")
        connectionState = .error(error)
        webSocketTask = nil
        
        // Stop heartbeat on disconnect
        stopHeartbeat()
        
        // Send offline presence
        sendPresence(isOnline: false)
        
        // Attempt reconnection if enabled
        if !simulateOffline && shouldReconnect && reconnectAttempt < maxReconnectAttempts {
            reconnectAttempt += 1
            let delay = min(pow(2.0, Double(reconnectAttempt)), 30.0) // Exponential backoff, max 30s
            
            print("🔄 Reconnecting in \(Int(delay)) seconds (attempt \(reconnectAttempt)/\(maxReconnectAttempts))...")
            
            reconnectTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.performConnection()
                }
            }
        } else if reconnectAttempt >= maxReconnectAttempts {
            print("❌ Max reconnection attempts reached")
            connectionState = .disconnected
        }
    }
    
    // MARK: - Lifecycle
    
    deinit {
        shouldReconnect = false
        reconnectTimer?.invalidate()
        heartbeatTimer?.invalidate()
        // Clean up typing timers
        for timer in typingTimers.values {
            timer.invalidate()
        }
        typingTimers.removeAll()
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        print("🔌 WebSocketService deinitialized")
    }
}

