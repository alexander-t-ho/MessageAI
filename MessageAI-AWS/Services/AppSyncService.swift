//
//  AppSyncService.swift
//  MessageAI (AWS Version)
//
//  Replaces Firestore with AWS AppSync + DynamoDB
//

import Foundation
import Amplify
import AWSAPIPlugin
import Combine

class AppSyncService {
    private var subscriptions: Set<AnyCancellable> = []
    
    // MARK: - User Operations
    
    func createUser(_ user: User) async throws {
        let mutation = """
        mutation CreateUser($input: CreateUserInput!) {
          createUser(input: $input) {
            id
            email
            displayName
            profilePictureUrl
            isOnline
            lastSeen
            createdAt
          }
        }
        """
        
        let variables: [String: Any] = [
            "input": [
                "id": user.id ?? "",
                "email": user.email,
                "displayName": user.displayName,
                "profilePictureUrl": user.profilePictureUrl as Any,
                "isOnline": user.isOnline,
                "lastSeen": Int(user.lastSeen.timeIntervalSince1970),
                "createdAt": Int(user.createdAt.timeIntervalSince1970)
            ]
        ]
        
        _ = try await executeGraphQL(query: mutation, variables: variables)
    }
    
    func getUser(userId: String) async throws -> User? {
        let query = """
        query GetUser($id: ID!) {
          getUser(id: $id) {
            id
            email
            displayName
            profilePictureUrl
            isOnline
            lastSeen
            createdAt
            deviceToken
          }
        }
        """
        
        let variables: [String: Any] = ["id": userId]
        let result = try await executeGraphQL(query: query, variables: variables)
        
        // Parse JSON response to User object
        // Implementation depends on actual response structure
        return nil // Placeholder
    }
    
    func listUsers() async throws -> [User] {
        let query = """
        query ListUsers {
          listUsers {
            items {
              id
              email
              displayName
              profilePictureUrl
              isOnline
              lastSeen
              createdAt
            }
          }
        }
        """
        
        let result = try await executeGraphQL(query: query, variables: [:])
        
        // Parse response
        return [] // Placeholder
    }
    
    func updateUser(userId: String, profilePictureUrl: String? = nil, deviceToken: String? = nil) async throws {
        var updateFields: [String: Any] = ["id": userId]
        if let url = profilePictureUrl {
            updateFields["profilePictureUrl"] = url
        }
        if let token = deviceToken {
            updateFields["deviceToken"] = token
        }
        
        let mutation = """
        mutation UpdateUser($input: UpdateUserInput!) {
          updateUser(input: $input) {
            id
            profilePictureUrl
            deviceToken
          }
        }
        """
        
        let variables: [String: Any] = ["input": updateFields]
        _ = try await executeGraphQL(query: mutation, variables: variables)
    }
    
    func updateUserPresence(userId: String, isOnline: Bool, lastSeen: Date) async throws {
        let mutation = """
        mutation UpdateUserPresence($userId: ID!, $isOnline: Boolean!, $lastSeen: AWSTimestamp!) {
          updateUserPresence(userId: $userId, isOnline: $isOnline, lastSeen: $lastSeen) {
            id
            isOnline
            lastSeen
          }
        }
        """
        
        let variables: [String: Any] = [
            "userId": userId,
            "isOnline": isOnline,
            "lastSeen": Int(lastSeen.timeIntervalSince1970)
        ]
        
        _ = try await executeGraphQL(query: mutation, variables: variables)
    }
    
    // MARK: - Chat Operations
    
    func createOrGetChat(with userId: String, currentUserId: String) async throws -> String {
        let chatId = generateChatId(userId1: currentUserId, userId2: userId)
        
        // Check if chat exists
        if let _ = try await getChat(chatId: chatId) {
            return chatId
        }
        
        // Create new chat
        let mutation = """
        mutation CreateChat($input: CreateChatInput!) {
          createChat(input: $input) {
            id
            participants
          }
        }
        """
        
        let variables: [String: Any] = [
            "input": [
                "id": chatId,
                "participants": [currentUserId, userId],
                "participantNames": [:], // Will be populated
                "lastMessage": "",
                "lastMessageTime": Int(Date().timeIntervalSince1970),
                "unreadCount": [:],
                "typing": [:]
            ]
        ]
        
        _ = try await executeGraphQL(query: mutation, variables: variables)
        return chatId
    }
    
    func getChat(chatId: String) async throws -> Chat? {
        let query = """
        query GetChat($id: ID!) {
          getChat(id: $id) {
            id
            participants
            participantNames
            lastMessage
            lastMessageTime
            lastMessageSenderId
            unreadCount
            typing
          }
        }
        """
        
        let variables: [String: Any] = ["id": chatId]
        _ = try await executeGraphQL(query: query, variables: variables)
        
        return nil // Placeholder
    }
    
    func listChats(participantId: String) async throws -> [Chat] {
        let query = """
        query ListChats($participantId: ID!) {
          listChats(participantId: $participantId) {
            items {
              id
              participants
              participantNames
              lastMessage
              lastMessageTime
              lastMessageSenderId
              unreadCount
              typing
            }
          }
        }
        """
        
        let variables: [String: Any] = ["participantId": participantId]
        _ = try await executeGraphQL(query: query, variables: variables)
        
        return [] // Placeholder
    }
    
