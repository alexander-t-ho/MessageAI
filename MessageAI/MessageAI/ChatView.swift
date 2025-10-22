//
//  ChatView.swift
//  MessageAI
//
//  Chat interface with message bubbles
//

import SwiftUI
import SwiftData

struct ChatView: View {
    let conversation: ConversationData
    
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var webSocketService: WebSocketService
    @Query private var allMessages: [MessageData]
    @Query private var allConversations: [ConversationData]
    @State private var messageText = ""
    @State private var isLoading = false
    @State private var replyingToMessage: MessageData? // Message being replied to
    @State private var showForwardSheet = false
    @State private var messageToForward: MessageData?
    @State private var visibleMessages: [MessageData] = [] // Manually managed visible messages
    @FocusState private var isInputFocused: Bool
    
    private var databaseService: DatabaseService {
        DatabaseService(modelContext: modelContext)
    }
    
    // Get current user ID from auth
    private var currentUserId: String {
        authViewModel.currentUser?.id ?? "unknown-user"
    }
    
    // Get current user name from auth
    private var currentUserName: String {
        authViewModel.currentUser?.name ?? "You"
    }
    
    // Get recipient ID (other participant in conversation)
    private var recipientId: String {
        conversation.participantIds.first { $0 != currentUserId } ?? "unknown-recipient"
    }
    
    // Computed messages from query (for reference)
    private var queriedMessages: [MessageData] {
        allMessages
            .filter { $0.conversationId == conversation.id && !$0.isDeleted }
            .sorted { $0.timestamp < $1.timestamp }
    }
    
