//
//  Chat.swift
//  MessageAI
//
//  Created on 10/20/2025.
//

import Foundation
import FirebaseFirestore

struct Chat: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var participants: [String]
    var participantNames: [String: String]
    var lastMessage: String
    var lastMessageTime: Date
    var lastMessageSenderId: String?
    var unreadCount: [String: Int]
    var typing: [String: Date]
    
    func otherParticipantId(currentUserId: String) -> String? {
        participants.first { $0 != currentUserId }
    }
    
    func otherParticipantName(currentUserId: String) -> String {
        guard let otherId = otherParticipantId(currentUserId: currentUserId) else {
            return "Unknown"
        }
        return participantNames[otherId] ?? "Unknown"
    }
    
    func isTyping(userId: String) -> Bool {
        guard let typingTime = typing[userId] else { return false }
        return Date().timeIntervalSince(typingTime) < 3
    }
}

extension Chat {
    static var preview: Chat {
        Chat(
            id: "preview-chat",
            participants: ["user1", "user2"],
            participantNames: ["user1": "User One", "user2": "User Two"],
            lastMessage: "Hey there!",
            lastMessageTime: Date(),
            lastMessageSenderId: "user1",
            unreadCount: ["user2": 2],
            typing: [:]
        )
    }
}

