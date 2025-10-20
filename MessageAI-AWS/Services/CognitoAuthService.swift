//
//  CognitoAuthService.swift
//  MessageAI (AWS Version)
//
//  Replaces Firebase Auth with AWS Cognito
//

import Foundation
import Amplify
import AWSCognitoAuthPlugin

class CognitoAuthService: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    
    private let appSyncService = AppSyncService()
    
    init() {
        // Check current auth session
        Task {
            await checkAuthSession()
        }
    }
    
    // MARK: - Authentication
    
    func checkAuthSession() async {
        do {
            let session = try await Amplify.Auth.fetchAuthSession()
            if session.isSignedIn {
                await MainActor.run {
                    self.isAuthenticated = true
                }
                await loadCurrentUser()
            }
        } catch {
            print("Failed to fetch auth session: \(error)")
        }
    }
    
    func register(email: String, password: String, displayName: String) async throws {
        let userAttributes = [
            AuthUserAttribute(.email, value: email),
            AuthUserAttribute(.name, value: displayName)
        ]
        
        let signUpResult = try await Amplify.Auth.signUp(
            username: email,
            password: password,
            options: AuthSignUpRequest.Options(userAttributes: userAttributes)
        )
        
        // If confirmation is required
        if case .confirmUser = signUpResult.nextStep {
            // For production, implement email confirmation flow
            // For now, we'll auto-confirm
            print("User needs to confirm email")
        }
        
        // Sign in after registration
        try await login(email: email, password: password)
        
        // Create user document in AppSync
        try await createUserDocument(email: email, displayName: displayName)
    }
    
    func login(email: String, password: String) async throws {
        let signInResult = try await Amplify.Auth.signIn(
            username: email,
            password: password
        )
        
        if signInResult.isSignedIn {
            await MainActor.run {
                self.isAuthenticated = true
            }
            await loadCurrentUser()
            try await updateOnlineStatus(true)
        }
    }
    
    func logout() async throws {
        try await updateOnlineStatus(false)
        _ = try await Amplify.Auth.signOut()
        
        await MainActor.run {
            self.isAuthenticated = false
            self.currentUser = nil
        }
    }
    
    // MARK: - User Management
    
    private func loadCurrentUser() async {
        do {
            let authUser = try await Amplify.Auth.getCurrentUser()
            // Fetch full user details from AppSync
            if let user = try await appSyncService.getUser(userId: authUser.userId) {
                await MainActor.run {
                    self.currentUser = user
                }
            }
        } catch {
            print("Failed to load current user: \(error)")
        }
    }
    
    private func createUserDocument(email: String, displayName: String) async throws {
        guard let authUser = try? await Amplify.Auth.getCurrentUser() else {
            throw NSError(domain: "AuthError", code: 401)
        }
        
        let user = User(
            id: authUser.userId,
            email: email,
            displayName: displayName,
            profilePictureUrl: nil,
            isOnline: true,
            lastSeen: Date(),
            createdAt: Date(),
            fcmToken: nil
        )
        
        try await appSyncService.createUser(user)
        
        await MainActor.run {
            self.currentUser = user
        }
    }
    
    func updateOnlineStatus(_ isOnline: Bool) async throws {
        guard let userId = try? await Amplify.Auth.getCurrentUser().userId else {
            return
        }
        
        try await appSyncService.updateUserPresence(
            userId: userId,
            isOnline: isOnline,
            lastSeen: Date()
        )
    }
    
    func updateProfilePicture(url: String) async throws {
        guard let userId = try? await Amplify.Auth.getCurrentUser().userId else {
            return
        }
        
        try await appSyncService.updateUser(userId: userId, profilePictureUrl: url)
        
        await MainActor.run {
            self.currentUser?.profilePictureUrl = url
        }
    }
    
    func updateDeviceToken(_ token: String) async throws {
        guard let userId = try? await Amplify.Auth.getCurrentUser().userId else {
            return
        }
        
        try await appSyncService.updateUser(userId: userId, deviceToken: token)
    }
    
    // MARK: - Password Management
    
    func resetPassword(email: String) async throws {
        try await Amplify.Auth.resetPassword(for: email)
    }
    
    func confirmResetPassword(
        email: String,
        newPassword: String,
        confirmationCode: String
    ) async throws {
        try await Amplify.Auth.confirmResetPassword(
            for: email,
            with: newPassword,
            confirmationCode: confirmationCode
        )
    }
}

