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
    let replyToMessageId: String?
    let replyToContent: String?
    let replyToSenderName: String?
}

/// WebSocket Service - Manages real-time messaging connection
@MainActor
class WebSocketService: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var connectionState: WebSocketState = .disconnected
    @Published var receivedMessages: [MessagePayload] = []
    
    // MARK: - Private Properties
    
    private var webSocketTask: URLSessionWebSocketTask?
    private var userId: String?
    private var reconnectTimer: Timer?
    private var shouldReconnect = true
    private let maxReconnectAttempts = 5
    private var reconnectAttempt = 0
    
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
        let payload: [String: Any] = [
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
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: payload)
            let message = URLSessionWebSocketTask.Message.data(jsonData)
            
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
    
    // MARK: - Private Methods
    
    /// Perform the actual WebSocket connection
    private func performConnection() {
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
                    
                    print("✅ New message received: \(payload.messageId)")
                    print("   From: \(payload.senderName)")
                    print("   Content: \(payload.content)")
                    
                    // Add to received messages
                    receivedMessages.append(payload)
                    
                } else {
                    print("⚠️ Unknown message format: \(json)")
                }
            }
        } catch {
            print("❌ Error parsing message: \(error.localizedDescription)")
        }
    }
    
    /// Handle disconnection and attempt reconnect
    private func handleDisconnection(error: Error) {
        print("🔌 WebSocket disconnected")
        connectionState = .error(error)
        webSocketTask = nil
        
        // Attempt reconnection if enabled
        if shouldReconnect && reconnectAttempt < maxReconnectAttempts {
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
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        print("🔌 WebSocketService deinitialized")
    }
}

