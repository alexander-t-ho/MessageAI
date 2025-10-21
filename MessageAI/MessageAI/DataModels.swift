//
//  DataModels.swift
//  MessageAI
//
//  SwiftData models for local persistence
//

import Foundation
import SwiftData

// MARK: - Message Model
@Model
final class MessageData {
    @Attribute(.unique) var id: String
    var conversationId: String
    var senderId: String
    var senderName: String
    var content: String
    var timestamp: Date
    var status: String // "sending", "sent", "delivered", "read", "failed"
    var isRead: Bool
    var isSentByCurrentUser: Bool
    
    init(
        id: String = UUID().uuidString,
        conversationId: String,
        senderId: String,
        senderName: String,
        content: String,
        timestamp: Date = Date(),
        status: String = "sending",
        isRead: Bool = false,
        isSentByCurrentUser: Bool
    ) {
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.senderName = senderName
        self.content = content
        self.timestamp = timestamp
        self.status = status
        self.isRead = isRead
        self.isSentByCurrentUser = isSentByCurrentUser
    }
}

// MARK: - Conversation Model
@Model
final class ConversationData {
    @Attribute(.unique) var id: String
    var participantIds: [String]
    var participantNames: [String]
    var isGroupChat: Bool
    var groupName: String?
    var lastMessage: String?
    var lastMessageTime: Date?
    var unreadCount: Int
    
    init(
        id: String = UUID().uuidString,
        participantIds: [String],
        participantNames: [String],
        isGroupChat: Bool = false,
        groupName: String? = nil,
        lastMessage: String? = nil,
        lastMessageTime: Date? = nil,
        unreadCount: Int = 0
    ) {
        self.id = id
        self.participantIds = participantIds
        self.participantNames = participantNames
        self.isGroupChat = isGroupChat
        self.groupName = groupName
        self.lastMessage = lastMessage
        self.lastMessageTime = lastMessageTime
        self.unreadCount = unreadCount
    }
}

// MARK: - Contact Model
@Model
final class ContactData {
    @Attribute(.unique) var id: String
    var email: String
    var name: String
    var isOnline: Bool
    var lastSeen: Date?
    
    init(
        id: String,
        email: String,
        name: String,
        isOnline: Bool = false,
        lastSeen: Date? = nil
    ) {
        self.id = id
        self.email = email
        self.name = name
        self.isOnline = isOnline
        self.lastSeen = lastSeen
    }
}

// MARK: - Message Status Enum
enum MessageStatus: String, Codable {
    case sending = "sending"
    case sent = "sent"
    case delivered = "delivered"
    case read = "read"
    case failed = "failed"
}

