//
//  NetworkService.swift
//  MessageAI
//
//  Network service for API communication
//

import Foundation

enum NetworkError: Error {
    case invalidURL
    case invalidResponse
    case serverError(String)
    case decodingError
    case networkError(Error)
    
    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .invalidResponse:
            return "Invalid server response"
        case .serverError(let message):
            return message
        case .decodingError:
            return "Failed to decode response"
        case .networkError(let error):
            return error.localizedDescription
        }
    }
}

class NetworkService {
    static let shared = NetworkService()
    
    private init() {}
    
    // MARK: - Signup
    func signup(email: String, password: String, name: String) async throws -> AuthResponse {
        guard let url = URL(string: Config.Endpoints.signup) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let signupRequest = SignupRequest(email: email, password: password, name: name)
        request.httpBody = try JSONEncoder().encode(signupRequest)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            // Log the response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 Signup Response (\(httpResponse.statusCode)): \(responseString)")
            }
            
            if httpResponse.statusCode == 200 {
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
                return authResponse
            } else {
                // Try to decode error response
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    throw NetworkError.serverError(errorResponse.message)
                } else {
                    throw NetworkError.serverError("Signup failed with status \(httpResponse.statusCode)")
                }
            }
        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.networkError(error)
        }
    }
    
    // MARK: - Login
    func login(email: String, password: String) async throws -> AuthResponse {
        guard let url = URL(string: Config.Endpoints.login) else {
            throw NetworkError.invalidURL
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let loginRequest = LoginRequest(email: email, password: password)
        request.httpBody = try JSONEncoder().encode(loginRequest)
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                throw NetworkError.invalidResponse
            }
            
            // Log the response for debugging
            if let responseString = String(data: data, encoding: .utf8) {
                print("📥 Login Response (\(httpResponse.statusCode)): \(responseString)")
            }
            
            if httpResponse.statusCode == 200 {
                let authResponse = try JSONDecoder().decode(AuthResponse.self, from: data)
                return authResponse
            } else {
                // Try to decode error response
                if let errorResponse = try? JSONDecoder().decode(ErrorResponse.self, from: data) {
                    throw NetworkError.serverError(errorResponse.message)
                } else {
                    throw NetworkError.serverError("Login failed with status \(httpResponse.statusCode)")
                }
            }
        } catch let error as NetworkError {
            throw error
        } catch {
            throw NetworkError.networkError(error)
        }
    }
}

