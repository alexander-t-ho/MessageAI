//
//  S3StorageService.swift
//  MessageAI (AWS Version)
//
//  Replaces Firebase Storage with AWS S3
//

import Foundation
import Amplify
import AWSS3StoragePlugin
import UIKit

class S3StorageService {
    
    // MARK: - Upload Operations
    
    func uploadImage(_ image: UIImage, path: String, progressListener: ((Double) -> Void)? = nil) async throws -> String {
        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            throw NSError(domain: "ImageError", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to convert image"])
        }
        
        let options = StorageUploadDataRequest.Options(
            accessLevel: .protected,
            contentType: "image/jpeg",
            metadata: [
                "uploadedAt": String(Date().timeIntervalSince1970)
            ]
        )
        
        let uploadTask = Amplify.Storage.uploadData(
            key: path,
            data: imageData,
            options: options
        )
        
        // Monitor progress
        Task {
            for await progress in await uploadTask.progress {
                await MainActor.run {
                    progressListener?(progress.fractionCompleted)
                }
            }
        }
        
        let result = try await uploadTask.value
        
        // Get download URL
        let downloadURL = try await getDownloadURL(key: result.key)
        return downloadURL
    }
    
    func uploadProfilePicture(_ image: UIImage, userId: String) async throws -> String {
        let path = "profile-pictures/\(userId).jpg"
        return try await uploadImage(image, path: path)
    }
    
    func uploadChatImage(_ image: UIImage, chatId: String) async throws -> String {
        let imageName = "\(UUID().uuidString).jpg"
        let path = "chat-images/\(chatId)/\(imageName)"
        return try await uploadImage(image, path: path)
    }
    
    func uploadGroupImage(_ image: UIImage, groupId: String) async throws -> String {
        let path = "group-images/\(groupId).jpg"
        return try await uploadImage(image, path: path)
    }
    
    // MARK: - Download Operations
    
    func getDownloadURL(key: String) async throws -> String {
        let result = try await Amplify.Storage.getURL(
            key: key,
            options: StorageGetURLRequest.Options(
                accessLevel: .protected,
                expires: 3600 // URL valid for 1 hour
            )
        )
        
        return result.url.absoluteString
    }
    
    func downloadImage(key: String) async throws -> Data {
        let downloadTask = Amplify.Storage.downloadData(
            key: key,
            options: StorageDownloadDataRequest.Options(
                accessLevel: .protected
            )
        )
        
        let result = try await downloadTask.value
        return result
    }
    
    // MARK: - Delete Operations
    
    func deleteFile(key: String) async throws {
        try await Amplify.Storage.remove(
            key: key,
            options: StorageRemoveRequest.Options(
                accessLevel: .protected
            )
        )
    }
    
    func deleteProfilePicture(userId: String) async throws {
        let path = "profile-pictures/\(userId).jpg"
        try await deleteFile(key: path)
    }
    
    // MARK: - List Operations
    
    func listFiles(path: String) async throws -> [StorageListResult.Item] {
        let result = try await Amplify.Storage.list(
            options: StorageListRequest.Options(
                accessLevel: .protected,
                path: path
            )
        )
        
        return result.items
    }
    
    // MARK: - Helper Methods
    
    func compressImage(_ image: UIImage, maxSizeKB: Int = 1024) -> UIImage {
        var compression: CGFloat = 0.9
        var imageData = image.jpegData(compressionQuality: compression)
        
        while (imageData?.count ?? 0) > maxSizeKB * 1024 && compression > 0.1 {
            compression -= 0.1
            imageData = image.jpegData(compressionQuality: compression)
        }
        
        guard let data = imageData,
              let compressedImage = UIImage(data: data) else {
            return image
        }
        
        return compressedImage
    }
    
    func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size
        
        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height
        
        let newSize: CGSize
        if widthRatio > heightRatio {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        } else {
            newSize = CGSize(width: size.width * widthRatio, height: size.height * widthRatio)
        }
        
        let rect = CGRect(origin: .zero, size: newSize)
        
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return newImage ?? image
    }
}

