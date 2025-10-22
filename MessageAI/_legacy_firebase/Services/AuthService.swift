//
//  AuthService.swift
//  MessageAI
//
//  Created on 10/20/2025.
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

class AuthService: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    
    private let db = Firestore.firestore()
    private var userListener: ListenerRegistration?
    
    init() {
        // Check if user is already signed in
        if let firebaseUser = Auth.auth().currentUser {
            isAuthenticated = true
            loadUserData(userId: firebaseUser.uid)
        }
        
        // Listen for auth state changes
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            if let user = user {
                self?.isAuthenticated = true
                self?.loadUserData(userId: user.uid)
            } else {
                self?.isAuthenticated = false
                self?.currentUser = nil
                self?.userListener?.remove()
            }
        }
    }
    
    func register(email: String, password: String, displayName: String) async throws {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        
        // Create user document in Firestore
        let user = User(
            id: result.user.uid,
            email: email,
            displayName: displayName,
            profilePictureUrl: nil,
            isOnline: true,
            lastSeen: Date(),
            createdAt: Date(),
            fcmToken: nil
        )
        
        try db.collection("users").document(result.user.uid).setData(from: user)
        
        await MainActor.run {
            self.currentUser = user
            self.isAuthenticated = true
        }
    }
    
    func login(email: String, password: String) async throws {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        loadUserData(userId: result.user.uid)
        
        // Update online status
        try await updateOnlineStatus(true)
    }
    
    func logout() throws {
        Task {
            try? await updateOnlineStatus(false)
        }
        
        try Auth.auth().signOut()
        
        await MainActor.run {
            self.isAuthenticated = false
            self.currentUser = nil
            self.userListener?.remove()
        }
    }
    
    func updateOnlineStatus(_ isOnline: Bool) async throws {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        try await db.collection("users").document(userId).updateData([
            "isOnline": isOnline,
            "lastSeen": Timestamp(date: Date())
        ])
    }
    
    func updateProfilePicture(url: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        try await db.collection("users").document(userId).updateData([
            "profilePictureUrl": url
        ])
        
        await MainActor.run {
            self.currentUser?.profilePictureUrl = url
        }
    }
    
    func updateFCMToken(_ token: String) async throws {
        guard let userId = Auth.auth().currentUser?.uid else { return }
        
        try await db.collection("users").document(userId).updateData([
            "fcmToken": token
        ])
    }
    
    private func loadUserData(userId: String) {
        userListener = db.collection("users").document(userId).addSnapshotListener { [weak self] snapshot, error in
            guard let data = snapshot?.data(),
                  let user = try? Firestore.Decoder().decode(User.self, from: data) else {
                return
            }
            
            DispatchQueue.main.async {
                self?.currentUser = user
            }
        }
    }
}

