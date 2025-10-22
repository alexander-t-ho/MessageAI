//
//  ChatViewModel.swift
//  MessageAI
//
//  Created on 10/20/2025.
//

import Foundation
import FirebaseFirestore
import SwiftData

@MainActor
class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isTyping = false
    @Published var isOtherUserTyping = false
    @Published var isLoading = false
    @Published var isSending = false
    
    private let firestoreService = FirestoreService()
    private let networkMonitor = NetworkMonitor()
    private var messagesListener: ListenerRegistration?
    private var typingTimer: Timer?
    private var modelContext: ModelContext?
    
    let chatId: String
    let currentUserId: String
    
    init(chatId: String, currentUserId: String) {
        self.chatId = chatId
        self.currentUserId = currentUserId
    }
    
    func setModelContext(_ context: ModelContext) {
        self.modelContext = context
    }
    
    func startListening() {
        isLoading = true
        
        // Load cached messages first
        loadCachedMessages()
        
        // Listen to Firestore messages
        messagesListener = firestoreService.observeMessages(chatId: chatId) { [weak self] messages in
            guard let self = self else { return }
            self.messages = messages
            self.isLoading = false
            
            // Cache messages locally
            self.cacheMessages(messages)
            
            // Mark messages as read
            let unreadMessages = messages.filter { 
                $0.senderId != self.currentUserId && $0.status != .read 
            }
            if !unreadMessages.isEmpty {
                Task {
                    try? await self.markMessagesAsRead(messageIds: unreadMessages.compactMap { $0.id })
                }
            }
        }
    }
    
    func stopListening() {
        messagesListener?.remove()
    }
    
    func sendMessage(text: String, imageUrl: String? = nil) async {
        guard !text.isEmpty || imageUrl != nil else { return }
        
        isSending = true
        
        // Create optimistic message
        let optimisticMessage = Message(
            id: UUID().uuidString,
            chatId: chatId,
            groupId: nil,
            senderId: currentUserId,
            senderName: "",
            text: text,
            type: imageUrl != nil ? .image : .text,
            imageUrl: imageUrl,
            timestamp: Date(),
            status: .sending
        )
        
        messages.append(optimisticMessage)
        
        do {
            if networkMonitor.isConnected {
                try await firestoreService.sendMessage(chatId: chatId, text: text, type: imageUrl != nil ? .image : .text, imageUrl: imageUrl)
            } else {
                // Queue for later sync
                cacheMessageForSync(optimisticMessage)
            }
        } catch {
            print("Error sending message: \(error)")
            // Update status to failed
            if let index = messages.firstIndex(where: { $0.id == optimisticMessage.id }) {
                messages[index] = Message(
                    id: optimisticMessage.id,
                    chatId: chatId,
                    groupId: nil,
                    senderId: currentUserId,
                    senderName: "",
                    text: text,
                    type: .text,
                    imageUrl: nil,
                    timestamp: Date(),
                    status: .failed
                )
            }
        }
        
        isSending = false
    }
    
    func updateTypingStatus(_ isTyping: Bool) {
        self.isTyping = isTyping
        
        typingTimer?.invalidate()
        
        if isTyping {
            Task {
                try? await firestoreService.updateTypingStatus(chatId: chatId, userId: currentUserId, isTyping: true)
            }
            
            // Auto-clear after 3 seconds
            typingTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
                guard let self = self else { return }
                Task {
                    try? await self.firestoreService.updateTypingStatus(chatId: self.chatId, userId: self.currentUserId, isTyping: false)
                }
            }
        } else {
            Task {
                try? await firestoreService.updateTypingStatus(chatId: chatId, userId: currentUserId, isTyping: false)
            }
        }
    }
    
    private func markMessagesAsRead(messageIds: [String]) async throws {
        try await firestoreService.markMessagesAsRead(chatId: chatId, messageIds: messageIds)
    }
    
    // MARK: - Offline Support
    
    private func loadCachedMessages() {
        guard let modelContext = modelContext else { return }
        
        let fetchDescriptor = FetchDescriptor<CachedMessage>(
            predicate: #Predicate { $0.chatId == chatId },
            sortBy: [SortDescriptor(\.timestamp, order: .forward)]
        )
        
        do {
            let cachedMessages = try modelContext.fetch(fetchDescriptor)
            self.messages = cachedMessages.map { $0.toMessage() }
        } catch {
            print("Error loading cached messages: \(error)")
        }
    }
    
    private func cacheMessages(_ messages: [Message]) {
        guard let modelContext = modelContext else { return }
        
        for message in messages {
            let cachedMessage = CachedMessage(from: message, needsSync: false)
            modelContext.insert(cachedMessage)
        }
        
        try? modelContext.save()
    }
    
    private func cacheMessageForSync(_ message: Message) {
        guard let modelContext = modelContext else { return }
        
        let cachedMessage = CachedMessage(from: message, needsSync: true)
        modelContext.insert(cachedMessage)
        try? modelContext.save()
    }
    
    func syncPendingMessages() async {
        guard let modelContext = modelContext else { return }
        guard networkMonitor.isConnected else { return }
        
        let fetchDescriptor = FetchDescriptor<CachedMessage>(
            predicate: #Predicate { $0.needsSync == true && $0.chatId == chatId }
        )
        
        do {
            let pendingMessages = try modelContext.fetch(fetchDescriptor)
            
            for cachedMessage in pendingMessages {
                let message = cachedMessage.toMessage()
                try await firestoreService.sendMessage(
                    chatId: chatId,
                    text: message.text,
                    type: message.type,
                    imageUrl: message.imageUrl
                )
                
                // Mark as synced
                cachedMessage.needsSync = false
            }
            
            try modelContext.save()
        } catch {
            print("Error syncing messages: \(error)")
        }
    }
    
    deinit {
        stopListening()
        typingTimer?.invalidate()
    }
}

