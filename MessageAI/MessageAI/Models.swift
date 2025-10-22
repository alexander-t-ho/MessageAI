//
//  Models.swift
//  MessageAI
//
//  Data models for authentication and user management
//

import Foundation

// MARK: - User Model
struct User: Codable, Identifiable {
    let id: String
    let email: String
    let name: String
    
    enum CodingKeys: String, CodingKey {
        case id = "userId"
        case email
        case name
    }
}

// MARK: - Authentication Response
struct AuthResponse: Codable {
    let success: Bool
    let userId: String?
    let email: String?
    let name: String?
    let tokens: AuthTokens?
    let message: String
    let error: String?
    
    struct AuthTokens: Codable {
        let accessToken: String
        let idToken: String
        let refreshToken: String
        let expiresIn: Int
    }
}

// MARK: - Signup Request
struct SignupRequest: Codable {
    let email: String
    let password: String
    let name: String
}

// MARK: - Login Request
struct LoginRequest: Codable {
    let email: String
    let password: String
}

// MARK: - Error Response
struct ErrorResponse: Codable {
    let error: String?
    let message: String
    let details: String?
}

// MARK: - User Search
struct UserSearchRequest: Codable {
    let searchQuery: String
}

struct UserSearchResponse: Codable {
    let success: Bool
    let users: [UserSearchResult]
    let count: Int
}

struct UserSearchResult: Codable, Identifiable {
    let userId: String
    let name: String
    let email: String
    
    var id: String { userId }
}

