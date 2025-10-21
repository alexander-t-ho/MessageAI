//
//  DatabaseTestView.swift
//  MessageAI
//
//  Test view to verify local database persistence
//

import SwiftUI
import SwiftData

struct DatabaseTestView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var messages: [MessageData]
    @Query private var conversations: [ConversationData]
    @Query private var drafts: [DraftData]
    
    @State private var testMessage = ""
    @State private var draftText = ""
    @State private var statusMessage = ""
    @State private var messageCount = 0
    @State private var conversationCount = 0
    
    private var databaseService: DatabaseService {
        DatabaseService(modelContext: modelContext)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header
                    VStack(spacing: 10) {
                        Image(systemName: "cylinder.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        Text("Database Test")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Phase 2: Local Persistence")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    
                    // Statistics Card
                    VStack(spacing: 15) {
                        Text("Current Data")
                            .font(.headline)
                        
                        HStack(spacing: 30) {
                            VStack {
                                Text("\(messages.count)")
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(.blue)
                                Text("Messages")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            VStack {
                                Text("\(conversations.count)")
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(.green)
                                Text("Conversations")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            
                            VStack {
                                Text("\(drafts.count)")
                                    .font(.system(size: 36, weight: .bold))
                                    .foregroundColor(.orange)
                                Text("Drafts")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(15)
                    .padding(.horizontal)
                    
                    // Test Input
                    VStack(spacing: 15) {
                        Text("Test Message Input")
                            .font(.headline)
                        
                        TextField("Type a test message", text: $testMessage)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal)
                        
                        Button(action: saveTestMessage) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Save Test Message")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(testMessage.isEmpty)
                        .padding(.horizontal)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(15)
                    .shadow(radius: 3)
                    .padding(.horizontal)
                    
                    // Draft Testing
                    VStack(spacing: 15) {
                        Text("Test Draft Messages")
                            .font(.headline)
                        
                        TextField("Type a draft message", text: $draftText)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal)
                        
                        HStack(spacing: 10) {
                            Button(action: saveDraft) {
                                HStack {
                                    Image(systemName: "doc.text.fill")
                                    Text("Save Draft")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.orange)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .disabled(draftText.isEmpty)
                            
                            Button(action: loadDraft) {
                                HStack {
                                    Image(systemName: "arrow.down.doc.fill")
                                    Text("Load Draft")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.purple)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(15)
                    .shadow(radius: 3)
                    .padding(.horizontal)
                    
                    // Test Actions
                    VStack(spacing: 10) {
                        Text("Test Actions")
                            .font(.headline)
                        
                        Button(action: createTestConversation) {
                            actionButton(
                                icon: "bubble.left.and.bubble.right.fill",
                                text: "Create Test Conversation",
                                color: .green
                            )
                        }
                        
                        Button(action: create10Messages) {
                            actionButton(
                                icon: "envelope.fill",
                                text: "Create 10 Test Messages",
                                color: .orange
                            )
                        }
                        
                        Button(action: testPersistence) {
                            actionButton(
                                icon: "checkmark.circle.fill",
                                text: "Test Persistence",
                                color: .purple
                            )
                        }
                        
                        Button(action: testDraftPersistence) {
                            actionButton(
                                icon: "doc.badge.clock",
                                text: "Test Draft Persistence",
                                color: .cyan
                            )
                        }
                        
                        Button(action: clearAllData) {
                            actionButton(
                                icon: "trash.fill",
                                text: "Clear All Data",
                                color: .red
                            )
                        }
                    }
                    .padding()
                    
                    // Status Message
                    if !statusMessage.isEmpty {
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding()
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(10)
                            .padding(.horizontal)
                    }
                    
                    // Messages List
                    if !messages.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Stored Messages")
                                .font(.headline)
                                .padding(.horizontal)
                            
                            ForEach(messages) { message in
                                MessageRow(message: message)
                            }
                        }
                        .padding(.top)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Database Test")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    // MARK: - Actions
    
    private func saveTestMessage() {
        guard !testMessage.isEmpty else { return }
        
        let message = MessageData(
            conversationId: "test-conversation-1",
            senderId: "current-user",
            senderName: "You",
            content: testMessage,
            isSentByCurrentUser: true
        )
        
        do {
            try databaseService.saveMessage(message)
            statusMessage = "✅ Message saved successfully!"
            testMessage = ""
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                statusMessage = ""
            }
        } catch {
            statusMessage = "❌ Error: \(error.localizedDescription)"
        }
    }
    
    private func saveDraft() {
        guard !draftText.isEmpty else { return }
        
        do {
            try databaseService.saveDraft(
                conversationId: "test-conversation-1",
                content: draftText
            )
            statusMessage = "📝 Draft saved! (Try closing and reopening the app)"
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                statusMessage = ""
            }
        } catch {
            statusMessage = "❌ Error: \(error.localizedDescription)"
        }
    }
    
    private func loadDraft() {
        do {
            if let draft = try databaseService.getDraft(for: "test-conversation-1") {
                draftText = draft.draftContent
                statusMessage = "✅ Draft loaded successfully!"
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    statusMessage = ""
                }
            } else {
                statusMessage = "ℹ️ No draft found for this conversation"
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    statusMessage = ""
                }
            }
        } catch {
            statusMessage = "❌ Error: \(error.localizedDescription)"
        }
    }
    
    private func createTestConversation() {
        let conversation = ConversationData(
            id: "test-conversation-\(UUID().uuidString.prefix(8))",
            participantIds: ["user1", "user2"],
            participantNames: ["Alice", "Bob"],
            lastMessage: "Hey! How are you?",
            lastMessageTime: Date()
        )
        
        do {
            try databaseService.saveConversation(conversation)
            statusMessage = "✅ Conversation created!"
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                statusMessage = ""
            }
        } catch {
            statusMessage = "❌ Error: \(error.localizedDescription)"
        }
    }
    
    private func create10Messages() {
        do {
            for i in 1...10 {
                let message = MessageData(
                    conversationId: "test-conversation-1",
                    senderId: i % 2 == 0 ? "current-user" : "other-user",
                    senderName: i % 2 == 0 ? "You" : "Friend",
                    content: "Test message number \(i)",
                    timestamp: Date().addingTimeInterval(Double(i)),
                    isSentByCurrentUser: i % 2 == 0
                )
                try databaseService.saveMessage(message)
            }
            statusMessage = "✅ Created 10 test messages!"
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                statusMessage = ""
            }
        } catch {
            statusMessage = "❌ Error: \(error.localizedDescription)"
        }
    }
    
    private func testPersistence() {
        do {
            let count = try databaseService.getTotalMessageCount()
            statusMessage = "✅ Persistence working! Found \(count) messages stored locally."
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                statusMessage = ""
            }
        } catch {
            statusMessage = "❌ Error: \(error.localizedDescription)"
        }
    }
    
    private func testDraftPersistence() {
        do {
            let draftCount = drafts.count
            if draftCount > 0 {
                statusMessage = "✅ Draft persistence working! Found \(draftCount) draft(s). Close & reopen app to verify!"
            } else {
                statusMessage = "ℹ️ No drafts found. Create a draft first, then close and reopen the app to test persistence."
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
                statusMessage = ""
            }
        } catch {
            statusMessage = "❌ Error: \(error.localizedDescription)"
        }
    }
    
    private func clearAllData() {
        do {
            try databaseService.clearAllData()
            statusMessage = "🗑️ All data cleared!"
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                statusMessage = ""
            }
        } catch {
            statusMessage = "❌ Error: \(error.localizedDescription)"
        }
    }
    
    // MARK: - Helper Views
    
    private func actionButton(icon: String, text: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon)
            Text(text)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color)
        .foregroundColor(.white)
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

// MARK: - Message Row

struct MessageRow: View {
    let message: MessageData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(message.senderName)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(message.isSentByCurrentUser ? .blue : .green)
                
                Spacer()
                
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            Text(message.content)
                .font(.body)
            
            HStack {
                Text("Status: \(message.status)")
                    .font(.caption2)
                    .foregroundColor(.gray)
                
                Spacer()
                
                if message.isRead {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

#Preview {
    DatabaseTestView()
        .modelContainer(for: [MessageData.self, ConversationData.self, ContactData.self, DraftData.self])
}

