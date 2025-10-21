//
//  ConversationListView.swift
//  MessageAI
//
//  Main conversation list showing all chats
//

import SwiftUI
import SwiftData

struct ConversationListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ConversationData.lastMessageTime, order: .reverse) private var conversations: [ConversationData]
    @State private var showNewChat = false
    @State private var selectedConversation: ConversationData?
    
    private var databaseService: DatabaseService {
        DatabaseService(modelContext: modelContext)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                if conversations.isEmpty {
                    // Empty state
                    VStack(spacing: 20) {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 80))
                            .foregroundColor(.gray.opacity(0.5))
                        
                        Text("No Conversations Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Tap + to start a new conversation")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        
                        Button(action: { showNewChat = true }) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Start New Chat")
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .padding(.top, 20)
                    }
                } else {
                    // Conversation list
                    List {
                        ForEach(conversations) { conversation in
                            NavigationLink(destination: ChatView(conversation: conversation)) {
                                ConversationRow(conversation: conversation)
                            }
                        }
                        .onDelete(perform: deleteConversations)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Messages")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showNewChat = true }) {
                        Image(systemName: "square.and.pencil")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showNewChat) {
                NewConversationView()
            }
        }
    }
    
    private func deleteConversations(at offsets: IndexSet) {
        for index in offsets {
            let conversation = conversations[index]
            do {
                try databaseService.deleteConversation(conversationId: conversation.id)
            } catch {
                print("Error deleting conversation: \(error)")
            }
        }
    }
}

// MARK: - Conversation Row

struct ConversationRow: View {
    let conversation: ConversationData
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar
            Circle()
                .fill(avatarColor)
                .frame(width: 56, height: 56)
                .overlay(
                    Text(displayName.prefix(1).uppercased())
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                )
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(displayName)
                        .font(.headline)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if let lastMessageTime = conversation.lastMessageTime {
                        Text(formatTime(lastMessageTime))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                HStack {
                    if let lastMessage = conversation.lastMessage {
                        Text(lastMessage)
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .lineLimit(2)
                    } else {
                        Text("No messages yet")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .italic()
                    }
                    
                    Spacer()
                    
                    if conversation.unreadCount > 0 {
                        Text("\(conversation.unreadCount)")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private var displayName: String {
        if conversation.isGroupChat {
            return conversation.groupName ?? "Group Chat"
        } else {
            // Get other participant's name (not current user)
            return conversation.participantNames.first ?? "Unknown"
        }
    }
    
    private var avatarColor: Color {
        // Generate consistent color based on name
        let colors: [Color] = [.blue, .purple, .green, .orange, .pink, .red]
        let index = abs(displayName.hashValue % colors.count)
        return colors[index]
    }
    
    private func formatTime(_ date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDate(date, equalTo: now, toGranularity: .weekOfYear) {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"  // Day name
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: date)
        }
    }
}

// MARK: - New Conversation View

struct NewConversationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var recipientName = ""
    @State private var recipientId = ""
    
    private var databaseService: DatabaseService {
        DatabaseService(modelContext: modelContext)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Recipient Name", text: $recipientName)
                        .autocapitalization(.words)
                    
                    TextField("Recipient ID (for testing)", text: $recipientId)
                        .autocapitalization(.none)
                }
                
                Section {
                    Text("For testing: Use any name and ID to create a test conversation")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
            }
            .navigationTitle("New Conversation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createConversation()
                    }
                    .disabled(recipientName.isEmpty || recipientId.isEmpty)
                }
            }
        }
    }
    
    private func createConversation() {
        // For testing: create a demo conversation
        let conversation = ConversationData(
            participantIds: ["current-user-id", recipientId],
            participantNames: [recipientName]
        )
        
        do {
            try databaseService.saveConversation(conversation)
            dismiss()
        } catch {
            print("Error creating conversation: \(error)")
        }
    }
}

#Preview {
    ConversationListView()
        .modelContainer(for: [ConversationData.self, MessageData.self, DraftData.self])
}

