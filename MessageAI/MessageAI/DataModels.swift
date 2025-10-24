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
    
    // Group chat read receipts - track who has read the message
    var readByUserIds: [String] // User IDs who have read this message
    var readByUserNames: [String] // Names of users who have read this message
    var readTimestamps: [String: Date] // Map of userId to read timestamp
    
    // Reply feature
    var replyToMessageId: String? // ID of message being replied to
    var replyToContent: String? // Preview of message being replied to
    var replyToSenderName: String? // Name of person who sent the original message
    
    // Delete feature
    var isDeleted: Bool // True if message was deleted
    
    // Edit feature
    var isEdited: Bool = false // True if message was edited  
    var editedAt: Date? // When the message was last edited
    
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
        readByUserIds: [String] = [],
        readByUserNames: [String] = [],
        readTimestamps: [String: Date] = [:],
        replyToMessageId: String? = nil,
        replyToContent: String? = nil,
        replyToSenderName: String? = nil,
        isDeleted: Bool = false,
        isEdited: Bool = false,
        editedAt: Date? = nil,
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
        self.readByUserIds = readByUserIds
        self.readByUserNames = readByUserNames
        self.readTimestamps = readTimestamps
        // No longer setting isSentByCurrentUser here!
        self.replyToMessageId = replyToMessageId
        self.replyToContent = replyToContent
        self.replyToSenderName = replyToSenderName
        self.isDeleted = isDeleted
        self.isEdited = isEdited
        self.editedAt = editedAt
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
    var isDeleted: Bool = false // True if conversation was deleted by user
    
    // Group-specific fields
    var createdBy: String? // User ID who created the group
    var createdByName: String? // Name of user who created the group
    var createdAt: Date? // When the group was created
    var groupAdmins: [String] // User IDs who can manage the group
    var lastUpdatedBy: String? // User ID who last updated group info
    var lastUpdatedAt: Date? // When the group info was last updated
    
    init(
        id: String = UUID().uuidString,
        participantIds: [String],
        participantNames: [String],
        isGroupChat: Bool = false,
        groupName: String? = nil,
        lastMessage: String? = nil,
        lastMessageTime: Date? = nil,
        unreadCount: Int = 0,
        isDeleted: Bool = false,
        createdBy: String? = nil,
        createdByName: String? = nil,
        createdAt: Date? = nil,
        groupAdmins: [String] = [],
        lastUpdatedBy: String? = nil,
        lastUpdatedAt: Date? = nil
    ) {
        self.id = id
        self.participantIds = participantIds
        self.participantNames = participantNames
        self.isGroupChat = isGroupChat
        self.groupName = groupName
        self.lastMessage = lastMessage
        self.lastMessageTime = lastMessageTime
        self.unreadCount = unreadCount
        self.isDeleted = isDeleted
        self.createdBy = createdBy
        self.createdByName = createdByName
        self.createdAt = createdAt
        self.groupAdmins = groupAdmins
        self.lastUpdatedBy = lastUpdatedBy
        self.lastUpdatedAt = lastUpdatedAt
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

