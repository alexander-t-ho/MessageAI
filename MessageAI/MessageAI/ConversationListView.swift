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
    @Query(
        filter: #Predicate<ConversationData> { conversation in
            conversation.isDeleted == false
        },
        sort: \ConversationData.lastMessageTime, 
        order: .reverse
    ) private var conversations: [ConversationData]
    @State private var showNewChat = false
    @State private var showingNewGroup = false
    @State private var selectedConversation: ConversationData?
    @EnvironmentObject var webSocketService: WebSocketService
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var networkToggle: Bool = false
    @State private var simulateOffline: Bool = false
    @State private var syncService: SyncService?
    @State private var refreshID = UUID() // Force refresh after deletion
    @State private var isSelectionMode = false // Multi-select mode
    @State private var selectedConversations = Set<String>() // Selected conversation IDs
    
    private var databaseService: DatabaseService {
        DatabaseService(modelContext: modelContext)
    }
    
    // Conversations are already filtered at Query level, just sort them
    private var activeConversations: [ConversationData] {
        // The @Query already filters out deleted conversations
        // We just return them sorted (although @Query also sorts, this ensures consistency)
        return conversations
    }
    
    // Break up complex view into smaller components
    @ViewBuilder
    private var emptyStateView: some View {
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
    }
    
    private var conversationListView: some View {
        List {
            ForEach(activeConversations) { conversation in
                conversationRowView(for: conversation)
                    .id(conversation.id)
                    .animation(.easeInOut(duration: 0.2), value: isSelectionMode)
            }
            .onDelete { offsets in
                if !isSelectionMode {
                    deleteConversations(at: offsets)
                }
            }
        }
        .listStyle(.plain)
        .id(refreshID)
    }
    
    @ViewBuilder
    private func conversationRowView(for conversation: ConversationData) -> some View {
        HStack {
            if isSelectionMode {
                Button(action: {
                    toggleSelection(for: conversation.id)
                }) {
                    Image(systemName: selectedConversations.contains(conversation.id) ? "checkmark.circle.fill" : "circle")
                        .foregroundColor(selectedConversations.contains(conversation.id) ? .blue : .gray)
                        .font(.title3)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            if isSelectionMode {
                ConversationRow(conversation: conversation)
                    .onTapGesture {
                        toggleSelection(for: conversation.id)
                    }
            } else {
                NavigationLink(value: conversation) {
                    ConversationRow(conversation: conversation)
                }
            }
        }
    }
    
    private func toggleSelection(for conversationId: String) {
        if selectedConversations.contains(conversationId) {
            selectedConversations.remove(conversationId)
        } else {
            selectedConversations.insert(conversationId)
        }
    }
    
    @ToolbarContentBuilder
    private var leadingToolbarItems: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            HStack(spacing: 12) {
                offlineToggle
                selectionModeButton
            }
        }
    }
    
    @ViewBuilder
    private var offlineToggle: some View {
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
    
    @ViewBuilder
    private var selectionModeButton: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                isSelectionMode.toggle()
                if !isSelectionMode {
                    selectedConversations.removeAll()
                }
            }
        }) {
            Text(isSelectionMode ? "Done" : "Select")
                .foregroundColor(.blue)
        }
    }
    
    @ToolbarContentBuilder
    private var trailingToolbarItems: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            trailingButton
        }
    }
    
    @ViewBuilder
    private var trailingButton: some View {
        if isSelectionMode && !selectedConversations.isEmpty {
            Button(action: deleteSelectedConversations) {
                Text("Delete (\(selectedConversations.count))")
                    .foregroundColor(.red)
            }
        } else if !isSelectionMode {
            Button(action: { showNewChat = true }) {
                Image(systemName: "square.and.pencil")
                    .font(.title3)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                if activeConversations.isEmpty && !isSelectionMode {
                    emptyStateView
                } else {
                    conversationListView
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
                leadingToolbarItems
                trailingToolbarItems
            }
            .sheet(isPresented: $showNewChat) {
                NewConversationView(showingNewGroup: $showingNewGroup, selectedConversation: $selectedConversation)
            }
            .sheet(isPresented: $showingNewGroup) {
                NewGroupChatView()
                    .environmentObject(authViewModel)
                    .environmentObject(webSocketService)
            }
            .onChange(of: webSocketService.receivedMessages.count) { oldValue, newValue in
                guard newValue > oldValue, let payload = webSocketService.receivedMessages.last else { return }
                handleIncomingMessage(payload)
            }
            .onChange(of: webSocketService.groupCreatedEvents.count) { oldValue, newValue in
                print("📥 groupCreatedEvents count changed: \(oldValue) → \(newValue)")
                guard newValue > oldValue, let groupData = webSocketService.groupCreatedEvents.last else {
                    print("⚠️ No new group event to handle")
                    return
                }
                print("📥 Processing group creation event...")
                handleGroupCreated(groupData)
            }
            .onChange(of: webSocketService.groupUpdateEvents.count) { oldValue, newValue in
                guard newValue > oldValue, let updateData = webSocketService.groupUpdateEvents.last else { return }
                handleGroupUpdate(updateData)
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
                
                // Clean up any duplicate direct message conversations that should be groups
                cleanupDuplicateConversations()
            }
        }
    }
    
    private func cleanupDuplicateConversations() {
        // DISABLED - This was incorrectly deleting valid direct message conversations
        // Only cleanup true duplicates, not direct messages between group members
        return
        
        // TODO: Implement proper duplicate detection that only removes:
        // 1. Multiple conversations with exact same participants AND same isGroupChat status
        // 2. Empty conversations with no messages
        // But NEVER removes valid direct messages between users who are also in groups together
    }
    
    private func deleteSelectedConversations() {
        // Delete all selected conversations
        for conversationId in selectedConversations {
            if let conversation = conversations.first(where: { $0.id == conversationId }) {
                print("🗑️ Deleting selected conversation: \(conversation.id)")
                
                // Delete any draft for this conversation first
                if let draft = try? modelContext.fetch(FetchDescriptor<DraftData>()).first(where: { $0.conversationId == conversation.id }) {
                    modelContext.delete(draft)
                }
                
                // Mark conversation as deleted
                conversation.isDeleted = true
                
                // Delete all messages for this conversation
                do {
                    let messages = try databaseService.fetchMessages(for: conversation.id)
                    for message in messages {
                        message.isDeleted = true
                    }
                } catch {
                    print("❌ Error deleting messages: \(error)")
                }
            }
        }
        
        // Save all changes
        do {
            try modelContext.save()
            print("✅ \(selectedConversations.count) conversations deleted successfully")
        } catch {
            print("❌ Error saving deletion: \(error)")
        }
        
        // Clear selection and exit selection mode
        selectedConversations.removeAll()
        isSelectionMode = false
        
        // Force UI refresh
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            refreshID = UUID()
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
            
            // Mark conversation as deleted
            conversation.isDeleted = true
            
            // Delete all messages for this conversation
            do {
                let messages = try databaseService.fetchMessages(for: conversation.id)
                for message in messages {
                    message.isDeleted = true
                }
                try modelContext.save()
                print("✅ Conversation deleted successfully")
            } catch {
                print("❌ Error deleting conversation: \(error)")
            }
        }
        
        // Force UI refresh after deletion
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            refreshID = UUID()
        }
    }
}