    func updateTypingStatus(chatId: String, userId: String, isTyping: Bool) async throws {
        let mutation = """
        mutation UpdateTypingStatus($chatId: ID!, $userId: ID!, $isTyping: Boolean!) {
          updateTypingStatus(chatId: $chatId, userId: $userId, isTyping: $isTyping) {
            id
            typing
          }
        }
        """
        
        let variables: [String: Any] = [
            "chatId": chatId,
            "userId": userId,
            "isTyping": isTyping
        ]
        
        _ = try await executeGraphQL(query: mutation, variables: variables)
    }
    
    // MARK: - Message Operations
    
    func sendMessage(chatId: String, senderId: String, senderName: String, text: String, type: MessageType = .text, imageUrl: String? = nil) async throws {
        let mutation = """
        mutation CreateMessage($input: CreateMessageInput!) {
          createMessage(input: $input) {
            id
            chatId
            senderId
            senderName
            text
            type
            imageUrl
            timestamp
            status
          }
        }
        """
        
        let variables: [String: Any] = [
            "input": [
                "id": UUID().uuidString,
                "chatId": chatId,
                "senderId": senderId,
                "senderName": senderName,
                "text": text,
                "type": type.rawValue.uppercased(),
                "imageUrl": imageUrl as Any,
                "timestamp": Int(Date().timeIntervalSince1970),
                "status": MessageStatus.sent.rawValue.uppercased()
            ]
        ]
        
        _ = try await executeGraphQL(query: mutation, variables: variables)
    }
    
    func listMessages(chatId: String, limit: Int = 50) async throws -> [Message] {
        let query = """
        query ListMessages($chatId: ID!, $limit: Int) {
          listMessages(chatId: $chatId, limit: $limit) {
            items {
              id
              chatId
              senderId
              senderName
              text
              type
              imageUrl
              timestamp
              status
            }
          }
        }
        """
        
        let variables: [String: Any] = [
            "chatId": chatId,
            "limit": limit
        ]
        
        _ = try await executeGraphQL(query: query, variables: variables)
        
        return [] // Placeholder
    }
    
    func markMessagesAsRead(chatId: String, messageIds: [String]) async throws {
        let mutation = """
        mutation MarkMessagesAsRead($chatId: ID!, $messageIds: [ID!]!) {
          markMessagesAsRead(chatId: $chatId, messageIds: $messageIds) {
            id
            status
          }
        }
        """
        
        let variables: [String: Any] = [
            "chatId": chatId,
            "messageIds": messageIds
        ]
        
        _ = try await executeGraphQL(query: mutation, variables: variables)
    }
    
    // MARK: - Group Operations
    
    func createGroup(name: String, participantIds: [String], createdBy: String) async throws -> String {
        let groupId = UUID().uuidString
        
        let mutation = """
        mutation CreateGroup($input: CreateGroupInput!) {
          createGroup(input: $input) {
            id
            name
            participants
          }
        }
        """
        
        let variables: [String: Any] = [
            "input": [
                "id": groupId,
                "name": name,
                "participants": participantIds,
                "participantNames": [:],
                "createdBy": createdBy,
                "createdAt": Int(Date().timeIntervalSince1970)
            ]
        ]
        
        _ = try await executeGraphQL(query: mutation, variables: variables)
        return groupId
    }
    
    func sendGroupMessage(groupId: String, senderId: String, senderName: String, text: String, type: MessageType = .text, imageUrl: String? = nil) async throws {
        let mutation = """
        mutation CreateMessage($input: CreateMessageInput!) {
          createMessage(input: $input) {
            id
            groupId
            senderId
            senderName
            text
            type
            timestamp
          }
        }
        """
        
        let variables: [String: Any] = [
            "input": [
                "id": UUID().uuidString,
                "groupId": groupId,
                "senderId": senderId,
                "senderName": senderName,
                "text": text,
                "type": type.rawValue.uppercased(),
                "imageUrl": imageUrl as Any,
                "timestamp": Int(Date().timeIntervalSince1970)
            ]
        ]
        
        _ = try await executeGraphQL(query: mutation, variables: variables)
    }
    
    // MARK: - Subscriptions (Real-time)
    
    func subscribeToMessages(chatId: String, completion: @escaping ([Message]) -> Void) -> AnyCancellable {
        let subscription = """
        subscription OnMessageReceived($chatId: ID!) {
          onMessageReceived(chatId: $chatId) {
            id
            chatId
            senderId
            senderName
            text
            type
            imageUrl
            timestamp
            status
          }
        }
        """
        
        // Create subscription using Amplify
        // Placeholder - actual implementation uses Amplify.API.subscribe
        
        return AnyCancellable {}
    }
    
    func subscribeToTypingStatus(chatId: String, completion: @escaping (Chat) -> Void) -> AnyCancellable {
        let subscription = """
        subscription OnTypingStatusChanged($chatId: ID!) {
          onTypingStatusChanged(chatId: $chatId) {
            id
            typing
          }
        }
        """
        
        return AnyCancellable {}
    }
    
    // MARK: - Helper Methods
    
    private func executeGraphQL(query: String, variables: [String: Any]) async throws -> [String: Any] {
        // Use Amplify.API.query or mutate
        // This is a placeholder - actual implementation uses Amplify SDK
        
        return [:]
    }
    
    private func generateChatId(userId1: String, userId2: String) -> String {
        let sortedIds = [userId1, userId2].sorted()
        return "\(sortedIds[0])_\(sortedIds[1])"
    }
}

