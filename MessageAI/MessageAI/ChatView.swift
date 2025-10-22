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
    @Query private var allMessages: [MessageData]
    @Query private var allConversations: [ConversationData]
    @State private var messageText = ""
    @State private var isLoading = false
    @State private var replyingToMessage: MessageData? // Message being replied to
    @State private var showForwardSheet = false
    @State private var messageToForward: MessageData?
    @FocusState private var isInputFocused: Bool
    
    private var databaseService: DatabaseService {
        DatabaseService(modelContext: modelContext)
    }
    
    // Filter messages for this conversation
    private var messages: [MessageData] {
        allMessages
            .filter { $0.conversationId == conversation.id }
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
                        ForEach(messages) { message in
                            MessageBubble(
                                message: message,
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
                .onChange(of: messages.count) { _, _ in
                    // Auto-scroll to bottom when new message arrives
                    if let lastMessage = messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    // Scroll to bottom on appear
                    if let lastMessage = messages.last {
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
            senderId: "current-user-id", // TODO: Replace with actual user ID in Phase 4
            senderName: "You", // TODO: Replace with actual user name in Phase 4
            content: text,
            timestamp: Date(),
            status: "sending",
            isSentByCurrentUser: true,
            replyToMessageId: replyingToMessage?.id,
            replyToContent: replyingToMessage?.content,
            replyToSenderName: replyingToMessage?.senderName
        )
        
        do {
            // Save to local database
            try databaseService.saveMessage(message)
            
            // Update conversation
            conversation.lastMessage = text
            conversation.lastMessageTime = Date()
            try modelContext.save()
            
            // Clear input, draft, and reply state
            messageText = ""
            replyingToMessage = nil
            try databaseService.deleteDraft(for: conversation.id)
            
            // TODO: Phase 3 - Send to server
            // For now, just mark as sent after a brief delay
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
        print("   Status: \(message.status)")
        print("   Already deleted: \(message.isDeleted)")
        
        withAnimation {
            // If message is still sending, delete completely
            if message.status == "sending" {
                print("   → Deleting completely (sending status)")
                do {
                    modelContext.delete(message)
                    try modelContext.save()
                    print("   ✅ Message deleted successfully")
                } catch {
                    print("   ❌ Error deleting message: \(error)")
                }
            } else {
                // For sent/delivered/read messages, mark as deleted
                print("   → Marking as deleted (sent/delivered/read status)")
                message.isDeleted = true
                do {
                    try modelContext.save()
                    print("   ✅ Message marked as deleted")
                } catch {
                    print("   ❌ Error marking message as deleted: \(error)")
                }
            }
        }
    }
    
    private func toggleEmphasis(_ message: MessageData) {
        let currentUserId = "current-user-id" // TODO: Replace with actual user ID
        
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
    
    private func forwardToConversation(_ message: MessageData, to targetConversation: ConversationData) {
        // Create a new message in the target conversation
        let forwardedMessage = MessageData(
            conversationId: targetConversation.id,
            senderId: "current-user-id",
            senderName: "You",
            content: message.content,
            timestamp: Date(),
            status: "sending",
            isSentByCurrentUser: true
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
                // If message is deleted, show placeholder
                if message.isDeleted {
                    Text("Message Deleted")
                        .italic()
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background((isFromCurrentUser ? Color.blue : Color(.systemGray5)).opacity(0.3))
                        .foregroundColor(.gray)
                        .cornerRadius(20)
                } else {
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
                }
                
                // Timestamp and status
                HStack(spacing: 4) {
                    Text(formatTime(message.timestamp))
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    if isFromCurrentUser && !message.isDeleted {
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
                if !message.isDeleted {
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
            }
            
            if !isFromCurrentUser {
                Spacer(minLength: 60)
            }
        }
    }
    
    private var isFromCurrentUser: Bool {
        message.senderId == "current-user-id" // TODO: Replace with actual user ID
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

// MARK: - Reply Banner (Smaller Version)

struct ReplyBanner: View {
    let message: MessageData
    let onCancel: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            // Vertical accent bar
            Rectangle()
                .fill(Color.blue)
                .frame(width: 2)
            
            // Reply content (more compact)
            VStack(alignment: .leading, spacing: 1) {
                Text("Replying to \(message.senderName)")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                
                Text(message.content)
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Cancel button (smaller)
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
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