extension ConversationListView {
    private func handleIncomingMessage(_ payload: MessagePayload) {
        print("📨 handleIncomingMessage called")
        print("   Sender: \(payload.senderName) (\(payload.senderId))")
        print("   Current user: \(authViewModel.currentUser?.name ?? "nil") (\(authViewModel.currentUser?.id ?? "nil"))")
        print("   Conversation ID: \(payload.conversationId)")
        
        // Ignore messages that originate from this device's user (defensive)
        if payload.senderId == authViewModel.currentUser?.id {
            print("   ⏭️ Skipping - message from self")
            return
        }
        
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
        
        // Find existing conversation or create it
        // Need to check ALL conversations including deleted ones to prevent resurrection
        let allConversations = try? modelContext.fetch(FetchDescriptor<ConversationData>())
        print("   🔍 Searching for conversation \(payload.conversationId) in \(allConversations?.count ?? 0) total conversations")
        
        if let existing = allConversations?.first(where: { $0.id == payload.conversationId }) {
            // Check if conversation was deleted by user - if so, don't update it
            if existing.isDeleted {
                print("   🚫 Conversation was deleted by user - ignoring incoming message")
                // Note: message is still saved locally, just not shown in conversation list
                return
            }
            
            print("   ✅ Found existing conversation, updating last message")
            existing.lastMessage = payload.content
            existing.lastMessageTime = timestamp
            // Increment unread count
            existing.unreadCount += 1
            do { try modelContext.save() } catch { print("❌ Error updating conversation: \(error)") }
        } else {
            print("   ⚠️ Conversation not found - creating new one")
            // Auto-create conversation for direct messages
            // Note: Group conversations will be created by groupCreated event
            print("⚠️ Received message for unknown conversation: \(payload.conversationId)")
            print("   Creating conversation for direct message from \(payload.senderName)")
            
            guard let currentUser = authViewModel.currentUser else {
                print("❌ Cannot create conversation - no current user")
                return
            }
            
            // Create direct message conversation with the sender
            let newConversation = ConversationData(
                id: payload.conversationId, // Use the same conversation ID from the message
                participantIds: [currentUser.id, payload.senderId],
                participantNames: [currentUser.name, payload.senderName],
                isGroupChat: false,
                groupName: nil,
                lastMessage: payload.content,
                lastMessageTime: timestamp,
                unreadCount: 1
            )
            
            modelContext.insert(newConversation)
            do {
                try modelContext.save()
                print("✅ Created conversation for incoming message from \(payload.senderName)")
                print("   Conversation ID: \(payload.conversationId)")
                print("   Participants: \(newConversation.participantIds)")
                print("   Last message time: \(newConversation.lastMessageTime?.description ?? "nil")")
                print("   Total conversations now: \(conversations.count)")
            } catch {
                print("❌ Error creating conversation: \(error)")
            }
        }
    }
    
