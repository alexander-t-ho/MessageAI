//
//  AuthViewModel.swift
//  MessageAI
//
//  ViewModel for authentication state management
//

import Foundation
import SwiftUI
import Combine

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    
    // User defaults keys
    private let accessTokenKey = "accessToken"
    private let userIdKey = "userId"
    private let userEmailKey = "userEmail"
    private let userNameKey = "userName"
    
    init() {
        // Check if user is already logged in
        checkAuthStatus()
    }
    
    private func checkAuthStatus() {
        if let userId = UserDefaults.standard.string(forKey: userIdKey),
           let email = UserDefaults.standard.string(forKey: userEmailKey),
           let name = UserDefaults.standard.string(forKey: userNameKey),
           let _ = UserDefaults.standard.string(forKey: accessTokenKey) {
            currentUser = User(id: userId, email: email, name: name)
            isAuthenticated = true
        }
    }
    
    func signup(email: String, password: String, name: String) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        do {
            let response = try await NetworkService.shared.signup(
                email: email,
                password: password,
                name: name
            )
            
            if response.success {
                successMessage = response.message
                // Note: User needs to verify email before logging in
                print("✅ Signup successful: \(response.message)")
            } else {
                errorMessage = response.error ?? "Signup failed"
            }
        } catch let error as NetworkError {
            errorMessage = error.localizedDescription
            print("❌ Signup error: \(error)")
        } catch {
            errorMessage = "An unexpected error occurred"
            print("❌ Unexpected signup error: \(error)")
        }
        
        isLoading = false
    }
    
    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        successMessage = nil
        
        do {
            let response = try await NetworkService.shared.login(
                email: email,
                password: password
            )
            
            if response.success,
               let userId = response.userId,
               let email = response.email,
               let name = response.name,
               let tokens = response.tokens {
                
                // Save user data
                UserDefaults.standard.set(tokens.accessToken, forKey: accessTokenKey)
                UserDefaults.standard.set(userId, forKey: userIdKey)
                UserDefaults.standard.set(email, forKey: userEmailKey)
                UserDefaults.standard.set(name, forKey: userNameKey)
                
                // Update state
                currentUser = User(id: userId, email: email, name: name)
                isAuthenticated = true
                
                print("✅ Login successful: Welcome \(name)!")
            } else {
                errorMessage = response.error ?? "Login failed"
            }
        } catch let error as NetworkError {
            errorMessage = error.localizedDescription
            print("❌ Login error: \(error)")
        } catch {
            errorMessage = "An unexpected error occurred"
            print("❌ Unexpected login error: \(error)")
        }
        
        isLoading = false
    }
    
    func logout() {
        // Clear user data
        UserDefaults.standard.removeObject(forKey: accessTokenKey)
        UserDefaults.standard.removeObject(forKey: userIdKey)
        UserDefaults.standard.removeObject(forKey: userEmailKey)
        UserDefaults.standard.removeObject(forKey: userNameKey)
        
        // Update state
        currentUser = nil
        isAuthenticated = false
        
        print("👋 Logged out")
    }
}

