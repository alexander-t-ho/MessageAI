//
//  AuthViewModel.swift
//  MessageAI
//
//  Created on 10/20/2025.
//

import Foundation
import FirebaseAuth

@MainActor
class AuthViewModel: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var errorMessage: String?
    @Published var isLoading = false
    
    private let authService = AuthService()
    
    init() {
        // Observe auth service
        authService.$isAuthenticated.assign(to: &$isAuthenticated)
        authService.$currentUser.assign(to: &$currentUser)
    }
    
    func register(email: String, password: String, displayName: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.register(email: email, password: password, displayName: displayName)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await authService.login(email: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    func logout() {
        do {
            try authService.logout()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func updateOnlineStatus(_ isOnline: Bool) async {
        try? await authService.updateOnlineStatus(isOnline)
    }
    
    func updateProfilePicture(url: String) async {
        try? await authService.updateProfilePicture(url: url)
    }
}

