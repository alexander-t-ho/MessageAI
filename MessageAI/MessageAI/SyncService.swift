//
//  SyncService.swift
//  MessageAI
//

import Foundation
import SwiftData
import Combine

@MainActor
final class SyncService: ObservableObject {
    @Published private(set) var isSyncing = false
    
    private let webSocket: WebSocketService
    private let modelContext: ModelContext
    
    init(webSocket: WebSocketService, modelContext: ModelContext) {
        self.webSocket = webSocket
        self.modelContext = modelContext
    }
    
    func enqueue(message: MessageData, recipientId: String) {
        let pending = PendingMessageData(
            messageId: message.id,
            conversationId: message.conversationId,
            senderId: message.senderId,
            senderName: message.senderName,
            recipientId: recipientId,
            content: message.content,
            timestamp: message.timestamp
        )
        modelContext.insert(pending)
        try? modelContext.save()
    }
    
    func processQueueIfPossible() async {
        guard case .connected = webSocket.connectionState else { return }
        
        isSyncing = true
        defer { isSyncing = false }
        
        let fetch = FetchDescriptor<PendingMessageData>()
        guard let queued = try? modelContext.fetch(fetch), !queued.isEmpty else { return }
        
        for item in queued {
            // Reconstruct minimal send; ChatView will already update UI
            webSocket.sendMessage(
                messageId: item.messageId,
                conversationId: item.conversationId,
                senderId: item.senderId,
                senderName: item.senderName,
                recipientId: item.recipientId,
                content: item.content,
                timestamp: item.timestamp
            )
            // Remove from queue on attempt; in Phase 6 we can add delivery acks
            modelContext.delete(item)
        }
        try? modelContext.save()
    }
}


