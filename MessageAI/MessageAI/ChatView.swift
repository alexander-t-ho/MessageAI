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
    @State private var messageText = ""
    @State private var isLoading = false
    @State private var replyingToMessage: MessageData? // Message being replied to
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
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: MessageData
    let onReply: () -> Void
    let onTapReply: (String) -> Void
    
    @State private var swipeOffset: CGFloat = 0
    
    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer(minLength: 60)
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
                
                // Message content
                Text(message.content)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(isFromCurrentUser ? Color.blue : Color(.systemGray5))
                    .foregroundColor(isFromCurrentUser ? .white : .primary)
                    .cornerRadius(20)
                
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
            .gesture(
                DragGesture()
                    .onChanged { value in
                        // Only allow swiping left (negative translation)
                        let translation = value.translation.width
                        if translation < 0 {
                            swipeOffset = max(translation, -60)
                        }
                    }
                    .onEnded { value in
                        if swipeOffset < -30 {
                            // Trigger reply
                            onReply()
                        }
                        // Animate back to original position
                        withAnimation(.spring()) {
                            swipeOffset = 0
                        }
                    }
            )
            
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

// MARK: - Reply Banner

struct ReplyBanner: View {
    let message: MessageData
    let onCancel: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // Vertical accent bar
            Rectangle()
                .fill(Color.blue)
                .frame(width: 3)
            
            // Reply content
            VStack(alignment: .leading, spacing: 2) {
                Text("Replying to \(message.senderName)")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
                
                Text(message.content)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Cancel button
            Button(action: onCancel) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .transition(.move(edge: .bottom).combined(with: .opacity))
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