    // Other conversations for forwarding
    private var otherConversations: [ConversationData] {
        allConversations.filter { $0.id != conversation.id }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(visibleMessages) { message in
                            MessageBubble(
                                message: message,
                                currentUserId: currentUserId, // Pass current user ID for bubble placement
                                onReply: { replyToMessage(message) },
                                onDelete: { deleteMessage(message) },
                                onEmphasize: { toggleEmphasis(message) },
                                onForward: { forwardMessage(message) },
                                onTapReply: { scrollToMessage($0, proxy: proxy) }
                            )
                            .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: queriedMessages.count) { oldCount, newCount in
                    print("📊 Messages count changed: \(oldCount) → \(newCount)")
                    // Update visible messages when query changes
                    visibleMessages = queriedMessages
                    
                    // Auto-scroll to bottom when new message arrives
                    if newCount > oldCount, let lastMessage = visibleMessages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    print("👁️ ChatView appeared - loading messages")
                    // Initialize visible messages from query
                    visibleMessages = queriedMessages
                    print("📊 Loaded \(visibleMessages.count) messages")
                    
                    // Scroll to bottom on appear
                    if let lastMessage = visibleMessages.last {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                    
                    // Load draft
                    loadDraft()
                }
            }
            
            // Reply banner (shown when replying to a message)
            if let replyMessage = replyingToMessage {
                ReplyBanner(
                    message: replyMessage,
                    onCancel: { cancelReply() }
                )
            }
            
            // Input bar
            HStack(spacing: 12) {
                TextField("Message", text: $messageText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...6)
                    .focused($isInputFocused)
                    .onChange(of: messageText) { _, newValue in
                        // Auto-save draft as user types
                        saveDraft(newValue)
                    }
                
                Button(action: sendMessage) {
                    if isLoading {
                        ProgressView()
                            .frame(width: 32, height: 32)
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                    }
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(.systemBackground))
        }
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showForwardSheet) {
            if let message = messageToForward {
                ForwardMessageView(
                    message: message,
                    conversations: otherConversations,
                    onForward: { conversation in
                        forwardToConversation(message, to: conversation)
                    }
                )
            }
        }
        .onChange(of: webSocketService.receivedMessages.count) { oldCount, newCount in
            // New message received via WebSocket
            if newCount > oldCount, let newMessage = webSocketService.receivedMessages.last {
                handleReceivedMessage(newMessage)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private var displayName: String {
        if conversation.isGroupChat {
            return conversation.groupName ?? "Group Chat"
        } else {
            return conversation.participantNames.first ?? "Unknown"
        }
    }
    
    private func loadDraft() {
        do {
            if let draft = try databaseService.getDraft(for: conversation.id) {
                messageText = draft.draftContent
            }
        } catch {
            print("Error loading draft: \(error)")
        }
    }
    
    private func saveDraft(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        
        do {
            if trimmed.isEmpty {
                // Delete draft if empty
                try databaseService.deleteDraft(for: conversation.id)
            } else {
                // Save draft
                try databaseService.saveDraft(conversationId: conversation.id, content: text)
            }
        } catch {
            print("Error saving draft: \(error)")
        }
    }
    
    private func sendMessage() {
        let text = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        
        isLoading = true
        
        // Create message locally first (optimistic update)
        let message = MessageData(
            conversationId: conversation.id,
            senderId: currentUserId,
            senderName: currentUserName,
            content: text,
            timestamp: Date(),
            status: "sending",
            // No longer passing isSentByCurrentUser - it's computed dynamically!
            replyToMessageId: replyingToMessage?.id,
            replyToContent: replyingToMessage?.content,
            replyToSenderName: replyingToMessage?.senderName
        )
        
        do {
            // Save to local database
            try databaseService.saveMessage(message)
            
            // IMMEDIATELY add to visible messages (optimistic UI update)
            visibleMessages.append(message)
            print("✅ Message added to UI - now showing \(visibleMessages.count) messages")
            
            // Update conversation
            conversation.lastMessage = text
            conversation.lastMessageTime = Date()
            try modelContext.save()
            
            // Clear input, draft, and reply state
            messageText = ""
            replyingToMessage = nil
            try databaseService.deleteDraft(for: conversation.id)
            
            // Phase 4: Send via WebSocket with real user IDs
            webSocketService.sendMessage(
                messageId: message.id,
                conversationId: conversation.id,
                senderId: currentUserId,
                senderName: currentUserName,
                recipientId: recipientId,
                content: text,
                timestamp: Date(),
                replyToMessageId: replyingToMessage?.id,
                replyToContent: replyingToMessage?.content,
                replyToSenderName: replyingToMessage?.senderName
            )
            
            // Mark as sent after brief delay (will be updated by delivery receipt)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                message.status = "sent"
                do {
                    try modelContext.save()
                } catch {
                    print("Error updating message status: \(error)")
                }
                isLoading = false
            }
            
        } catch {
            print("Error sending message: \(error)")
            isLoading = false
        }
    }
    
    private func replyToMessage(_ message: MessageData) {
        replyingToMessage = message
        isInputFocused = true // Focus text field
    }
    
    private func cancelReply() {
        withAnimation {
            replyingToMessage = nil
        }
    }
    
    private func scrollToMessage(_ messageId: String, proxy: ScrollViewProxy) {
        withAnimation {
            proxy.scrollTo(messageId, anchor: .center)
        }
        
        // TODO: Could add a highlight animation here
    }
    
    private func deleteMessage(_ message: MessageData) {
        print("🗑️ Delete triggered for message: \(message.id)")
        print("   Content: \(message.content)")
        print("   Status: \(message.status)")
        print("   Already deleted: \(message.isDeleted)")
        print("   Current visible messages: \(visibleMessages.count)")
        
        // IMMEDIATELY remove from UI (before database operation)
        withAnimation {
            visibleMessages.removeAll { $0.id == message.id }
        }
        print("   ✅ Removed from UI immediately - now showing \(visibleMessages.count) messages")
        
        // If message is still sending, delete completely from database
        if message.status == "sending" {
            print("   → Deleting completely from database (sending status)")
            modelContext.delete(message)
            
            do {
                try modelContext.save()
                print("   ✅ Message deleted from database")
            } catch {
                print("   ❌ Error deleting message: \(error)")
                // Rollback UI change if database fails
                visibleMessages = queriedMessages
            }
        } else {
            // For sent/delivered/read messages: Keep in database but hide from both users
            print("   → Marking as deleted in database (soft delete)")
            
            // Mark as deleted - message stays in database but won't be displayed
            message.isDeleted = true
            
            do {
                try modelContext.save()
                print("   ✅ Message marked as deleted in database (isDeleted = true)")
            } catch {
                print("   ❌ Error marking message as deleted: \(error)")
                // Rollback UI change if database fails
                visibleMessages = queriedMessages
            }
        }
    }
    
    private func toggleEmphasis(_ message: MessageData) {
        if message.emphasizedBy.contains(currentUserId) {
            // Remove emphasis
            message.emphasizedBy.removeAll { $0 == currentUserId }
            message.isEmphasized = !message.emphasizedBy.isEmpty
        } else {
            // Add emphasis
            message.emphasizedBy.append(currentUserId)
            message.isEmphasized = true
        }
        
        do {
            try modelContext.save()
        } catch {
            print("Error toggling emphasis: \(error)")
        }
    }
    
    private func forwardMessage(_ message: MessageData) {
        messageToForward = message
        showForwardSheet = true
    }
    
    private func handleReceivedMessage(_ payload: MessagePayload) {
        print("📥 Handling received WebSocket message: \(payload.messageId)")
        
        // Only handle messages for this conversation
        guard payload.conversationId == conversation.id else {
            print("   ⏭️ Message is for different conversation, ignoring")
            return
        }
        
        // Check if message already exists (avoid duplicates)
        if visibleMessages.contains(where: { $0.id == payload.messageId }) {
            print("   ⚠️ Message already exists, ignoring duplicate")
            return
        }
        
        // Parse timestamp
        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.date(from: payload.timestamp) ?? Date()
        
        // Create MessageData from payload
        // No longer need to compute isSentByCurrentUser - MessageBubble will do it!
        
        let newMessage = MessageData(
            conversationId: payload.conversationId,
            senderId: payload.senderId,
            senderName: payload.senderName,
            content: payload.content,
            timestamp: timestamp,
            status: payload.status,
            // isSentByCurrentUser removed - computed dynamically by MessageBubble
            replyToMessageId: payload.replyToMessageId,
            replyToContent: payload.replyToContent,
            replyToSenderName: payload.replyToSenderName
        )
        
        // Save to database
        do {
            try databaseService.saveMessage(newMessage)
            
            // Add to visible messages
            withAnimation {
                visibleMessages.append(newMessage)
            }
            
            // Update conversation
            conversation.lastMessage = payload.content
            conversation.lastMessageTime = timestamp
            try modelContext.save()
            
            print("✅ Message added to conversation")
        } catch {
            print("❌ Error saving received message: \(error)")
        }
    }
    
    private func forwardToConversation(_ message: MessageData, to targetConversation: ConversationData) {
        // Create a new message in the target conversation
        let forwardedMessage = MessageData(
            conversationId: targetConversation.id,
            senderId: currentUserId,
            senderName: "You",
            content: message.content,
            timestamp: Date(),
            status: "sending"
            // isSentByCurrentUser removed - computed dynamically
        )
        
        do {
            try databaseService.saveMessage(forwardedMessage)
            
            // Update target conversation
            targetConversation.lastMessage = message.content
            targetConversation.lastMessageTime = Date()
            try modelContext.save()
            
            // Close sheet
            showForwardSheet = false
            messageToForward = nil
            
            // Simulate sending
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                forwardedMessage.status = "sent"
                do {
                    try modelContext.save()
                } catch {
                    print("Error updating forwarded message status: \(error)")
                }
            }
        } catch {
            print("Error forwarding message: \(error)")
        }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: MessageData
    let currentUserId: String // ✅ Added to determine bubble placement
    let onReply: () -> Void
    let onDelete: () -> Void
    let onEmphasize: () -> Void
    let onForward: () -> Void
    let onTapReply: (String) -> Void
    
    @State private var swipeOffset: CGFloat = 0
    
    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer(minLength: 60)
            }
            
