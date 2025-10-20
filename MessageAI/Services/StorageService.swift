//
//  StorageService.swift
//  MessageAI
//
//  Created on 10/20/2025.
//

import Foundation
import FirebaseStorage
import UIKit

class StorageService {
    private let storage = Storage.storage()
    
    func uploadImage(_ image: UIImage, path: String) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw NSError(domain: "ImageError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image"])
        }
        
        let storageRef = storage.reference().child(path)
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"
        
        _ = try await storageRef.putDataAsync(imageData, metadata: metadata)
        let downloadURL = try await storageRef.downloadURL()
        
        return downloadURL.absoluteString
    }
    
    func uploadProfilePicture(_ image: UIImage, userId: String) async throws -> String {
        let path = "profile_pictures/\(userId).jpg"
        return try await uploadImage(image, path: path)
    }
    
    func uploadChatImage(_ image: UIImage, chatId: String) async throws -> String {
        let imageName = "\(UUID().uuidString).jpg"
        let path = "chat_images/\(chatId)/\(imageName)"
        return try await uploadImage(image, path: path)
    }
    
    func uploadGroupImage(_ image: UIImage, groupId: String) async throws -> String {
        let path = "group_images/\(groupId).jpg"
        return try await uploadImage(image, path: path)
    }
}

