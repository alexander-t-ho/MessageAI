//
//  CachedMessage.swift
//  MessageAI
//
//  Created on 10/20/2025.
//

import Foundation
import SwiftData

@Model
final class CachedMessage {
    @Attribute(.unique) var id: String
    var chatId: String?
    var groupId: String?
    var senderId: String
    var senderName: String
    var text: String
    var type: String
    var imageUrl: String?
    var timestamp: Date
    var status: String
    var needsSync: Bool
    
    init(id: String, chatId: String?, groupId: String?, senderId: String, senderName: String, text: String, type: String, imageUrl: String?, timestamp: Date, status: String, needsSync: Bool) {
        self.id = id
        self.chatId = chatId
        self.groupId = groupId
        self.senderId = senderId
        self.senderName = senderName
        self.text = text
        self.type = type
        self.imageUrl = imageUrl
        self.timestamp = timestamp
        self.status = status
        self.needsSync = needsSync
    }
    
    convenience init(from message: Message, needsSync: Bool = false) {
        self.init(
            id: message.id ?? UUID().uuidString,
            chatId: message.chatId,
            groupId: message.groupId,
            senderId: message.senderId,
            senderName: message.senderName,
            text: message.text,
            type: message.type.rawValue,
            imageUrl: message.imageUrl,
            timestamp: message.timestamp,
            status: message.status.rawValue,
            needsSync: needsSync
        )
    }
    
    func toMessage() -> Message {
        Message(
            id: id,
            chatId: chatId,
            groupId: groupId,
            senderId: senderId,
            senderName: senderName,
            text: text,
            type: MessageType(rawValue: type) ?? .text,
            imageUrl: imageUrl,
            timestamp: timestamp,
            status: MessageStatus(rawValue: status) ?? .sent
        )
    }
}

