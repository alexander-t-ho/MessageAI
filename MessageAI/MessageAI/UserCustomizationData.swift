//
//  UserCustomizationData.swift
//  MessageAI
//
//  Store custom nicknames and photos for other users (local only)
//

import SwiftUI
import SwiftData

@Model
class UserCustomizationData {
    @Attribute(.unique) var userId: String
    var customNickname: String?
    var customPhotoData: Data?
    var lastUpdated: Date
    
    init(userId: String, customNickname: String? = nil, customPhotoData: Data? = nil) {
        self.userId = userId
        self.customNickname = customNickname
        self.customPhotoData = customPhotoData
        self.lastUpdated = Date()
    }
}

// Helper class to manage user customizations
class UserCustomizationManager {
    static let shared = UserCustomizationManager()
    
    // Get custom nickname for a user (fallback to real name)
    func getNickname(for userId: String, realName: String, modelContext: ModelContext) -> String {
        let descriptor = FetchDescriptor<UserCustomizationData>(
            predicate: #Predicate { $0.userId == userId }
        )
        
        if let customization = try? modelContext.fetch(descriptor).first,
           let nickname = customization.customNickname, !nickname.isEmpty {
            return nickname
        }
        
        return realName
    }
    
    // Get custom photo for a user
    func getCustomPhoto(for userId: String, modelContext: ModelContext) -> Data? {
        let descriptor = FetchDescriptor<UserCustomizationData>(
            predicate: #Predicate { $0.userId == userId }
        )
        
        return try? modelContext.fetch(descriptor).first?.customPhotoData
    }
    
    // Set custom nickname for a user
    func setNickname(for userId: String, nickname: String?, modelContext: ModelContext) {
        let descriptor = FetchDescriptor<UserCustomizationData>(
            predicate: #Predicate { $0.userId == userId }
        )
        
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.customNickname = nickname
            existing.lastUpdated = Date()
        } else {
            let newCustomization = UserCustomizationData(userId: userId, customNickname: nickname)
            modelContext.insert(newCustomization)
        }
        
        try? modelContext.save()
    }
    
    // Set custom photo for a user
    func setCustomPhoto(for userId: String, photoData: Data?, modelContext: ModelContext) {
        let descriptor = FetchDescriptor<UserCustomizationData>(
            predicate: #Predicate { $0.userId == userId }
        )
        
        if let existing = try? modelContext.fetch(descriptor).first {
            existing.customPhotoData = photoData
            existing.lastUpdated = Date()
        } else {
            let newCustomization = UserCustomizationData(userId: userId, customPhotoData: photoData)
            modelContext.insert(newCustomization)
        }
        
        try? modelContext.save()
    }
}

