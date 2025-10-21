//
//  DatabaseService.swift
//  MessageAI
//
//  Service for local database operations
//

import Foundation
import SwiftData

@MainActor
class DatabaseService {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    // MARK: - Message Operations
    
    /// Save a new message to local database
    func saveMessage(_ message: MessageData) throws {
        modelContext.insert(message)
        try modelContext.save()
        print("✅ Message saved locally: \(message.id)")
    }
    
    /// Fetch all messages for a conversation
    func fetchMessages(for conversationId: String) throws -> [MessageData] {
        let predicate = #Predicate<MessageData> { message in
            message.conversationId == conversationId
        }
        let descriptor = FetchDescriptor<MessageData>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    /// Update message status (e.g., sent, delivered, read)
    func updateMessageStatus(messageId: String, status: String) throws {
        let predicate = #Predicate<MessageData> { message in
            message.id == messageId
        }
        let descriptor = FetchDescriptor<MessageData>(predicate: predicate)
        
        if let message = try modelContext.fetch(descriptor).first {
            message.status = status
            try modelContext.save()
            print("✅ Message status updated: \(messageId) -> \(status)")
        }
    }
    
    /// Mark message as read
    func markMessageAsRead(messageId: String) throws {
        let predicate = #Predicate<MessageData> { message in
            message.id == messageId
        }
        let descriptor = FetchDescriptor<MessageData>(predicate: predicate)
        
        if let message = try modelContext.fetch(descriptor).first {
            message.isRead = true
            message.status = "read"
            try modelContext.save()
            print("✅ Message marked as read: \(messageId)")
        }
    }
    
    /// Delete a message
    func deleteMessage(messageId: String) throws {
        let predicate = #Predicate<MessageData> { message in
            message.id == messageId
        }
        let descriptor = FetchDescriptor<MessageData>(predicate: predicate)
        
        if let message = try modelContext.fetch(descriptor).first {
            modelContext.delete(message)
            try modelContext.save()
            print("🗑️ Message deleted: \(messageId)")
        }
    }
    
    // MARK: - Conversation Operations
    
    /// Save a new conversation
    func saveConversation(_ conversation: ConversationData) throws {
        modelContext.insert(conversation)
        try modelContext.save()
        print("✅ Conversation saved locally: \(conversation.id)")
    }
    
    /// Fetch all conversations
    func fetchConversations() throws -> [ConversationData] {
        let descriptor = FetchDescriptor<ConversationData>(
            sortBy: [SortDescriptor(\.lastMessageTime, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    /// Fetch a specific conversation
    func fetchConversation(id: String) throws -> ConversationData? {
        let predicate = #Predicate<ConversationData> { conversation in
            conversation.id == id
        }
        let descriptor = FetchDescriptor<ConversationData>(predicate: predicate)
        return try modelContext.fetch(descriptor).first
    }
    
    /// Update conversation last message
    func updateConversationLastMessage(
        conversationId: String,
        lastMessage: String,
        timestamp: Date
    ) throws {
        if let conversation = try fetchConversation(id: conversationId) {
            conversation.lastMessage = lastMessage
            conversation.lastMessageTime = timestamp
            try modelContext.save()
            print("✅ Conversation updated: \(conversationId)")
        }
    }
    
    /// Increment unread count
    func incrementUnreadCount(conversationId: String) throws {
        if let conversation = try fetchConversation(id: conversationId) {
            conversation.unreadCount += 1
            try modelContext.save()
            print("✅ Unread count incremented: \(conversationId)")
        }
    }
    
    /// Reset unread count
    func resetUnreadCount(conversationId: String) throws {
        if let conversation = try fetchConversation(id: conversationId) {
            conversation.unreadCount = 0
            try modelContext.save()
            print("✅ Unread count reset: \(conversationId)")
        }
    }
    
    /// Delete a conversation and all its messages
    func deleteConversation(conversationId: String) throws {
        // Delete all messages in conversation
        let messages = try fetchMessages(for: conversationId)
        for message in messages {
            modelContext.delete(message)
        }
        
        // Delete conversation
        if let conversation = try fetchConversation(id: conversationId) {
            modelContext.delete(conversation)
        }
        
        try modelContext.save()
        print("🗑️ Conversation and messages deleted: \(conversationId)")
    }
    
    // MARK: - Contact Operations
    
    /// Save a contact
    func saveContact(_ contact: ContactData) throws {
        modelContext.insert(contact)
        try modelContext.save()
        print("✅ Contact saved locally: \(contact.name)")
    }
    
    /// Fetch all contacts
    func fetchContacts() throws -> [ContactData] {
        let descriptor = FetchDescriptor<ContactData>(
            sortBy: [SortDescriptor(\.name, order: .forward)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    /// Fetch a specific contact
    func fetchContact(id: String) throws -> ContactData? {
        let predicate = #Predicate<ContactData> { contact in
            contact.id == id
        }
        let descriptor = FetchDescriptor<ContactData>(predicate: predicate)
        return try modelContext.fetch(descriptor).first
    }
    
    /// Update contact online status
    func updateContactStatus(contactId: String, isOnline: Bool, lastSeen: Date? = nil) throws {
        if let contact = try fetchContact(id: contactId) {
            contact.isOnline = isOnline
            if let lastSeen = lastSeen {
                contact.lastSeen = lastSeen
            }
            try modelContext.save()
            print("✅ Contact status updated: \(contactId)")
        }
    }
    
    // MARK: - Utility Methods
    
    /// Get total message count
    func getTotalMessageCount() throws -> Int {
        let descriptor = FetchDescriptor<MessageData>()
        return try modelContext.fetchCount(descriptor)
    }
    
    /// Get total conversation count
    func getTotalConversationCount() throws -> Int {
        let descriptor = FetchDescriptor<ConversationData>()
        return try modelContext.fetchCount(descriptor)
    }
    
    /// Clear all data (for testing/logout)
    func clearAllData() throws {
        // Delete all messages
        let messages = try modelContext.fetch(FetchDescriptor<MessageData>())
        for message in messages {
            modelContext.delete(message)
        }
        
        // Delete all conversations
        let conversations = try modelContext.fetch(FetchDescriptor<ConversationData>())
        for conversation in conversations {
            modelContext.delete(conversation)
        }
        
        // Delete all contacts
        let contacts = try modelContext.fetch(FetchDescriptor<ContactData>())
        for contact in contacts {
            modelContext.delete(contact)
        }
        
        try modelContext.save()
        print("🗑️ All local data cleared")
    }
}

