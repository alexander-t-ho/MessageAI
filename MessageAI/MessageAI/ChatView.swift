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
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var webSocketService: WebSocketService
    @Query private var allMessages: [MessageData]
    @Query private var allConversations: [ConversationData]
    @Query private var pendingAll: [PendingMessageData]
    @State private var messageText = ""
    @State private var isLoading = false
    @State private var suppressDraftSaves = false
    @State private var replyingToMessage: MessageData? // Message being replied to
    @State private var showForwardSheet = false
    @State private var messageToForward: MessageData?
    @State private var visibleMessages: [MessageData] = [] // Manually managed visible messages
    @FocusState private var isInputFocused: Bool
    @State private var isAtBottom: Bool = false // true when user is viewing the latest message
    @State private var refreshTick: Int = 0 // forces UI refresh on status updates
    @State private var userHasManuallyScrolledUp: Bool = false // disables auto-scroll until back at bottom
    @State private var scrollToBottomTick: Int = 0 // trigger to request bottom scroll inside ScrollViewReader
    @State private var typingTimer: Timer? = nil // Timer for typing indicator timeout
    @State private var lastTypingTime: Date = Date() // Track last typing activity
    @State private var typingDotsAnimation: Bool = false // Animation trigger for typing dots
    
    private var databaseService: DatabaseService {
        DatabaseService(modelContext: modelContext)
    }
    
    // Treat connected WebSocket as online-effective for UI/queue decisions on phase-5
    private var isOnlineEffective: Bool {
        if case .connected = webSocketService.connectionState { return true }
        return false
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
            .filter { $0.conversationId == conversation.id }
            .sorted { $0.timestamp < $1.timestamp }
    }
    
    // Other conversations for forwarding
    private var otherConversations: [ConversationData] {
        allConversations.filter { $0.id != conversation.id }
    }
    
    // Queued count for this conversation
    private var queuedCount: Int {
        pendingAll.filter { $0.conversationId == conversation.id }.count
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
                                lastReadMessageId: lastReadOutgoingId,
                                refreshKey: refreshTick,
                                onReply: { replyToMessage(message) },
                                onDelete: { deleteMessage(message) },
                                onEmphasize: { toggleEmphasis(message) },
                                onForward: { forwardMessage(message) },
                                onTapReply: { scrollToMessage($0, proxy: proxy) }
                            )
                            .id(message.id)
                        }
                        
                        // Typing indicator as a message bubble (left side)
                        if let typingUser = webSocketService.typingUsers[conversation.id] {
                            HStack(alignment: .bottom, spacing: 8) {
                                // Bubble with animated dots - more visible
                                ZStack {
                                    // Background bubble with better visibility
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(Color(.systemGray5))
                                        .frame(width: 80, height: 44)
                                        .shadow(color: .gray.opacity(0.2), radius: 2, x: 0, y: 1)
                                    
                                    // Animated dots - larger and more visible
                                    HStack(spacing: 5) {
                                        ForEach(0..<3) { index in
                                            Circle()
                                                .fill(Color.gray)
                                                .frame(width: 12, height: 12)
                                                .scaleEffect(typingDotsAnimation ? 1.2 : 0.8)
                                                .animation(
                                                    Animation.easeInOut(duration: 0.6)
                                                        .repeatForever()
                                                        .delay(Double(index) * 0.15),
                                                    value: typingDotsAnimation
                                                )
                                        }
                                    }
                                }
                                
                                Spacer()
                            }
                            .padding(.leading, 12)
                            .padding(.vertical, 4)
                            .id("typing-indicator")
                            .transition(.asymmetric(
                                insertion: .move(edge: .bottom).combined(with: .opacity),
                                removal: .move(edge: .bottom).combined(with: .opacity)
                            ))
                            .onAppear {
                                print("🎯 Typing bubble visible for: \(typingUser)")
                                withAnimation {
                                    typingDotsAnimation = true
                                }
                                // Auto-scroll to bottom when typing appears with delay
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    if !userHasManuallyScrolledUp {
                                        scrollToBottomTick += 1
                                    }
                                }
                            }
                            .onDisappear {
                                typingDotsAnimation = false
                            }
                        }
                        
                        // Sentinel to detect when user is at bottom
                        Color.clear
                            .frame(height: 1)
                            .onAppear {
                                print("📍 Sentinel at bottom appeared → isAtBottom=true")
                                isAtBottom = true
                                userHasManuallyScrolledUp = false
                                // Small delay to ensure all messages are loaded
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                    markVisibleIncomingAsRead()
                                }
                            }
                            .onDisappear {
                                print("📍 Sentinel left viewport → isAtBottom=false")
                                isAtBottom = false
                            }
                    }
                    .padding()
                }
                // Detect user scrolling intent: dragging down (content pulled down) means user wants to read older messages
                .gesture(
                    DragGesture().onChanged { value in
                        if value.translation.height > 20 { // user dragged downwards to see older messages
                            userHasManuallyScrolledUp = true
                        }
                    }
                    .onEnded { _ in
                        // If we ended a gesture and we're at bottom, re-enable auto-scroll
                        if isAtBottom { userHasManuallyScrolledUp = false }
                    }
                )
                .onChange(of: queriedMessages.count) { oldCount, newCount in
                    print("📊 Messages count changed: \(oldCount) → \(newCount)")
                    // Update visible messages when query changes
                    visibleMessages = queriedMessages
                    
                    // Always auto-scroll to bottom when a new message arrives
                    if newCount > oldCount {
                        scrollToBottomTick += 1
                    }
                    // Phase 6: mark visible incoming as read
                    markVisibleIncomingAsRead()
                }
                .onChange(of: scrollToBottomTick) { _, _ in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        if webSocketService.typingUsers[conversation.id] != nil {
                            // If typing, scroll to the typing indicator
                            proxy.scrollTo("typing-indicator", anchor: .bottom)
                        } else if let lastMessage = visibleMessages.last {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        } else {
                            proxy.scrollTo("bottom-sentinel", anchor: .bottom)
                        }
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { isAtBottom = true }
                }
                .onAppear {
                    print("👁️ ChatView appeared - loading messages")
                    print("📍 Conversation ID: \(conversation.id)")
                    // Initialize visible messages from query
                    visibleMessages = queriedMessages
                    print("📊 Loaded \(visibleMessages.count) messages")
                    
                    // Scroll to bottom on appear
                    if let lastMessage = visibleMessages.last {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            // Assume we are at bottom after programmatic scroll
                            isAtBottom = true
                            userHasManuallyScrolledUp = false
                            markVisibleIncomingAsRead()
                        }
                    }
                    
                    // Load draft
                    loadDraft()

                    // Phase 6: attempt to mark current messages as read when at bottom
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        markVisibleIncomingAsRead()
                    }

                    // Ensure WebSocket is connected when entering chat
                    let isConnected: Bool = {
                        if case .connected = webSocketService.connectionState { return true }
                        return false
                    }()
                    if !webSocketService.simulateOffline && !isConnected, let uid = authViewModel.currentUser?.id {
                        print("🔄 ChatView requesting WebSocket reconnect for userId: \(uid)")
                        webSocketService.connect(userId: uid)
                    }
                }
            }
            // Check if conversation still exists
            .onChange(of: allConversations) { _, newConversations in
                // If conversation is no longer in the list, dismiss the view
                if !newConversations.contains(where: { $0.id == conversation.id }) {
                    print("⚠️ Conversation deleted, dismissing ChatView")
                    // Small delay to avoid navigation conflicts
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        dismiss()
                    }
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
                    .onChange(of: messageText) { oldValue, newValue in
                        // Avoid recreating a draft immediately after send
                        guard !suppressDraftSaves else { return }
                        saveDraft(newValue)
                        
                        // Send typing indicator
                        handleTypingIndicator(oldValue: oldValue, newValue: newValue)
                    }
                
                // Offline/Queue badge (based on WS connection)
                if !isOnlineEffective || queuedCount > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: isOnlineEffective ? "arrow.triangle.2.circlepath" : "icloud.slash")
                            .font(.system(size: 12, weight: .semibold))
                        if queuedCount > 0 {
                            Text("\(queuedCount)")
                                .font(.caption2)
                                .fontWeight(.bold)
                        } else {
                            Text("Offline")
                                .font(.caption2)
                                .fontWeight(.semibold)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color(.systemGray5)))
                    .foregroundColor(.gray)
                    .accessibilityLabel("Queued messages: \(queuedCount). \(isOnlineEffective ? "Online" : "Offline")")
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
        .onDisappear {
            // Clean up typing indicator when leaving chat
            sendTypingIndicator(isTyping: false)
        }
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 6) {
                    Text(displayName)
                        .font(.headline)
                    presenceDot
                }
                .contentShape(Rectangle())
                .contextMenu {
                    if isPeerOnline {
                        Label("Active", systemImage: "circle.fill")
                    } else {
                        Label("Offline", systemImage: "circle")
                    }
                }
            }
        }
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
                // Keep at bottom unless user scrolled up
                // Always keep at bottom on new incoming message
                scrollToBottomTick += 1
                // Mark any now-visible incoming as read (only if at bottom)
                // Add a small delay to ensure the message is added to visibleMessages
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    markVisibleIncomingAsRead()
                }
            }
        }
        .onChange(of: webSocketService.deletedMessages.count) { old, new in
            if new > old, let payload = webSocketService.deletedMessages.last {
                handleDeletedMessage(payload)
            }
        }
        // After catch-up completes, force-scroll to bottom and mark all visible incoming as read
        .onChange(of: webSocketService.catchUpCounter) { _, _ in
            print("📦 catchUpComplete observed in ChatView → attempting read sync")
            // Force we are at bottom and re-evaluate
            isAtBottom = true
            userHasManuallyScrolledUp = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                markVisibleIncomingAsRead()
            }
        }
        .onChange(of: webSocketService.statusUpdates.count) { old, new in
            if new > old, let payload = webSocketService.statusUpdates.last {
                handleStatusUpdate(payload)
                // Refresh visible list and tick UI so lastReadOutgoingId recalculates
                visibleMessages = queriedMessages
                refreshTick += 1
                // Keep bottom aligned for live updates unless user scrolled up
                // Keep bottom aligned for live updates
                scrollToBottomTick += 1
            }
        }
        .onChange(of: webSocketService.typingUsers[conversation.id]) { oldValue, newValue in
            // Auto-scroll to bottom when someone starts typing
            if newValue != nil && oldValue == nil {
                print("🔽 Auto-scrolling to show typing indicator")
                // Always scroll to bottom for typing indicator visibility
                withAnimation(.easeInOut(duration: 0.3)) {
                    scrollToBottomTick += 1
                    userHasManuallyScrolledUp = false
                }
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

    // The most recent outgoing message that has been read
    private var lastReadOutgoingId: String? {
        visibleMessages
            .filter { $0.senderId == currentUserId && $0.isRead }
            .sorted { $0.timestamp < $1.timestamp }
            .last?.id
    }
    
    private var isPeerOnline: Bool {
        // Read peer presence from WebSocketService cache
        webSocketService.userPresence[recipientId] ?? false
    }
    
    @ViewBuilder private var presenceDot: some View {
        Circle()
            .fill(isPeerOnline ? Color.green : Color.clear)
            .overlay(
                Circle()
                    .stroke(Color.gray.opacity(0.6), lineWidth: 1)
            )
            .frame(width: 10, height: 10)
            .accessibilityLabel(isPeerOnline ? "Active" : "Offline")
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
        
        // Stop typing indicator
        sendTypingIndicator(isTyping: false)
        
        isLoading = true
        // Prevent TextField change observers from saving a new draft during send
        suppressDraftSaves = true
        
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
            
            // If offline or WS not connected, enqueue; else send immediately
            let isConnected: Bool = {
                if case .connected = webSocketService.connectionState { return true }
                return false
            }()
                if !isOnlineEffective || !isConnected {
                // Enqueue for later send
                let sync = SyncService(webSocket: webSocketService, modelContext: modelContext)
                sync.enqueue(message: message, recipientId: recipientId)
                Task { await sync.processQueueIfPossible() }
            } else {
                print("🚀🚀🚀 SENDING MESSAGE VIA WEBSOCKET:")
                print("   Sender ID: \(currentUserId)")
                print("   Sender Name: \(currentUserName)")
                print("   Recipient ID: \(recipientId)")
                print("   Conversation ID: \(conversation.id)")
                print("   Participant IDs: \(conversation.participantIds)")
                print("🚀🚀🚀")
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
            }
            
            // Mark as sent after brief delay, but only if still sending
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if message.status == "sending" { // avoid overwriting delivered/read
                    message.status = "sent"
                    do {
                        try modelContext.save()
                    } catch {
                        print("Error updating message status: \(error)")
                    }
                }
                isLoading = false
                // Re-enable draft autosave shortly after send
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    suppressDraftSaves = false
                }
            }
            
        } catch {
            print("Error sending message: \(error)")
            isLoading = false
            // Ensure we re-enable drafts even if send fails synchronously
            suppressDraftSaves = false
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
        
        // If message is still sending, delete completely from database
        if message.status == "sending" {
            print("   → Deleting completely from database (sending status)")
            
            // Remove from UI immediately for unsent messages
            withAnimation {
                visibleMessages.removeAll { $0.id == message.id }
            }
            
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
            // For sent/delivered/read messages: Mark as deleted but keep in view
            print("   → Marking as deleted (soft delete)")
            
            // Update message to show as deleted
            message.isDeleted = true
            message.content = "This message was deleted"
            
            // Update in visible messages
            if let index = visibleMessages.firstIndex(where: { $0.id == message.id }) {
                visibleMessages[index].isDeleted = true
                visibleMessages[index].content = "This message was deleted"
            }
            
            do {
                try modelContext.save()
                print("   ✅ Message marked as deleted in database")
                
                // Trigger UI refresh
                refreshTick += 1
            } catch {
                print("   ❌ Error marking message as deleted: \(error)")
            }
        }
        
        // Notify recipient via WebSocket
        webSocketService.sendDeleteMessage(
            messageId: message.id,
            conversationId: conversation.id,
            senderId: currentUserId,
            recipientId: recipientId
        )
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
        print("   From: \(payload.senderId), Current user: \(currentUserId)")
        
        // Only handle messages for this conversation
        guard payload.conversationId == conversation.id else {
            print("   ⏭️ Message is for different conversation, ignoring")
            return
        }
        
        // Check if message already exists in DB (avoid duplicates after relaunch)
        if (try? modelContext.fetch(FetchDescriptor<MessageData>()).contains { $0.id == payload.messageId }) ?? false {
            print("   ⚠️ Message already exists, ignoring duplicate")
            return
        }
        
        // Parse timestamp
        let formatter = ISO8601DateFormatter()
        let timestamp = formatter.date(from: payload.timestamp) ?? Date()
        
        // Create MessageData from payload
        // No longer need to compute isSentByCurrentUser - MessageBubble will do it!
        
        let newMessage = MessageData(
            id: payload.messageId,
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
            
            print("✅ Message added to conversation, count: \(visibleMessages.count)")
            
            // If this is an incoming message and we're at the bottom, mark it as read immediately
            if payload.senderId != currentUserId && isAtBottom {
                print("📤 New incoming message while at bottom, marking as read")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    markVisibleIncomingAsRead()
                }
            }
        } catch {
            print("❌ Error saving received message: \(error)")
        }
    }
    
    private func handleDeletedMessage(_ payload: DeletePayload) {
        // Only handle deletes for this conversation
        guard payload.conversationId == conversation.id else { return }
        
        print("🗑️ Received delete notification for message: \(payload.messageId)")
        
        // Update DB to mark as deleted
        do {
            let fetch = FetchDescriptor<MessageData>()
            if let msg = try modelContext.fetch(fetch).first(where: { $0.id == payload.messageId }) {
                msg.isDeleted = true
                msg.content = "This message was deleted" // Update content for deleted messages
                try modelContext.save()
                print("   ✅ Message marked as deleted in database")
                
                // Update in visible messages (don't remove, just mark as deleted)
                if let index = visibleMessages.firstIndex(where: { $0.id == payload.messageId }) {
                    visibleMessages[index].isDeleted = true
                    visibleMessages[index].content = "This message was deleted"
                }
                
                // Trigger UI refresh
                refreshTick += 1
            }
        } catch {
            print("❌ Error applying delete: \(error)")
        }
    }
    
    // Phase 6: handle delivery/read status updates (includes readAt timestamp)
    private func handleStatusUpdate(_ payload: MessageStatusPayload) {
        guard payload.conversationId == conversation.id else { return }
        print("📬 handleStatusUpdate: messageId=\(payload.messageId) status=\(payload.status) readAt=\(payload.readAt ?? "nil")")
        do {
            let fetch = FetchDescriptor<MessageData>()
            let msgs = try modelContext.fetch(fetch).filter { $0.conversationId == conversation.id && !$0.isDeleted }
            
            if payload.status == "read" {
                // For read status, we need to find the latest outgoing message and mark only that as read
                // Clear ALL previous outgoing read flags first
                for m in msgs where m.senderId == currentUserId {
                    m.isRead = false
                    m.readAt = nil
                }
                
                // Find the specific message from the payload
                if let msg = msgs.first(where: { $0.id == payload.messageId && $0.senderId == currentUserId }) {
                    print("   Found outgoing message to mark as read: \(msg.id)")
                    msg.status = "read"
                    msg.isRead = true
                    
                    // Always set a readAt timestamp
                    if let s = payload.readAt {
                        if let d = ISO8601DateFormatter().date(from: s) {
                            msg.readAt = d
                            print("   ✅ Set readAt from server=\(d) for message \(msg.id)")
                        } else {
                            // Failed to parse, use current time
                            msg.readAt = Date()
                            print("   ⚠️ Failed to parse readAt timestamp: \(s), using current time")
                        }
                    } else {
                        // No timestamp provided, use current time
                        msg.readAt = Date()
                        print("   ⚠️ No readAt timestamp in payload, using current time")
                    }
                } else {
                    print("   ⚠️ Message not found or not outgoing: \(payload.messageId)")
                }
            } else {
                // For other statuses (delivered, etc), just update the specific message
                if let msg = msgs.first(where: { $0.id == payload.messageId }) {
                    print("   Found message to update: current status=\(msg.status)")
                    msg.status = payload.status
                } else {
                    print("   ⚠️ Message not found in database: \(payload.messageId)")
                }
            }
            
            try modelContext.save()
            print("   ✅ Saved status update to database")
        } catch {
            print("❌ Error applying status update: \(error)")
        }
    }
    
    // Phase 6: send markRead for any incoming messages that are now visible and not yet read
    private func markVisibleIncomingAsRead() {
        guard isAtBottom else { 
            print("📤 markVisibleIncomingAsRead skipped: isAtBottom=\(isAtBottom)")
            return 
        }
        let reads = visibleMessages
            .filter { $0.conversationId == conversation.id && !$0.isDeleted }
            .filter { $0.senderId != currentUserId }
            .filter { !$0.isRead }
            .map { (id: $0.id, senderId: $0.senderId) }
        guard !reads.isEmpty else { 
            print("📤 markVisibleIncomingAsRead: no unread incoming messages to mark")
            return 
        }
        print("📤 markVisibleIncomingAsRead sending for \(reads.count) messages: ids=\(reads.map{ $0.id }) isAtBottom=\(isAtBottom)")
        // Optimistically set read locally
        for m in visibleMessages where reads.contains(where: { $0.id == m.id }) {
            m.isRead = true
            m.readAt = Date() // Set local readAt timestamp
        }
        do { try modelContext.save() } catch { print("❌ Error saving read flags: \(error)") }
        // Send to server with senderId to avoid race on GetItem
        webSocketService.sendMarkRead(
            conversationId: conversation.id,
            readerId: currentUserId,
            messageReads: reads.map { ["messageId": $0.id, "senderId": $0.senderId] }
        )
    }
    
    // Handle typing indicator
    private func handleTypingIndicator(oldValue: String, newValue: String) {
        let trimmedOld = oldValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNew = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // If user just started typing (went from empty to non-empty)
        if trimmedOld.isEmpty && !trimmedNew.isEmpty {
            sendTypingIndicator(isTyping: true)
            lastTypingTime = Date()
        }
        // If user is still typing
        else if !trimmedNew.isEmpty {
            // Cancel existing timer
            typingTimer?.invalidate()
            
            // Send typing indicator at reasonable intervals to reduce jitter
            let now = Date()
            if now.timeIntervalSince(lastTypingTime) > 1.0 { // Send every 1 second to reduce network traffic
                sendTypingIndicator(isTyping: true)
                lastTypingTime = now
            }
            
            // Set timer to stop typing after 2 seconds of inactivity
            typingTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: false) { _ in
                Task { @MainActor in
                    sendTypingIndicator(isTyping: false)
                }
            }
        }
        // If user cleared the text
        else if !trimmedOld.isEmpty && trimmedNew.isEmpty {
            typingTimer?.invalidate()
            sendTypingIndicator(isTyping: false)
        }
    }
    
    // Send typing indicator via WebSocket
    private func sendTypingIndicator(isTyping: Bool) {
        print("📤 Sending typing: \(isTyping ? "START" : "STOP") for conversation \(conversation.id)")
        print("   From: \(currentUserId) (\(currentUserName)) to: \(recipientId)")
        print("   Connection state: \(webSocketService.connectionState)")
        
        guard case .connected = webSocketService.connectionState else {
            print("   ⚠️ Cannot send typing indicator - not connected")
            return
        }
        
        webSocketService.sendTyping(
            conversationId: conversation.id,
            senderId: currentUserId,
            senderName: currentUserName,
            recipientId: recipientId,
            isTyping: isTyping
        )
        
        if !isTyping {
            typingTimer?.invalidate()
            typingTimer = nil
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
    let lastReadMessageId: String?
    let refreshKey: Int
    let onReply: () -> Void
    let onDelete: () -> Void
    let onEmphasize: () -> Void
    let onForward: () -> Void
    let onTapReply: (String) -> Void
    
    @State private var swipeOffset: CGFloat = 0
    @State private var showTimestamp: Bool = false
    @State private var hideDeliveredStatus: Bool = false
    @State private var lastStatus: String = ""
    
    // Determine if this is the last outgoing message that is read
    private var isLastOutgoingRead: Bool {
        guard message.isSentBy(userId: currentUserId) else { return false }
        guard let lastId = lastReadMessageId else { return false }
        return message.id == lastId
    }

    var body: some View {
        // For deleted messages, center them but keep sender's color
        if message.isDeleted {
            HStack {
                Spacer()
                Text("This message was deleted")
                    .font(.system(size: 12))
                    .italic()
                    .foregroundColor(isFromCurrentUser ? .white : .gray)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(isFromCurrentUser ? Color.blue : Color(.systemGray5))
                    .cornerRadius(14)
                    .scaleEffect(0.7) // 70% size
                    .opacity(0.5) // 50% opacity
                Spacer()
            }
            .padding(.vertical, 2)
        } else {
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
                
                // Timestamp is hidden by default; shown only on light right-swipe
                HStack(spacing: 4) {
                    if showTimestamp {
                        Text(formatTime(message.timestamp))
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    // Keep status icon visible for outgoing messages UNLESS showing read receipt
                    if isFromCurrentUser && !isLastOutgoingRead {
                        statusIcon
                    }
                }
                // Read receipt label shown only for the most recent outgoing message
                if isFromCurrentUser, isLastOutgoingRead {
                    HStack(spacing: 4) {
                        Text("Read")
                        if let t = message.readAt {
                            Text(readTime(t))
                        }
                        // Blue check in a circle
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundColor(.blue)
                    }
                    .font(.caption2)
                    .foregroundColor(.gray)
                    .padding(.top, 2)
                }
            } // End of VStack
            } // End of ZStack
            .offset(x: swipeOffset)
            // force view refresh when status updates tick changes so latest read attaches correctly
            .id(refreshKey)
            .onChange(of: message.status) { oldValue, newValue in
                // Reset hide flag when status changes
                if oldValue != newValue {
                    hideDeliveredStatus = false
                    lastStatus = newValue
                }
            }
            .onAppear {
                lastStatus = message.status
            }
            } // Close ZStack
            .gesture(
                DragGesture()
                    .onChanged { value in
                        let translation = value.translation.width
                        // threshold for light reveal
                        let revealThreshold: CGFloat = 10
                        // Swipe RIGHT interactions only
                        if translation > 0 {
                            swipeOffset = min(translation, 60)
                            // Reveal timestamp on light swipe
                            showTimestamp = translation > revealThreshold
                        } else {
                            swipeOffset = 0
                            showTimestamp = false
                        }
                    }
                    .onEnded { value in
                        let translation = value.translation.width
                        let replyThreshold: CGFloat = 30
                        if translation > replyThreshold {
                            // Trigger reply (strong swipe right)
                            onReply()
                        }
                        // Keep timestamp briefly if it was revealed by a light swipe
                        if showTimestamp {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showTimestamp = false
                                }
                            }
                        }
                        // Reset swipe offset
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
        } // End of HStack
        } // End of else (non-deleted messages) and body
    
    private var isFromCurrentUser: Bool {
        message.isSentBy(userId: currentUserId) // ✅ Now uses real current user ID!
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        if !hideDeliveredStatus {
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
                HStack(spacing: -4) {
                    Image(systemName: "checkmark")
                    Image(systemName: "checkmark")
                        .offset(x: 4)
                }
                .font(.caption2)
                .foregroundColor(.blue)
                .onAppear {
                    // Hide delivered status after 3 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation(.easeOut(duration: 0.3)) {
                            hideDeliveredStatus = true
                        }
                    }
                }
            case "read":
                // Don't show the status icon for read - it's shown in the read receipt
                EmptyView()
            case "failed":
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.red)
            default:
                EmptyView()
            }
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

    private func readTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
} // End of MessageBubble struct

// MARK: - Typing Dot Animation

// Removed TypingDot struct - using simplified inline animation instead

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

