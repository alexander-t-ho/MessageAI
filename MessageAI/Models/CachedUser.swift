//
//  CachedUser.swift
//  MessageAI
//
//  Created on 10/20/2025.
//

import Foundation
import SwiftData

@Model
final class CachedUser {
    @Attribute(.unique) var id: String
    var email: String
    var displayName: String
    var profilePictureUrl: String?
    var isOnline: Bool
    var lastSeen: Date
    
    init(id: String, email: String, displayName: String, profilePictureUrl: String?, isOnline: Bool, lastSeen: Date) {
        self.id = id
        self.email = email
        self.displayName = displayName
        self.profilePictureUrl = profilePictureUrl
        self.isOnline = isOnline
        self.lastSeen = lastSeen
    }
    
    func toUser() -> User {
        User(
            id: id,
            email: email,
            displayName: displayName,
            profilePictureUrl: profilePictureUrl,
            isOnline: isOnline,
            lastSeen: lastSeen,
            createdAt: Date(),
            fcmToken: nil
        )
    }
}

