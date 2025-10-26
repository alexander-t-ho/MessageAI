//
//  S3VoiceStorage.swift
//  Cloudy
//
//  Service for uploading and downloading voice messages to/from S3
//

import Foundation

class S3VoiceStorage {
    static let shared = S3VoiceStorage()
    
    private let bucketName = "cloudy-voice-messages-alexho"
    private let region = "us-east-1"
    
    // Lambda Function URL for generating pre-signed URLs
    private var uploadURLEndpoint: String {
        return "https://45egclkl7gi7f2u5btb7m6ezmm0lvfxh.lambda-url.us-east-1.on.aws/"
    }
    
    private init() {}
    
    // MARK: - Upload
    
    /// Upload voice message to S3
    /// Returns the S3 URL of the uploaded file
    func uploadVoiceMessage(fileURL: URL, userId: String, messageId: String) async throws -> String {
        print("☁️ Starting S3 upload for voice message")
        print("   File URL: \(fileURL)")
        print("   User ID: \(userId)")
        print("   Message ID: \(messageId)")
        
        // Step 1: Read the audio file data
        guard let audioData = try? Data(contentsOf: fileURL) else {
            print("❌ Failed to read audio file at: \(fileURL)")
            throw S3Error.failedToReadFile
        }
        
        print("📁 Audio data size: \(audioData.count) bytes")
        
        // Step 2: Generate S3 key (path in bucket)
        let fileExtension = fileURL.pathExtension
        let s3Key = "\(userId)/\(messageId).\(fileExtension)"
        
        print("🔑 S3 Key: \(s3Key)")
        
        // Step 3: Get pre-signed upload URL from backend
        print("🔗 Requesting pre-signed URL from Lambda...")
        let uploadURL = try await getUploadURL(s3Key: s3Key, contentType: "audio/m4a")
        
        print("🔗 Got pre-signed URL: \(uploadURL)")
        
        // Step 4: Upload file to S3 using pre-signed URL
        print("📤 Uploading to S3...")
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "PUT"
        request.setValue("audio/m4a", forHTTPHeaderField: "Content-Type")
        request.httpBody = audioData
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Invalid HTTP response")
            throw S3Error.uploadFailed
        }
        
        print("📤 S3 upload response: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            print("❌ S3 upload failed with status: \(httpResponse.statusCode)")
            throw S3Error.uploadFailed
        }
        
        print("✅ Voice message uploaded to S3 successfully")
        
        // Step 5: Return the permanent S3 URL
        let s3URL = "https://\(bucketName).s3.\(region).amazonaws.com/\(s3Key)"
        
        print("🔗 S3 URL: \(s3URL)")
        
