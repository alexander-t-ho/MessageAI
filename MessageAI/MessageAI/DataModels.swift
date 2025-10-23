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
    var readAt: Date?
    // NOTE: isSentByCurrentUser is NO LONGER stored - it's computed on the fly!
    // This is because the SAME message should appear differently for sender vs receiver
    
    // Reply feature
    var replyToMessageId: String? // ID of message being replied to
    var replyToContent: String? // Preview of message being replied to
    var replyToSenderName: String? // Name of person who sent the original message
    
    // Delete feature
    var isDeleted: Bool // True if message was deleted
    
    // Emphasis feature (like/reaction)
    var isEmphasized: Bool // True if message has emphasis
    var emphasizedBy: [String] // Array of user IDs who emphasized this message
    
    init(
        id: String = UUID().uuidString,
        conversationId: String,
        senderId: String,
        senderName: String,
        content: String,
        timestamp: Date = Date(),
        status: String = "sending",
        isRead: Bool = false,
        readAt: Date? = nil,
        replyToMessageId: String? = nil,
        replyToContent: String? = nil,
        replyToSenderName: String? = nil,
        isDeleted: Bool = false,
        isEmphasized: Bool = false,
        emphasizedBy: [String] = []
    ) {
        self.id = id
        self.conversationId = conversationId
        self.senderId = senderId
        self.senderName = senderName
        self.content = content
        self.timestamp = timestamp
        self.status = status
        self.isRead = isRead
        self.readAt = readAt
        // No longer setting isSentByCurrentUser here!
        self.replyToMessageId = replyToMessageId
        self.replyToContent = replyToContent
        self.replyToSenderName = replyToSenderName
        self.isDeleted = isDeleted
        self.isEmphasized = isEmphasized
        self.emphasizedBy = emphasizedBy
    }
    
    // Helper method to check if message was sent by a specific user
    func isSentBy(userId: String) -> Bool {
        return senderId == userId
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

// MARK: - Draft Message Model
@Model
final class DraftData {
    @Attribute(.unique) var conversationId: String
    var draftContent: String
    var lastUpdated: Date
    
    init(
        conversationId: String,
        draftContent: String,
        lastUpdated: Date = Date()
    ) {
        self.conversationId = conversationId
        self.draftContent = draftContent
        self.lastUpdated = lastUpdated
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

// MARK: - Pending (Queued) Outgoing Message
@Model
final class PendingMessageData {
    @Attribute(.unique) var id: String
    var messageId: String
    var conversationId: String
    var senderId: String
    var senderName: String
    var recipientId: String
    var content: String
    var timestamp: Date
    var retryCount: Int
    var lastError: String?
    
    init(
        id: String = UUID().uuidString,
        messageId: String,
        conversationId: String,
        senderId: String,
        senderName: String,
        recipientId: String,
        content: String,
        timestamp: Date = Date(),
        retryCount: Int = 0,
        lastError: String? = nil
    ) {
        self.id = id
        self.messageId = messageId
        self.conversationId = conversationId
        self.senderId = senderId
        self.senderName = senderName
        self.recipientId = recipientId
        self.content = content
        self.timestamp = timestamp
        self.retryCount = retryCount
        self.lastError = lastError
    }
}

