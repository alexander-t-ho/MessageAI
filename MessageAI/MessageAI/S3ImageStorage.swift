//
//  S3ImageStorage.swift
//  MessageAI
//
//  Service for uploading and downloading images to/from S3
//

import Foundation
import UIKit

class S3ImageStorage {
    static let shared = S3ImageStorage()
    
    private let bucketName = "cloudy-images-alexho"
    private let region = "us-east-1"
    
    // Lambda Function URL for generating pre-signed URLs
    private var uploadURLEndpoint: String {
        return "https://45egclkl7gi7f2u5btb7m6ezmm0lvfxh.lambda-url.us-east-1.on.aws/"
    }
    
    private init() {}
    
    // MARK: - Upload
    
    /// Upload image to S3
    /// Returns the S3 URL of the uploaded image
    func uploadImage(imageData: Data, userId: String, messageId: String, isThumbnail: Bool = false) async throws -> String {
        print("📸 Starting S3 upload for image")
        print("   Data size: \(imageData.count) bytes")
        print("   User ID: \(userId)")
        print("   Message ID: \(messageId)")
        print("   Is thumbnail: \(isThumbnail)")
        
        // Step 1: Generate S3 key (path in bucket)
        let s3Key = isThumbnail ? "\(userId)/\(messageId)_thumb.jpg" : "\(userId)/\(messageId).jpg"
        
        print("🔑 S3 Key: \(s3Key)")
        
        // Step 2: Get pre-signed upload URL from backend
        print("🔗 Requesting pre-signed URL from Lambda...")
        let uploadURL = try await getUploadURL(s3Key: s3Key, contentType: "image/jpeg")
        
        print("✅ Pre-signed URL received")
        
        // Step 3: Upload image data to S3
        print("☁️ Uploading image to S3...")
        let s3URL = try await uploadToS3(data: imageData, uploadURL: uploadURL)
        
        print("✅ Image uploaded successfully to: \(s3URL)")
        return s3URL
    }
    
    /// Upload both full image and thumbnail
    func uploadImageWithThumbnail(imageData: Data, thumbnailData: Data, userId: String, messageId: String) async throws -> (imageURL: String, thumbnailURL: String) {
        print("📸 Starting S3 upload for image and thumbnail")
        
        // Upload full image
        let imageURL = try await uploadImage(imageData: imageData, userId: userId, messageId: messageId, isThumbnail: false)
        
        // Upload thumbnail
        let thumbnailURL = try await uploadImage(imageData: thumbnailData, userId: userId, messageId: messageId, isThumbnail: true)
        
        return (imageURL, thumbnailURL)
    }
    
    // MARK: - Download
    
    /// Download image from S3 URL
    func downloadImage(from url: String) async throws -> Data {
        print("📥 Downloading image from: \(url)")
        
        guard let downloadURL = URL(string: url) else {
            print("❌ Invalid image URL: \(url)")
            throw S3Error.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: downloadURL)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Invalid response type")
            throw S3Error.invalidResponse
        }
        
        guard httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
            print("❌ HTTP error: \(httpResponse.statusCode)")
            throw S3Error.httpError(httpResponse.statusCode)
        }
        
        print("✅ Image downloaded successfully: \(data.count) bytes")
        return data
    }
    
    // MARK: - Private Methods
    
    private func getUploadURL(s3Key: String, contentType: String) async throws -> String {
        let requestBody = [
            "bucketName": bucketName,
            "key": s3Key,
            "contentType": contentType
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: requestBody) else {
            print("❌ Failed to serialize request body")
            throw S3Error.serializationError
        }
        
        guard let url = URL(string: uploadURLEndpoint) else {
            print("❌ Invalid upload URL endpoint")
            throw S3Error.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = jsonData
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Invalid response type")
            throw S3Error.invalidResponse
        }
        
        guard httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
            print("❌ HTTP error: \(httpResponse.statusCode)")
            throw S3Error.httpError(httpResponse.statusCode)
        }
        
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let uploadURL = json["uploadURL"] as? String else {
            print("❌ Failed to parse upload URL response")
            throw S3Error.invalidResponse
        }
        
        return uploadURL
    }
    
    private func uploadToS3(data: Data, uploadURL: String) async throws -> String {
        guard let url = URL(string: uploadURL) else {
            print("❌ Invalid upload URL")
            throw S3Error.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = data
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Invalid response type")
            throw S3Error.invalidResponse
        }
        
        guard httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
            print("❌ S3 upload failed with status: \(httpResponse.statusCode)")
            throw S3Error.httpError(httpResponse.statusCode)
        }
        
        // Extract S3 URL from the upload URL
        // The upload URL typically contains the S3 URL
        let s3URL = uploadURL.components(separatedBy: "?").first ?? uploadURL
        return s3URL
    }
}

// MARK: - Error Types
enum S3ImageError: Error, LocalizedError {
    case failedToReadFile
    case invalidURL
    case invalidResponse
    case httpError(Int)
    case serializationError
    case uploadFailed
    
    var errorDescription: String? {
        switch self {
        case .failedToReadFile:
            return "Failed to read image file"
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let code):
            return "HTTP error: \(code)"
        case .serializationError:
            return "Failed to serialize request"
        case .uploadFailed:
            return "Image upload failed"
        }
    }
}
