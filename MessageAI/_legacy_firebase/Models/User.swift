//
//  User.swift
//  MessageAI
//
//  Created on 10/20/2025.
//

import Foundation
import FirebaseFirestore

struct User: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var email: String
    var displayName: String
    var profilePictureUrl: String?
    var isOnline: Bool
    var lastSeen: Date
    var createdAt: Date
    var fcmToken: String?
    
    var initials: String {
        let components = displayName.components(separatedBy: " ")
        let firstInitial = components.first?.first?.uppercased() ?? ""
        let lastInitial = components.count > 1 ? components.last?.first?.uppercased() ?? "" : ""
        return firstInitial + lastInitial
    }
}

extension User {
    static var preview: User {
        User(
            id: "preview-user",
            email: "test@example.com",
            displayName: "Test User",
            profilePictureUrl: nil,
            isOnline: true,
            lastSeen: Date(),
            createdAt: Date(),
            fcmToken: nil
        )
    }
}

