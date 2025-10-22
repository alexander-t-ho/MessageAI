//
//  CachedChat.swift
//  MessageAI
//
//  Created on 10/20/2025.
//

import Foundation
import SwiftData

@Model
final class CachedChat {
    @Attribute(.unique) var id: String
    var participants: [String]
    var lastMessage: String
    var lastMessageTime: Date
    var lastMessageSenderId: String?
    
    init(id: String, participants: [String], lastMessage: String, lastMessageTime: Date, lastMessageSenderId: String?) {
        self.id = id
        self.participants = participants
        self.lastMessage = lastMessage
        self.lastMessageTime = lastMessageTime
        self.lastMessageSenderId = lastMessageSenderId
    }
}