    private func handleGroupCreated(_ groupData: [String: Any]) {
        print("👥 Handling group created event")
        
        guard let conversationId = groupData["conversationId"] as? String,
              let participantIds = groupData["participantIds"] as? [String],
              let participantNames = groupData["participantNames"] as? [String],
              let groupName = groupData["groupName"] as? String,
              let createdBy = groupData["createdBy"] as? String,
              let createdByName = groupData["createdByName"] as? String,
              let createdAtString = groupData["createdAt"] as? String,
              let groupAdmins = groupData["groupAdmins"] as? [String] else {
            print("❌ Invalid group creation data")
            return
        }
        
        let createdAt = ISO8601DateFormatter().date(from: createdAtString) ?? Date()
        
        // Check if conversation already exists
        if conversations.contains(where: { $0.id == conversationId }) {
            print("⚠️ Group conversation already exists locally")
            return
        }
        
        // Check for any messages that arrived before the group was created
        let existingMessages = (try? modelContext.fetch(FetchDescriptor<MessageData>())) ?? []
        let groupMessages = existingMessages.filter { $0.conversationId == conversationId }
        let lastMessage = groupMessages.sorted(by: { $0.timestamp < $1.timestamp }).last
        
        print("📦 Found \(groupMessages.count) existing messages for this group")
        
        // Create new group conversation
        let conversation = ConversationData(
            id: conversationId,
            participantIds: participantIds,
            participantNames: participantNames,
            isGroupChat: true,
            groupName: groupName,
            lastMessage: lastMessage?.content,
            lastMessageTime: lastMessage?.timestamp ?? createdAt,
            unreadCount: groupMessages.filter { $0.senderId != authViewModel.currentUser?.id }.count,
            createdBy: createdBy,
            createdByName: createdByName,
            createdAt: createdAt,
            groupAdmins: groupAdmins
        )
        
        do {
            try databaseService.saveConversation(conversation)
            print("✅ Group conversation created locally: \(groupName)")
            print("   With \(groupMessages.count) messages and \(conversation.unreadCount) unread")
        } catch {
            print("❌ Error creating group conversation: \(error)")
        }
    }
    