            ZStack(alignment: .leading) {
                // Reply icon background (shows when swiping right)
                if swipeOffset > 10 {
                    HStack {
                        Image(systemName: "arrowshape.turn.up.left.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding(.leading, 20)
                            .opacity(Double(min(swipeOffset / 60.0, 1.0)))
                        Spacer()
                    }
                    .frame(height: 50)
                    .background(Color.blue)
                    .cornerRadius(20)
                }
                
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                // Reply context (if this message is a reply)
                    if let replyToContent = message.replyToContent,
                       let replyToSenderName = message.replyToSenderName,
                       let replyToId = message.replyToMessageId {
                        Button(action: { onTapReply(replyToId) }) {
                            HStack(spacing: 6) {
                                Rectangle()
                                    .fill(isFromCurrentUser ? Color.white.opacity(0.6) : Color.blue)
                                    .frame(width: 3)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(replyToSenderName)
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(isFromCurrentUser ? .white.opacity(0.9) : .blue)
                                    
                                    Text(replyToContent)
                                        .font(.caption)
                                        .foregroundColor(isFromCurrentUser ? .white.opacity(0.7) : .gray)
                                        .lineLimit(2)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(isFromCurrentUser ? Color.white.opacity(0.2) : Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    
                    // Message content with emphasis overlay
                    ZStack(alignment: .topTrailing) {
                        Text(message.content)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(isFromCurrentUser ? Color.blue : Color(.systemGray5))
                            .foregroundColor(isFromCurrentUser ? .white : .primary)
                            .cornerRadius(20)
                        
                        // Emphasis indicator
                        if message.isEmphasized {
                            Image(systemName: "heart.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(4)
                                .background(Circle().fill(Color.white))
                                .offset(x: 8, y: -8)
                        }
                    }
                
                // Timestamp and status
                HStack(spacing: 4) {
                    Text(formatTime(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    if isFromCurrentUser {
                        statusIcon
                    }
                }
            }
            .offset(x: swipeOffset)
            } // Close ZStack
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let translation = value.translation.width
                        // Swipe RIGHT for reply only
                        if translation > 0 {
                            swipeOffset = min(translation, 60)
                        } else {
                            swipeOffset = 0 // No swipe left action
                        }
                    }
                    .onEnded { value in
                        if swipeOffset > 30 {
                            // Trigger reply (swipe right)
                            onReply()
                        }
                        // Animate back to original position
                        withAnimation(.spring()) {
                            swipeOffset = 0
                        }
                    }
            )
            .animation(.easeInOut(duration: 0.2), value: swipeOffset)
            .contextMenu {
                Button(action: onEmphasize) {
                    Label(
                        message.isEmphasized ? "Remove Emphasis" : "Emphasize",
                        systemImage: message.isEmphasized ? "heart.slash.fill" : "heart.fill"
                    )
                }
                
                Button(action: onForward) {
                    Label("Forward", systemImage: "arrowshape.turn.up.right.fill")
                }
                
                Button(action: onReply) {
                    Label("Reply", systemImage: "arrowshape.turn.up.left.fill")
                }
                
                Divider()
                
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
            
            if !isFromCurrentUser {
                Spacer(minLength: 60)
            }
        }
    }
    
    private var isFromCurrentUser: Bool {
        message.isSentBy(userId: currentUserId) // ✅ Now uses real current user ID!
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch message.status {
        case "sending":
            Image(systemName: "clock.fill")
                .font(.caption2)
                .foregroundColor(.gray)
        case "sent":
            Image(systemName: "checkmark")
                .font(.caption2)
                .foregroundColor(.gray)
        case "delivered":
            Image(systemName: "checkmark")
                .font(.caption2)
                .foregroundColor(.blue)
        case "read":
            Image(systemName: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundColor(.blue)
        case "failed":
            Image(systemName: "exclamationmark.circle.fill")
                .font(.caption2)
                .foregroundColor(.red)
        default:
            EmptyView()
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            formatter.timeStyle = .short
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            formatter.timeStyle = .short
            return "Yesterday " + formatter.string(from: date)
        } else {
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return formatter.string(from: date)
        }
    }
}

// MARK: - Reply Banner (Very Compact)

struct ReplyBanner: View {
    let message: MessageData
    let onCancel: () -> Void
    
    var body: some View {
        HStack(spacing: 6) {
            // Vertical accent bar (thinner)
            Rectangle()
                .fill(Color.blue)
                .frame(width: 2, height: 18)
            
            // Reply content (single line, very compact)
            HStack(spacing: 3) {
                Text("Replying:")
                    .font(.system(size: 11))
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                
                Text(message.content)
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Cancel button (very small)
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .frame(height: 24)
        .background(Color(.systemGray6))
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}

// MARK: - Forward Message View

struct ForwardMessageView: View {
    @Environment(\.dismiss) private var dismiss
    let message: MessageData
    let conversations: [ConversationData]
    let onForward: (ConversationData) -> Void
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Message preview
                VStack(alignment: .leading, spacing: 8) {
                    Text("Forward Message")
                        .font(.headline)
                        .foregroundColor(.gray)
                    
                    HStack {
                        Rectangle()
                            .fill(Color.blue)
                            .frame(width: 3)
                        
                        Text(message.content)
                            .font(.subheadline)
                            .foregroundColor(.primary)
                            .lineLimit(3)
                            .padding(.leading, 8)
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                }
                .padding()
                
                Divider()
                
                // Conversation list
                if conversations.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "tray")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        
                        Text("No other conversations")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Text("Create a new conversation first")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    List(conversations) { conversation in
                        Button(action: {
                            onForward(conversation)
                            dismiss()
                        }) {
                            HStack(spacing: 12) {
                                // Avatar
                                Circle()
                                    .fill(avatarColor(for: conversation))
                                    .frame(width: 50, height: 50)
                                    .overlay(
                                        Text(displayName(for: conversation).prefix(1).uppercased())
                                            .font(.title3)
                                            .fontWeight(.semibold)
                                            .foregroundColor(.white)
                                    )
                                
                                // Name
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(displayName(for: conversation))
                                        .font(.headline)
                                        .foregroundColor(.primary)
                                    
                                    if let lastMessage = conversation.lastMessage {
                                        Text(lastMessage)
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                            .lineLimit(1)
                                    }
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
            }
            .navigationTitle("Forward To...")
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
    
    private func displayName(for conversation: ConversationData) -> String {
        if conversation.isGroupChat {
            return conversation.groupName ?? "Group Chat"
        } else {
            return conversation.participantNames.first ?? "Unknown"
        }
    }
    
    private func avatarColor(for conversation: ConversationData) -> Color {
        let colors: [Color] = [.blue, .purple, .green, .orange, .pink, .red]
        let name = displayName(for: conversation)
        let index = abs(name.hashValue % colors.count)
        return colors[index]
    }
}

#Preview {
    NavigationStack {
        ChatView(conversation: ConversationData(
            participantIds: ["user1", "user2"],
            participantNames: ["John Doe"]
        ))
    }
    .modelContainer(for: [MessageData.self, ConversationData.self, DraftData.self])
}

