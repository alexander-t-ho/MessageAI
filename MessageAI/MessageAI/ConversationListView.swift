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
    @EnvironmentObject var webSocketService: WebSocketService
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var networkToggle: Bool = false
    @State private var simulateOffline: Bool = false
    @State private var syncService: SyncService?
    
    private var databaseService: DatabaseService {
        DatabaseService(modelContext: modelContext)
    }
    
    // Filter out deleted conversations to prevent crashes
    private var activeConversations: [ConversationData] {
        conversations.filter { !$0.isDeleted }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                if activeConversations.isEmpty {
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
                        ForEach(activeConversations) { conversation in
                            NavigationLink(value: conversation) {
                                ConversationRow(conversation: conversation)
                            }
                            .id(conversation.id) // Force refresh on deletion
                        }
                        .onDelete(perform: deleteConversations)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Messages")
            .navigationDestination(for: ConversationData.self) { convo in
                // Ensure conversation still exists and is not deleted before navigating
                if activeConversations.contains(where: { $0.id == convo.id }) && !convo.isDeleted {
                    ChatView(conversation: convo)
                } else {
                    EmptyView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Toggle(isOn: $simulateOffline) {
                        Image(systemName: simulateOffline ? "icloud.slash" : "icloud")
                    }
                    .labelsHidden()
                    .onChange(of: simulateOffline) { _, newVal in
                        print("🛜 Simulate Offline toggled -> \(newVal ? "ON" : "OFF")")
                        webSocketService.simulateOffline = newVal
                        if newVal {
                            print("🛜 Disconnecting WebSocket due to Simulate Offline ON")
                            webSocketService.disconnect()
                        } else if let uid = authViewModel.currentUser?.id {
                            print("🛜 Reconnecting WebSocket due to Simulate Offline OFF for userId: \(uid)")
                            webSocketService.connect(userId: uid)
                        }
                    }
                    .accessibilityLabel("Simulate Offline")
                }
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
            .onChange(of: webSocketService.receivedMessages.count) { oldValue, newValue in
                guard newValue > oldValue, let payload = webSocketService.receivedMessages.last else { return }
                handleIncomingMessage(payload)
            }
            .onChange(of: webSocketService.connectionState) { _, state in
                if case .connected = state {
                    if syncService == nil {
                        syncService = SyncService(webSocket: webSocketService, modelContext: modelContext)
                    }
                    Task { await syncService?.processQueueIfPossible() }
                }
            }
            .onAppear {
                if syncService == nil {
                    syncService = SyncService(webSocket: webSocketService, modelContext: modelContext)
                }
                Task { await syncService?.processQueueIfPossible() }
            }
        }
    }
    
    private func deleteConversations(at offsets: IndexSet) {
        // Convert IndexSet to array of conversations before deletion
        // Use activeConversations since that's what's displayed in the list
        let conversationsToDelete: [ConversationData] = offsets.compactMap { index in
            guard index < activeConversations.count else { return nil }
            return activeConversations[index]
        }
        
        for conversation in conversationsToDelete {
            // Skip if already deleted
            guard !conversation.isDeleted else { continue }
            
            print("🗑️ Deleting conversation: \(conversation.id)")
            
            // Delete any draft for this conversation first
            if let draft = try? modelContext.fetch(FetchDescriptor<DraftData>()).first(where: { $0.conversationId == conversation.id }) {
                modelContext.delete(draft)
            }
            
            do {
                try databaseService.deleteConversation(conversationId: conversation.id)
                print("✅ Conversation deleted successfully")
            } catch {
                print("❌ Error deleting conversation: \(error)")
            }
        }
    }
}

extension ConversationListView {
    private func handleIncomingMessage(_ payload: MessagePayload) {
        // Ignore messages that originate from this device's user (defensive)
        if payload.senderId == authViewModel.currentUser?.id { return }
        
        let timestamp = ISO8601DateFormatter().date(from: payload.timestamp) ?? Date()
        
        // Save the message locally (avoid duplicates)
        let exists = (try? modelContext.fetch(FetchDescriptor<MessageData>()).contains { $0.id == payload.messageId }) ?? false
        if !exists {
            let message = MessageData(
                id: payload.messageId,
                conversationId: payload.conversationId,
                senderId: payload.senderId,
                senderName: payload.senderName,
                content: payload.content,
                timestamp: timestamp,
                status: payload.status,
                replyToMessageId: payload.replyToMessageId,
                replyToContent: payload.replyToContent,
                replyToSenderName: payload.replyToSenderName
            )
            do { try databaseService.saveMessage(message) } catch { print("❌ Error saving incoming message: \(error)") }
        }
        
        // Find existing conversation or create a minimal one
        if let existing = conversations.first(where: { $0.id == payload.conversationId }) {
            existing.lastMessage = payload.content
            existing.lastMessageTime = timestamp
            do { try modelContext.save() } catch { print("❌ Error updating conversation: \(error)") }
        } else {
            let myUserId = authViewModel.currentUser?.id ?? "unknown-user"
            let convo = ConversationData(
                id: payload.conversationId,
                participantIds: [payload.senderId, myUserId],
                participantNames: [payload.senderName],
                lastMessage: payload.content,
                lastMessageTime: timestamp
            )
            do { try databaseService.saveConversation(convo) } catch { print("❌ Error creating conversation: \(error)") }
        }
    }
}

// MARK: - Conversation Row

struct ConversationRow: View {
    let conversation: ConversationData
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var webSocketService: WebSocketService
    @Query private var allDrafts: [DraftData]
    