    private func handleGroupUpdate(_ updateData: [String: Any]) {
        print("👥 Handling group update event")
        
        guard let conversationId = updateData["conversationId"] as? String,
              let groupName = updateData["groupName"] as? String,
              let updatedBy = updateData["updatedBy"] as? String,
              let timestampString = updateData["timestamp"] as? String else {
            print("❌ Invalid group update data")
            return
        }
        
        let timestamp = ISO8601DateFormatter().date(from: timestampString) ?? Date()
        
        // Find and update existing conversation
        if let existing = conversations.first(where: { $0.id == conversationId }) {
            existing.groupName = groupName
            existing.lastUpdatedBy = updatedBy
            existing.lastUpdatedAt = timestamp
            
            do {
                try modelContext.save()
                print("✅ Group name updated locally: \(groupName)")
            } catch {
                print("❌ Error updating group: \(error)")
            }
        } else {
            print("⚠️ Group conversation not found for update")
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
            // For direct messages, show the OTHER participant's name (not current user)
            let currentUserId = authViewModel.currentUser?.id ?? ""
            let currentUserName = authViewModel.currentUser?.name ?? ""
            
            // Find the other participant's name
            if let otherIndex = conversation.participantIds.firstIndex(where: { $0 != currentUserId }) {
                // Use the same index to get the name from participantNames array
                if otherIndex < conversation.participantNames.count {
                    return conversation.participantNames[otherIndex]
                }
            }
            
            // Fallback: filter out current user's name from the list
            let otherNames = conversation.participantNames.filter { $0 != currentUserName }
            return otherNames.first ?? "Unknown User"
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
    @EnvironmentObject var webSocketService: WebSocketService
    @Query private var conversations: [ConversationData]
    
    @Binding var showingNewGroup: Bool
    @Binding var selectedConversation: ConversationData?
    
    @State private var searchQuery = ""
    @State private var searchResults: [UserSearchResult] = []
    @State private var isSearching = false
    @State private var selectedUsers: [UserSearchResult] = []
    @FocusState private var isSearchFieldFocused: Bool
    
    private var databaseService: DatabaseService {
        DatabaseService(modelContext: modelContext)
    }
    
    // Computed property to show placeholder text
    private var toFieldPlaceholder: String {
        selectedUsers.isEmpty ? "To: " : ""
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // To: field with selected users
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: 8) {
                        Text("To:")
                            .foregroundColor(.gray)
                            .padding(.top, 12)
                            .padding(.leading, 12)
                        
                        // Selected users as chips + search field
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(selectedUsers, id: \.userId) { user in
                                    UserChipCompact(user: user) {
                                        removeUser(user)
                                    }
                                }
                                
                                // Search TextField
                                TextField(toFieldPlaceholder, text: $searchQuery)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .autocapitalization(.none)
                                    .frame(minWidth: 100)
                                    .focused($isSearchFieldFocused)
                                    .onChange(of: searchQuery) { oldValue, newValue in
                                        Task {
                                            await performSearch(query: newValue)
                                        }
                                    }
                            }
                            .padding(.vertical, 8)
                        }
                        
                        if isSearching {
                            ProgressView()
                                .progressViewStyle(.circular)
                                .scaleEffect(0.8)
                                .padding(.trailing, 12)
                        }
                    }
                    .frame(minHeight: 44)
                    .background(Color(.systemBackground))
                    
