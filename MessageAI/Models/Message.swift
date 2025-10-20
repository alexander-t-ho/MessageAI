//
//  Message.swift
//  MessageAI
//
//  Created on 10/20/2025.
//

import Foundation
import FirebaseFirestore

enum MessageType: String, Codable {
    case text
    case image
    case system
}

enum MessageStatus: String, Codable {
    case sending
    case sent
    case delivered
    case read
    case failed
}

struct Message: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var chatId: String?
    var groupId: String?
    var senderId: String
    var senderName: String
    var text: String
    var type: MessageType
    var imageUrl: String?
    var timestamp: Date
    var status: MessageStatus
    
    var isFromCurrentUser: Bool {
        // This will be set by the view model
        return false
    }
}

extension Message {
    static var preview: Message {
        Message(
            id: "preview-message",
            chatId: "preview-chat",
            groupId: nil,
            senderId: "preview-sender",
            senderName: "Test User",
            text: "Hello, this is a preview message!",
            type: .text,
            imageUrl: nil,
            timestamp: Date(),
            status: .sent
        )
    }
}