    // Get draft for this conversation
    private var draft: DraftData? {
        allDrafts.first { $0.conversationId == conversation.id }
    }
    
    private var databaseService: DatabaseService {
        DatabaseService(modelContext: modelContext)
    }
    
    // Get recipient ID (other participant in conversation)
    private var recipientId: String? {
        guard !conversation.isDeleted else { return nil }
        return conversation.participantIds.first { $0 != authViewModel.currentUser?.id }
    }
    
    // Check if recipient is online
    private var isOnline: Bool {
        if let id = recipientId {
            let online = webSocketService.userPresence[id] ?? false
            print("🔍 Checking online status for \(displayName) (id: \(id)): \(online ? "ONLINE" : "OFFLINE")")
            print("   All online users: \(webSocketService.userPresence.filter { $0.value }.map { $0.key })")
            return online
        }
        return false
    }
    
    var body: some View {
        // Safety check: Don't render if conversation appears to be deleted
        Group {
            if conversation.isDeleted {
                EmptyView()
            } else {
                rowContent
            }
        }
    }
    
    private var rowContent: some View {
        HStack(spacing: 12) {
            // Avatar with online indicator
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(avatarColor)
                    .frame(width: 56, height: 56)
                    .overlay(
                        Text(displayName.prefix(1).uppercased())
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    )
                
                // Online indicator
                if isOnline {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 14, height: 14)
                        .overlay(
                            Circle()
                                .stroke(Color(.systemBackground), lineWidth: 2)
                        )
                        .offset(x: 2, y: 2)
                }
            }
            
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
                    // Show draft if exists, otherwise show last message
                    if let draft = draft {
                        // Draft indicator
                        HStack(spacing: 4) {
                            Text("Draft:")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.red)
                            
                            Text(draft.draftContent)
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        .lineLimit(2)
                    } else if let lastMessage = conversation.lastMessage {
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
        // Safety check for deleted conversations
        guard !conversation.isDeleted else {
            return "Deleted Conversation"
        }
        
        if conversation.isGroupChat {
            return conversation.groupName ?? "Group Chat"
        } else {
            // Get other participant's name (not current user)
            // Safety: Handle empty participantNames array
            let names = conversation.participantNames
            guard !names.isEmpty else {
                return "Unknown User"
            }
            return names.first ?? "Unknown User"
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
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var searchQuery = ""
    @State private var searchResults: [UserSearchResult] = []
    @State private var isSearching = false
    @State private var selectedUser: UserSearchResult?
    
    private var databaseService: DatabaseService {
        DatabaseService(modelContext: modelContext)
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search by name or email", text: $searchQuery)
                        .autocapitalization(.none)
                        .textContentType(.name)
                        .onChange(of: searchQuery) { oldValue, newValue in
                            Task {
                                await performSearch(query: newValue)
                            }
                        }
                    
                    if isSearching {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.8)
                    }
                    
                    if !searchQuery.isEmpty {
                        Button(action: { searchQuery = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.gray)
                        }
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                
                // Search results or empty state
                if searchQuery.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.5))
                            .padding(.top, 80)
                        
                        Text("Search for People")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        Text("Enter a name or email to find users")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                } else if searchResults.isEmpty && !isSearching {
                    VStack(spacing: 20) {
                        Image(systemName: "person.fill.questionmark")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.5))
                            .padding(.top, 80)
                        
                        Text("No Users Found")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        Text("Try a different name or email")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                } else {
                    List(searchResults) { user in
                        Button(action: {
                            createConversation(with: user)
                        }) {
                            HStack(spacing: 12) {
                                // Avatar
                                Circle()
                                    .fill(avatarColor(for: user.name))
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        Text(user.name.prefix(1).uppercased())
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                    )
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(user.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    Text(user.email)
                                        .font(.subheadline)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            .padding(.vertical, 8)
                        }
                    }
                    .listStyle(.plain)
                }
                
                Spacer()
            }
            .navigationTitle("New Conversation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func performSearch(query: String) async {
        guard !query.isEmpty && query.count >= 2 else {
            searchResults = []
            return
        }
        
        isSearching = true
        
        do {
            // Small delay to avoid too many requests while typing
            try await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            
            // Only search if query hasn't changed
            guard searchQuery == query else { return }
            
            let results = try await NetworkService.shared.searchUsers(query: query)
            
            await MainActor.run {
                // Filter out current user from results
                if let currentUserId = authViewModel.currentUser?.id {
                    searchResults = results.filter { $0.userId != currentUserId }
                } else {
                    searchResults = results
                }
                isSearching = false
            }
        } catch {
            await MainActor.run {
                print("❌ Search error: \(error)")
                searchResults = []
                isSearching = false
            }
        }
    }
    
    private func createConversation(with user: UserSearchResult) {
        guard let currentUser = authViewModel.currentUser else {
            print("❌ No current user")
            return
        }
        
        // Create conversation with both participant IDs
        let conversation = ConversationData(
            participantIds: [currentUser.id, user.userId],
            participantNames: [user.name] // Just store other user's name for display
        )
        
        do {
            try databaseService.saveConversation(conversation)
            print("✅ Created conversation with \(user.name)")
            dismiss()
        } catch {
            print("❌ Error creating conversation: \(error)")
        }
    }
    
    private func avatarColor(for name: String) -> Color {
        let colors: [Color] = [.blue, .purple, .green, .orange, .pink, .red]
        let index = abs(name.hashValue % colors.count)
        return colors[index]
    }
}

#Preview {
    ConversationListView()
        .modelContainer(for: [ConversationData.self, MessageData.self, DraftData.self])
}