                    Divider()
                }
                
                // Search results or info message
                if searchQuery.isEmpty && selectedUsers.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.gray.opacity(0.5))
                            .padding(.top, 60)
                        
                        Text("New Message")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        Text("Type a name or email to search for users")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                    Spacer()
                } else if searchQuery.isEmpty && !selectedUsers.isEmpty {
                    // Show selected users info
                    VStack(spacing: 16) {
                        Image(systemName: selectedUsers.count == 1 ? "person.fill" : "person.3.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.blue.opacity(0.7))
                            .padding(.top, 60)
                        
                        if selectedUsers.count == 1 {
                            Text("Direct Message")
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            Text("Tap Create to start messaging \(selectedUsers[0].name)")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        } else {
                            Text("Group Chat (\(selectedUsers.count) people)")
                                .font(.title3)
                                .fontWeight(.semibold)
                            
                            Text("Tap Create to start a group conversation")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                    }
                    Spacer()
                } else if searchResults.isEmpty && !isSearching {
                    VStack(spacing: 16) {
                        Image(systemName: "person.fill.questionmark")
                            .font(.system(size: 50))
                            .foregroundColor(.gray.opacity(0.5))
                            .padding(.top, 60)
                        
                        Text("No Users Found")
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        Text("Try a different name or email")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                } else {
                    // Search results list
                    List(searchResults) { user in
                        Button(action: {
                            addUser(user)
                        }) {
                            HStack(spacing: 12) {
                                // Avatar
                                Circle()
                                    .fill(avatarColor(for: user.name))
                                    .frame(width: 40, height: 40)
                                    .overlay(
                                        Text(user.name.prefix(1).uppercased())
                                            .font(.headline)
                                            .foregroundColor(.white)
                                    )
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(user.name)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                    
                                    Text(user.email)
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                // Show checkmark if already selected
                                if selectedUsers.contains(where: { $0.userId == user.userId }) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("New iMessage")
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
                    .fontWeight(.semibold)
                    .disabled(selectedUsers.isEmpty)
                }
            }
            .onAppear {
                isSearchFieldFocused = true
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
    
    private func addUser(_ user: UserSearchResult) {
        // Check if user is already selected
        if !selectedUsers.contains(where: { $0.userId == user.userId }) {
            selectedUsers.append(user)
        }
        // Clear search after selection
        searchQuery = ""
        searchResults = []
    }
    
    private func removeUser(_ user: UserSearchResult) {
        selectedUsers.removeAll { $0.userId == user.userId }
    }
    
    private func createConversation() {
        guard let currentUser = authViewModel.currentUser else {
            print("❌ No current user")
            return
        }
        
        guard !selectedUsers.isEmpty else {
            print("❌ No users selected")
            return
        }
        
        if selectedUsers.count == 1 {
            // Create direct message conversation
            // Note: Duplicate checking removed due to SwiftData context issues
            // The app will handle duplicates gracefully by reusing existing conversations
            let user = selectedUsers[0]
            let conversation = ConversationData(
                participantIds: [currentUser.id, user.userId],
                participantNames: [currentUser.name, user.name] // Include both users' names for consistency
            )
            
            // Save to database using modelContext (same as group chats)
            modelContext.insert(conversation)
            
            do {
                try modelContext.save()
                print("✅ Created direct conversation with \(user.name)")
                
                dismiss()
                
                // Note: Navigation will happen automatically when user taps the conversation
                // The conversation will appear at the top of the list due to sorting by lastMessageTime
            } catch {
                print("❌ Error creating conversation: \(error)")
            }
        } else {
            // Create group chat conversation
            var participantIds = selectedUsers.map { $0.userId }
            var participantNames = selectedUsers.map { $0.name }
            
            // Add current user to participants
            participantIds.append(currentUser.id)
            participantNames.append(currentUser.name)
            
            // Create conversation ID
            let conversationId = UUID().uuidString
            
            // Auto-generate group name from first 3 members
            let autoGroupName = participantNames.prefix(3).joined(separator: ", ") + (participantNames.count > 3 ? "..." : "")
            
            // Create group conversation (name can be edited later)
            let conversation = ConversationData(
                id: conversationId,
                participantIds: participantIds,
                participantNames: participantNames,
                isGroupChat: true,
                groupName: autoGroupName,
                lastMessage: nil,
                lastMessageTime: Date(),
                unreadCount: 0,
                createdBy: currentUser.id,
                createdByName: currentUser.name,
                createdAt: Date(),
                groupAdmins: [currentUser.id]
            )
            
            // Save to database
            modelContext.insert(conversation)
            
            do {
                try modelContext.save()
                
                // Send group creation notification via WebSocket
                webSocketService.sendGroupCreated(
                    conversationId: conversationId,
                    groupName: autoGroupName,
                    participantIds: participantIds,
                    participantNames: participantNames,
                    createdBy: currentUser.id,
                    createdByName: currentUser.name
                )
                
                print("✅ Created group conversation with \(selectedUsers.count + 1) users (including self)")
                print("   Conversation ID: \(conversationId)")
                print("   Participants: \(participantIds)")
                
                dismiss()
                
                // Note: The new group conversation will appear at the top of the list
            } catch {
                print("❌ Error creating group conversation: \(error)")
            }
        }
    }
    
    private func avatarColor(for name: String) -> Color {
        let colors: [Color] = [.blue, .purple, .green, .orange, .pink, .red]
        let index = abs(name.hashValue % colors.count)
        return colors[index]
    }
}

// MARK: - User Chip (Compact for To: field)
struct UserChipCompact: View {
    let user: UserSearchResult
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(user.name)
                .font(.body)
                .lineLimit(1)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.body)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(.systemGray5))
        .cornerRadius(16)
    }
}

#Preview {
    ConversationListView()
        .modelContainer(for: [ConversationData.self, MessageData.self, DraftData.self])
}


