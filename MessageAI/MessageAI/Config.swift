//
//  Config.swift
//  MessageAI
//
//  Backend Configuration
//

import Foundation

struct Config {
    // API Configuration
    static let baseURL = "https://hzbifqs8e2.execute-api.us-east-1.amazonaws.com/prod"
    
    // Cognito Configuration
    static let userPoolId = "us-east-1_aJN47Jgfy"
    static let appClientId = "55d6h6f4he7j72082d086red5b"
    
    // WebSocket Configuration - Phase 4: Real-Time Messaging
    static let webSocketURL = "wss://bnbr75tld0.execute-api.us-east-1.amazonaws.com/production"
    
    // API Endpoints
    struct Endpoints {
        static let signup = "\(baseURL)/auth/signup"
        static let login = "\(baseURL)/auth/login"
        static let searchUsers = "\(baseURL)/users/search"
    }
}