        return s3URL
    }
    
    // MARK: - Download
    
    /// Download voice message from S3
    /// Returns local file URL where the audio is cached
    func downloadVoiceMessage(s3URL: String, messageId: String) async throws -> URL {
        print("⬇️ Downloading voice message from S3")
        print("🔗 URL: \(s3URL)")
        
        // Check if already cached
        let cacheURL = getCacheURL(for: messageId)
        if FileManager.default.fileExists(atPath: cacheURL.path) {
            print("✅ Voice message already cached")
            return cacheURL
        }
        
        // Download from S3
        guard let url = URL(string: s3URL) else {
            throw S3Error.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw S3Error.downloadFailed
        }
        
        // Save to cache
        try data.write(to: cacheURL)
        
        print("✅ Voice message downloaded and cached")
        print("📁 Cached at: \(cacheURL.path)")
        
        return cacheURL
    }
    
    // MARK: - Helpers
    
    private func getUploadURL(s3Key: String, contentType: String) async throws -> URL {
        // Call Lambda function to generate pre-signed upload URL
        
        guard let lambdaURL = URL(string: uploadURLEndpoint) else {
            print("❌ Invalid Lambda URL: \(uploadURLEndpoint)")
            throw S3Error.invalidURL
        }
        
        // Extract userId and messageId from s3Key (format: userId/messageId.m4a)
        let components = s3Key.components(separatedBy: "/")
        guard components.count == 2 else {
            print("❌ Invalid S3 key format: \(s3Key)")
            throw S3Error.invalidURL
        }
        
        let userId = components[0]
        let messageIdWithExt = components[1]
        let messageId = messageIdWithExt.replacingOccurrences(of: ".m4a", with: "")
        
        print("🔗 Lambda request details:")
        print("   URL: \(lambdaURL)")
        print("   User ID: \(userId)")
        print("   Message ID: \(messageId)")
        print("   Content Type: \(contentType)")
        
        // Prepare request
        var request = URLRequest(url: lambdaURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: String] = [
            "userId": userId,
            "messageId": messageId,
            "contentType": contentType
        ]
        
        request.httpBody = try JSONEncoder().encode(requestBody)
        
        print("📤 Calling Lambda function...")
        
        // Call Lambda
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ Invalid Lambda response")
            throw S3Error.uploadFailed
        }
        
        print("📥 Lambda response status: \(httpResponse.statusCode)")
        
        guard (200...299).contains(httpResponse.statusCode) else {
            print("❌ Lambda returned status: \(httpResponse.statusCode)")
            if let errorText = String(data: data, encoding: .utf8) {
                print("   Error response: \(errorText)")
            }
            throw S3Error.uploadFailed
        }
        
        // Parse response
        struct LambdaResponse: Codable {
            let success: Bool
            let uploadURL: String
            let s3URL: String?
        }
        
        let lambdaResponse = try JSONDecoder().decode(LambdaResponse.self, from: data)
        
        print("📥 Lambda response parsed:")
        print("   Success: \(lambdaResponse.success)")
        print("   Upload URL: \(lambdaResponse.uploadURL)")
        print("   S3 URL: \(lambdaResponse.s3URL ?? "nil")")
        
        guard lambdaResponse.success, let uploadURLString = lambdaResponse.uploadURL as String? else {
            print("❌ Lambda returned unsuccessful response")
            throw S3Error.uploadFailed
        }
        
        guard let uploadURL = URL(string: uploadURLString) else {
            print("❌ Invalid upload URL: \(uploadURLString)")
            throw S3Error.invalidURL
        }
        
        return uploadURL
    }
    
    private func getCacheURL(for messageId: String) -> URL {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let voiceCacheDir = cacheDir.appendingPathComponent("VoiceMessages")
        
        // Create directory if needed
        try? FileManager.default.createDirectory(at: voiceCacheDir, withIntermediateDirectories: true)
        
        return voiceCacheDir.appendingPathComponent("\(messageId).m4a")
    }
    
    /// Clear old cached voice messages (30 days)
    func clearOldCache() {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let voiceCacheDir = cacheDir.appendingPathComponent("VoiceMessages")
        
        guard let files = try? FileManager.default.contentsOfDirectory(at: voiceCacheDir, includingPropertiesForKeys: [.creationDateKey]) else {
            return
        }
        
        let thirtyDaysAgo = Date().addingTimeInterval(-30 * 24 * 60 * 60)
        
        for fileURL in files {
            if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
               let creationDate = attributes[.creationDate] as? Date,
               creationDate < thirtyDaysAgo {
                try? FileManager.default.removeItem(at: fileURL)
                print("🗑️ Deleted old cached voice message: \(fileURL.lastPathComponent)")
            }
        }
    }
}

// MARK: - Errors

enum S3Error: LocalizedError {
    case failedToReadFile
    case uploadFailed
    case downloadFailed
    case invalidURL
    case notImplemented(String)
    
    var errorDescription: String? {
        switch self {
        case .failedToReadFile:
            return "Failed to read audio file"
        case .uploadFailed:
            return "Failed to upload to S3"
        case .downloadFailed:
            return "Failed to download from S3"
        case .invalidURL:
            return "Invalid S3 URL"
        case .notImplemented(let message):
            return message
        }
    }
}

