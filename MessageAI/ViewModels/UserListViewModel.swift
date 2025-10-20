//
//  UserListViewModel.swift
//  MessageAI
//
//  Created on 10/20/2025.
//

import Foundation
import FirebaseFirestore

@MainActor
class UserListViewModel: ObservableObject {
    @Published var users: [User] = []
    @Published var chats: [Chat] = []
    @Published var isLoading = false
    
    private let firestoreService = FirestoreService()
    private var usersListener: ListenerRegistration?
    private var chatsListener: ListenerRegistration?
    
    func startListening(currentUserId: String) {
        isLoading = true
        
        // Listen to users
        usersListener = firestoreService.observeUsers { [weak self] users in
            self?.users = users.filter { $0.id != currentUserId }
            self?.isLoading = false
        }
        
        // Listen to chats
        chatsListener = firestoreService.observeChats(userId: currentUserId) { [weak self] chats in
            self?.chats = chats
        }
    }
    
    func stopListening() {
        usersListener?.remove()
        chatsListener?.remove()
    }
    
    func createChat(with userId: String) async -> String? {
        do {
            return try await firestoreService.createOrGetChat(with: userId)
        } catch {
            print("Error creating chat: \(error)")
            return nil
        }
    }
    
    deinit {
        stopListening()
    }
}

