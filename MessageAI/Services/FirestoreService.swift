//
//  FirestoreService.swift
//  MessageAI
//
//  Created on 10/20/2025.
//

import Foundation
import FirebaseFirestore
import FirebaseAuth

class FirestoreService {
    private let db = Firestore.firestore()
    
    // MARK: - User Operations
    
    func fetchUsers() async throws -> [User] {
        let snapshot = try await db.collection("users").getDocuments()
        return snapshot.documents.compactMap { doc in
            try? doc.data(as: User.self)
        }
    }
    
    func observeUsers(completion: @escaping ([User]) -> Void) -> ListenerRegistration {
        return db.collection("users").addSnapshotListener { snapshot, error in
            guard let documents = snapshot?.documents else { return }
            let users = documents.compactMap { try? $0.data(as: User.self) }
            completion(users)
        }
    }
    
    // MARK: - Chat Operations
    
    func createOrGetChat(with userId: String) async throws -> String {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "AuthError", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        let chatId = generateChatId(userId1: currentUserId, userId2: userId)
        let chatRef = db.collection("chats").document(chatId)
        
        let snapshot = try await chatRef.getDocument()
        
        if !snapshot.exists {
            // Create new chat
            let currentUser = try await db.collection("users").document(currentUserId).getDocument().data(as: User.self)
            let otherUser = try await db.collection("users").document(userId).getDocument().data(as: User.self)
            
            let chat = Chat(
                id: chatId,
                participants: [currentUserId, userId].sorted(),
                participantNames: [
                    currentUserId: currentUser.displayName,
                    userId: otherUser.displayName
                ],
                lastMessage: "",
                lastMessageTime: Date(),
                lastMessageSenderId: nil,
                unreadCount: [:],
                typing: [:]
            )
            
            try chatRef.setData(from: chat)
        }
        
        return chatId
    }
    
    func observeChats(userId: String, completion: @escaping ([Chat]) -> Void) -> ListenerRegistration {
        return db.collection("chats")
            .whereField("participants", arrayContains: userId)
            .order(by: "lastMessageTime", descending: true)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else { return }
                let chats = documents.compactMap { try? $0.data(as: Chat.self) }
                completion(chats)
            }
    }
    
    func updateTypingStatus(chatId: String, userId: String, isTyping: Bool) async throws {
        let chatRef = db.collection("chats").document(chatId)
        
        if isTyping {
            try await chatRef.updateData([
                "typing.\(userId)": Timestamp(date: Date())
            ])
        } else {
            try await chatRef.updateData([
                "typing.\(userId)": FieldValue.delete()
            ])
        }
    }
    
    // MARK: - Message Operations
    
    func sendMessage(chatId: String, text: String, type: MessageType = .text, imageUrl: String? = nil) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let currentUser = try await db.collection("users").document(currentUserId).getDocument().data(as: User.self)
        
        let message = Message(
            id: UUID().uuidString,
            chatId: chatId,
            groupId: nil,
            senderId: currentUserId,
            senderName: currentUser.displayName,
            text: text,
            type: type,
            imageUrl: imageUrl,
            timestamp: Date(),
            status: .sent
        )
        
        let messageRef = db.collection("chats").document(chatId).collection("messages").document(message.id!)
        try messageRef.setData(from: message)
        
        // Update chat's last message
        try await db.collection("chats").document(chatId).updateData([
            "lastMessage": text,
            "lastMessageTime": Timestamp(date: Date()),
            "lastMessageSenderId": currentUserId
        ])
    }
    
    func observeMessages(chatId: String, completion: @escaping ([Message]) -> Void) -> ListenerRegistration {
        return db.collection("chats").document(chatId).collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else { return }
                let messages = documents.compactMap { try? $0.data(as: Message.self) }
                completion(messages)
            }
    }
    
    func markMessagesAsRead(chatId: String, messageIds: [String]) async throws {
        let batch = db.batch()
        
        for messageId in messageIds {
            let messageRef = db.collection("chats").document(chatId).collection("messages").document(messageId)
            batch.updateData(["status": MessageStatus.read.rawValue], forDocument: messageRef)
        }
        
        try await batch.commit()
    }
    
    // MARK: - Group Operations
    
    func createGroup(name: String, participantIds: [String]) async throws -> String {
        guard let currentUserId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "AuthError", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }
        
        // Fetch participant names
        var participantNames: [String: String] = [:]
        for userId in participantIds {
            let user = try await db.collection("users").document(userId).getDocument().data(as: User.self)
            participantNames[userId] = user.displayName
        }
        
        let group = Group(
            id: UUID().uuidString,
            name: name,
            participants: participantIds,
            participantNames: participantNames,
            createdBy: currentUserId,
            createdAt: Date(),
            lastMessage: nil,
            lastMessageTime: nil,
            groupImageUrl: nil
        )
        
        let groupRef = db.collection("groups").document(group.id!)
        try groupRef.setData(from: group)
        
        return group.id!
    }
    
    func observeGroups(userId: String, completion: @escaping ([Group]) -> Void) -> ListenerRegistration {
        return db.collection("groups")
            .whereField("participants", arrayContains: userId)
            .order(by: "createdAt", descending: true)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else { return }
                let groups = documents.compactMap { try? $0.data(as: Group.self) }
                completion(groups)
            }
    }
    
    func sendGroupMessage(groupId: String, text: String, type: MessageType = .text, imageUrl: String? = nil) async throws {
        guard let currentUserId = Auth.auth().currentUser?.uid else { return }
        
        let currentUser = try await db.collection("users").document(currentUserId).getDocument().data(as: User.self)
        
        let message = Message(
            id: UUID().uuidString,
            chatId: nil,
            groupId: groupId,
            senderId: currentUserId,
            senderName: currentUser.displayName,
            text: text,
            type: type,
            imageUrl: imageUrl,
            timestamp: Date(),
            status: .sent
        )
        
        let messageRef = db.collection("groups").document(groupId).collection("messages").document(message.id!)
        try messageRef.setData(from: message)
        
        // Update group's last message
        try await db.collection("groups").document(groupId).updateData([
            "lastMessage": text,
            "lastMessageTime": Timestamp(date: Date())
        ])
    }
    
    func observeGroupMessages(groupId: String, completion: @escaping ([Message]) -> Void) -> ListenerRegistration {
        return db.collection("groups").document(groupId).collection("messages")
            .order(by: "timestamp", descending: false)
            .addSnapshotListener { snapshot, error in
                guard let documents = snapshot?.documents else { return }
                let messages = documents.compactMap { try? $0.data(as: Message.self) }
                completion(messages)
            }
    }
    
    // MARK: - Helper Methods
    
    private func generateChatId(userId1: String, userId2: String) -> String {
        let sortedIds = [userId1, userId2].sorted()
        return "\(sortedIds[0])_\(sortedIds[1])"
    }
}

