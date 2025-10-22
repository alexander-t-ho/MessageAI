//
//  GroupViewModel.swift
//  MessageAI
//
//  Created on 10/20/2025.
//

import Foundation
import FirebaseFirestore

@MainActor
class GroupViewModel: ObservableObject {
    @Published var groups: [Group] = []
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var isSending = false
    
    private let firestoreService = FirestoreService()
    private var groupsListener: ListenerRegistration?
    private var messagesListener: ListenerRegistration?
    
    let currentUserId: String
    var currentGroupId: String?
    
    init(currentUserId: String) {
        self.currentUserId = currentUserId
    }
    
    func startListeningToGroups() {
        isLoading = true
        
        groupsListener = firestoreService.observeGroups(userId: currentUserId) { [weak self] groups in
            self?.groups = groups
            self?.isLoading = false
        }
    }
    
    func startListeningToMessages(groupId: String) {
        currentGroupId = groupId
        
        messagesListener = firestoreService.observeGroupMessages(groupId: groupId) { [weak self] messages in
            self?.messages = messages
        }
    }
    
    func stopListening() {
        groupsListener?.remove()
        messagesListener?.remove()
    }
    
    func createGroup(name: String, participantIds: [String]) async -> String? {
        do {
            return try await firestoreService.createGroup(name: name, participantIds: participantIds)
        } catch {
            print("Error creating group: \(error)")
            return nil
        }
    }
    
    func sendMessage(groupId: String, text: String, imageUrl: String? = nil) async {
        guard !text.isEmpty || imageUrl != nil else { return }
        
        isSending = true
        
        do {
            try await firestoreService.sendGroupMessage(
                groupId: groupId,
                text: text,
                type: imageUrl != nil ? .image : .text,
                imageUrl: imageUrl
            )
        } catch {
            print("Error sending group message: \(error)")
        }
        
        isSending = false
    }
    
    deinit {
        stopListening()
    }
}

