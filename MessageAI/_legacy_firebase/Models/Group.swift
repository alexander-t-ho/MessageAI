//
//  Group.swift
//  MessageAI
//
//  Created on 10/20/2025.
//

import Foundation
import FirebaseFirestore

struct Group: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var name: String
    var participants: [String]
    var participantNames: [String: String]
    var createdBy: String
    var createdAt: Date
    var lastMessage: String?
    var lastMessageTime: Date?
    var groupImageUrl: String?
    
    var participantCount: Int {
        participants.count
    }
    
    var participantNamesString: String {
        participantNames.values.sorted().joined(separator: ", ")
    }
}

extension Group {
    static var preview: Group {
        Group(
            id: "preview-group",
            name: "Team Chat",
            participants: ["user1", "user2", "user3"],
            participantNames: [
                "user1": "Alice",
                "user2": "Bob",
                "user3": "Charlie"
            ],
            createdBy: "user1",
            createdAt: Date(),
            lastMessage: "Great work everyone!",
            lastMessageTime: Date(),
            groupImageUrl: nil
        )
    }
}

