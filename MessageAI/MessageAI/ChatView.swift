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
    @StateObject private var aiService = AITranslationService.shared
    @StateObject private var preferences = UserPreferences.shared
    @StateObject private var voiceRecorder = VoiceMessageRecorder()
    @StateObject private var voiceToTextService = VoiceToTextService()
    @Query private var allMessages: [MessageData]
    @Query private var allConversations: [ConversationData]
    @Query private var pendingAll: [PendingMessageData]
    @State private var messageText = ""
    @State private var isLoading = false
    @State private var suppressDraftSaves = false
    @State private var replyingToMessage: MessageData? // Message being replied to
    @State private var showForwardSheet = false
    @State private var messageToForward: MessageData?
    @State private var messageToEdit: MessageData?
    @State private var showTranslationSheet = false
    @State private var messageToTranslate: MessageData?
    @State private var translationType: TranslationSheetView.TranslationType = .translate
    @State private var visibleMessages: [MessageData] = [] // Manually managed visible messages
    @FocusState private var isInputFocused: Bool
    @State private var isAtBottom: Bool = false // true when user is viewing the latest message
    @State private var refreshTick: Int = 0 // forces UI refresh on status updates
    @State private var userHasManuallyScrolledUp: Bool = false // disables auto-scroll until back at bottom
    @State private var scrollToBottomTick: Int = 0 // trigger to request bottom scroll inside ScrollViewReader
    @State private var typingTimer: Timer? = nil // Timer for typing indicator timeout
    @State private var lastTypingTime: Date = Date() // Track last typing activity
    @State private var typingDotsAnimation: Bool = false // Animation trigger for typing dots
    @State private var showGroupDetails = false
    
    // Voice message recording states
    @State private var isRecordingVoice = false
    @State private var recordedVoiceURL: URL?
    @State private var recordedVoiceDuration: TimeInterval = 0
    @State private var showVoicePreview = false
    
    private var databaseService: DatabaseService {
        DatabaseService(modelContext: modelContext)
    }
    
    // Calculate unread message count from other conversations
    private var totalUnreadCount: Int {
        // Only count from non-deleted conversations
        let otherConversations = allConversations.filter { 
            $0.id != conversation.id && !$0.isDeleted 
        }
        var unreadCount = 0
        
        for conv in otherConversations {
            // Only count non-deleted, unread messages from others
            let unreadMessages = allMessages.filter { message in
                message.conversationId == conv.id &&
                message.senderId != currentUserId &&
                !message.isRead &&
                !message.isDeleted
            }
            unreadCount += unreadMessages.count
        }
        
        return unreadCount
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
    
    // Format recording duration
    private func formatRecordingDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
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
                                conversation: conversation, // Pass conversation for group chat features
                                lastReadMessageId: lastReadOutgoingId,
                                refreshKey: refreshTick,
                                messageBubbleColor: preferences.messageBubbleColor,
                                onReply: { replyToMessage(message) },
                                onDelete: { deleteMessage(message) },
                                onEmphasize: { toggleEmphasis(message) },
                                onForward: { forwardMessage(message) },
                                onEdit: { editMessage(message) },
                                onTapReply: { scrollToMessage($0, proxy: proxy) },
                                onTranslate: {
                                    messageToTranslate = message
                                    translationType = .translate
                                    showTranslationSheet = true
                                },
                                onExplainSlang: {
                                    messageToTranslate = message
                                    translationType = .explainSlang
                                    showTranslationSheet = true
                                },
                                onTranslateAndExplain: {
                                    messageToTranslate = message
                                    translationType = .both
                                    showTranslationSheet = true
                                }
                            )
                            .id(message.id)
                        }
                        
                        // Typing indicator as a message bubble (left side)
                        if let typingUser = webSocketService.typingUsers[conversation.id] {
                            VStack(alignment: .leading, spacing: 4) {
                                // Show who is typing - especially useful in group chats
                                if conversation.isGroupChat {
                                    Text("\(typingUser) is typing...")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                        .padding(.leading, 12)
                                }
                                
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
                            }
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
                    
                    // Track current conversation for notification suppression
                    UserDefaults.standard.set(conversation.id, forKey: "currentConversationId")
                    print("📍 Set currentConversationId for notification suppression")
                    
                    // Clear notifications for this conversation
                    NotificationManager.shared.clearNotifications(for: conversation.id)
                    
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
                .onDisappear {
                    // Clear current conversation ID to allow notifications
                    UserDefaults.standard.removeObject(forKey: "currentConversationId")
                    print("📍 Cleared currentConversationId - notifications will show")
                    
                    // Force badge count recalculation on dismiss
                    let descriptor = FetchDescriptor<ConversationData>(
                        predicate: #Predicate { $0.isDeleted == false }
                    )
                    if let allConversations = try? modelContext.fetch(descriptor) {
                        let totalUnread = allConversations.reduce(0) { $0 + $1.unreadCount }
                        NotificationManager.shared.setBadgeCount(totalUnread)
                        print("🔔 Badge recalculated on dismiss: \(totalUnread)")
                    }
                }
            }
            // Check if conversation still exists
            .onChange(of: allConversations) { _, newConversations in
                // DISABLED - This was causing crashes when navigating back
                // TODO: Implement better conversation lifecycle management
                /*
                if !newConversations.contains(where: { $0.id == conversation.id }) {
                    print("⚠️ Conversation deleted, dismissing ChatView")
                    // Small delay to avoid navigation conflicts
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        dismiss()
                    }
                }
                */
            }
            
            // Reply banner (shown when replying to a message)
            if let replyMessage = replyingToMessage {
                ReplyBanner(
                    message: replyMessage,
                    onCancel: { cancelReply() }
                )
            }
            
            // Edit banner (shown when editing a message)
            if let editMessage = messageToEdit {
                HStack(spacing: 8) {
                    Image(systemName: "pencil.circle.fill")
                        .foregroundColor(.blue)
                        .font(.system(size: 16))
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Editing Message")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                        Text(editMessage.content)
                            .font(.caption2)
                            .foregroundColor(.gray)
                            .lineLimit(1)
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        messageToEdit = nil
                        messageText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                            .font(.system(size: 20))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
            }
            
            
            // Voice recording indicator (shown when recording)
            if voiceRecorder.isRecording {
                VStack(spacing: 8) {
                    // Waveform animation
                    VoiceWaveformView(
                        audioLevel: voiceRecorder.audioLevel,
                        isRecording: true
                    )
                    .frame(height: 50)
                    
                    HStack(spacing: 12) {
                        // Recording indicator
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 12, height: 12)
                                .opacity(typingDotsAnimation ? 0.3 : 1.0)
                                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: typingDotsAnimation)
                            
                            Text("Recording...")
                                .font(.subheadline)
                                .foregroundColor(.red)
                        }
                        
                        Spacer()
                        
                        // Duration
                        Text(formatRecordingDuration(voiceRecorder.recordingDuration))
                            .font(.system(.body, design: .monospaced))
                            .foregroundColor(.primary)
                        
                        // Stop button
                        Button(action: {
                            stopVoiceRecording()
                        }) {
                            Image(systemName: "stop.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .onAppear {
                    typingDotsAnimation = true
                }
            } else if voiceToTextService.isTranscribing {
                // Voice-to-text transcription indicator
                VStack(spacing: 8) {
                    HStack(spacing: 12) {
                        // Transcription indicator
                        HStack(spacing: 8) {
                            Image(systemName: "waveform")
                                .foregroundColor(.blue)
                                .font(.system(size: 16))
                                .opacity(typingDotsAnimation ? 0.3 : 1.0)
                                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: typingDotsAnimation)
                            
                            Text("Converting voice to text...")
                                .font(.subheadline)
                                .foregroundColor(.blue)
                        }
                        
                        Spacer()
                        
                        // Cancel button
                        Button(action: {
                            voiceToTextService.cancelTranscription()
                            cleanupVoiceRecording()
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.gray)
                        }
                    }
                    
                    if let errorMessage = voiceToTextService.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .onAppear {
                    typingDotsAnimation = true
                }
            } else {
                // Input bar (normal state)
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
                    
                    // Send button (tap to send text, long press to record voice)
                    Button(action: {
                        if messageToEdit != nil {
                            saveEdit()
                        } else {
                            sendMessage()
                        }
                    }) {
                        if isLoading {
                            ProgressView()
                                .frame(width: 32, height: 32)
                        } else {
                            Image(systemName: messageToEdit != nil ? "checkmark.circle.fill" : "arrow.up.circle.fill")
                                .font(.system(size: 32))
                                .foregroundColor(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .gray : .blue)
                        }
                    }
                    .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isLoading)
                    .simultaneousGesture(
                        LongPressGesture(minimumDuration: 0.5)
                            .onEnded { _ in
                                // Long press detected - start voice recording
                                if messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    startVoiceRecording()
                                }
                            }
                    )
                    .simultaneousGesture(
                        DragGesture(minimumDistance: 0)
                            .onEnded { _ in
                                // Release gesture - stop voice recording if recording
                                if isRecordingVoice {
                                    stopVoiceRecording()
                                }
                            }
                    )
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemBackground))
            }
        }
        .onAppear {
            // Initialize AI Translation Service with auth token
            if let token = UserDefaults.standard.string(forKey: "accessToken") {
                aiService.setAuthToken(token)
                print("🌍 AI Translation Service initialized")
            }
            
            // Set currently viewed conversation
            webSocketService.currentlyViewedConversationId = conversation.id
            print("👁️ Now viewing conversation: \(conversation.id)")
            
            // Reset unread count for this conversation
            conversation.unreadCount = 0
            do {
                try modelContext.save()
                
                // Immediately update badge count
                // Calculate total unread across all conversations
                let descriptor = FetchDescriptor<ConversationData>(
                    predicate: #Predicate { $0.isDeleted == false }
                )
                if let allConversations = try? modelContext.fetch(descriptor) {
                    let totalUnread = allConversations.reduce(0) { $0 + $1.unreadCount }
                    NotificationManager.shared.setBadgeCount(totalUnread)
                    print("🔔 Badge updated on chat open: \(totalUnread)")
                }
            } catch {
                print("❌ Error resetting unread count: \(error)")
            }
        }
        .onDisappear {
            // Clear currently viewed conversation
            webSocketService.currentlyViewedConversationId = nil
            print("👁️ Left conversation")
            
            // Clean up typing indicator when leaving chat
            sendTypingIndicator(isTyping: false)
        }
        .navigationTitle(displayName)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true) // Hide default back button
        .toolbar {
            // Custom back button with unread count badge
            ToolbarItem(placement: .navigationBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.blue)
                        
                        Text("Back")
                            .foregroundColor(.blue)
                        
                        // Show unread count badge if there are unread messages
                        if totalUnreadCount > 0 {
                            ZStack {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 20, height: 20)
                                
                                Text("\(totalUnreadCount > 99 ? "99+" : "\(totalUnreadCount)")")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                            }
                        }
                    }
                }
            }
            
            ToolbarItem(placement: .principal) {
                ChatHeaderView(
                    conversation: conversation,
                    userPresence: webSocketService.userPresence,
                    currentUserId: currentUserId
                )
                .onTapGesture {
                    if conversation.isGroupChat {
                        showGroupDetails = true
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
        .sheet(isPresented: $showGroupDetails) {
            if conversation.isGroupChat {
                GroupDetailsView(conversation: conversation)
                    .environmentObject(authViewModel)
                    .environmentObject(webSocketService)
            }
        }
        .sheet(isPresented: $showTranslationSheet) {
            if let message = messageToTranslate {
                TranslationSheetView(
                    message: message,
                    translationType: translationType
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
        .onChange(of: webSocketService.editedMessages.count) { old, new in
            if new > old, let payload = webSocketService.editedMessages.last {
                handleEditedMessage(payload)
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
        if conversation.isGroupChat {
            // For group chats, check if ANY member (except current user) is online
            return conversation.participantIds
                .filter { $0 != currentUserId }
                .contains { webSocketService.userPresence[$0] ?? false }
        } else {
            // For direct messages, check the single recipient
            return webSocketService.userPresence[recipientId] ?? false
        }
    }
    
    private var onlineMemberCount: Int {
        guard conversation.isGroupChat else { return isPeerOnline ? 1 : 0 }
        return conversation.participantIds
            .filter { $0 != currentUserId }
            .filter { webSocketService.userPresence[$0] ?? false }
            .count
    }
    
    @ViewBuilder private var presenceDot: some View {
        if conversation.isGroupChat {
            // For group chats, show green if anyone is online, gray otherwise
            Circle()
                .fill(isPeerOnline ? Color.green : Color.clear)
                .overlay(
                    Circle()
                        .stroke(Color.gray.opacity(0.6), lineWidth: 1)
                )
                .frame(width: 10, height: 10)
                .accessibilityLabel(isPeerOnline ? "\(onlineMemberCount) member\(onlineMemberCount == 1 ? "" : "s") active" : "All offline")
        } else {
            // For direct messages, simple online/offline indicator
            Circle()
                .fill(isPeerOnline ? Color.green : Color.clear)
                .overlay(
                    Circle()
                        .stroke(Color.gray.opacity(0.6), lineWidth: 1)
                )
                .frame(width: 10, height: 10)
                .accessibilityLabel(isPeerOnline ? "Active" : "Offline")
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
                sync.enqueue(
                    message: message, 
                    recipientId: recipientId,
                    recipientIds: conversation.participantIds,
                    isGroupChat: conversation.isGroupChat
                )
                Task { await sync.processQueueIfPossible() }
            } else {
                print("🚀🚀🚀 SENDING MESSAGE VIA WEBSOCKET:")
                print("   Sender ID: \(currentUserId)")
                print("   Sender Name: \(currentUserName)")
                print("   Recipient ID: \(recipientId)")
                print("   Conversation ID: \(conversation.id)")
                print("   Participant IDs: \(conversation.participantIds)")
                print("   Is Group Chat: \(conversation.isGroupChat)")
                print("🚀🚀🚀")
                webSocketService.sendMessage(
                    messageId: message.id,
                    conversationId: conversation.id,
                    senderId: currentUserId,
                    senderName: currentUserName,
                    recipientId: recipientId,
                    recipientIds: conversation.isGroupChat ? conversation.participantIds : [recipientId],
                    isGroupChat: conversation.isGroupChat,
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
        
        // Notify recipients via WebSocket
        webSocketService.sendDeleteMessage(
            messageId: message.id,
            conversationId: conversation.id,
            senderId: currentUserId,
            recipientId: recipientId,
            recipientIds: conversation.isGroupChat ? conversation.participantIds.filter { $0 != currentUserId } : nil,
            isGroupChat: conversation.isGroupChat
        )
    }
    
    private func editMessage(_ message: MessageData) {
        print("✏️ Edit triggered for message: \(message.id)")
        print("   Current content: \(message.content)")
        
        // Only allow editing your own messages
        guard message.senderId == currentUserId else {
            print("   ❌ Cannot edit: not sender")
            return
        }
        
        // Cannot edit deleted messages
        guard !message.isDeleted else {
            print("   ❌ Cannot edit: message is deleted")
            return
        }
        
        // Set up editing state - populate message bar
        messageToEdit = message
        messageText = message.content
        isInputFocused = true
    }
    
    private func saveEdit() {
        guard let message = messageToEdit else { return }
        let trimmedText = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedText.isEmpty else {
            // Don't allow empty edits - cancel edit mode
            messageToEdit = nil
            messageText = ""
            return
        }
        
        // Don't save if content hasn't changed
        guard trimmedText != message.content else {
            messageToEdit = nil
            messageText = ""
            return
        }
        
        print("💾 Saving edit for message: \(message.id)")
        print("   Old: \(message.content)")
        print("   New: \(trimmedText)")
        
        // Update local message
        message.content = trimmedText
        message.isEdited = true
        message.editedAt = Date()
        
        // Update in visible messages
        if let index = visibleMessages.firstIndex(where: { $0.id == message.id }) {
            visibleMessages[index].content = trimmedText
            visibleMessages[index].isEdited = true
            visibleMessages[index].editedAt = Date()
        }
        
        // Update conversation's lastMessage if this was the most recent message
        if let lastMsg = visibleMessages.last, lastMsg.id == message.id {
            conversation.lastMessage = trimmedText
            print("   📝 Updated conversation preview to: \(trimmedText)")
        }
        
        do {
            try modelContext.save()
            print("   ✅ Message edited in local database")
            
            // Trigger UI refresh
            refreshTick += 1
            
            // Send edit to backend
            webSocketService.sendEditMessage(
                messageId: message.id,
                conversationId: conversation.id,
                senderId: currentUserId,
                senderName: currentUserName,
                newContent: trimmedText,
                recipientIds: conversation.isGroupChat ? conversation.participantIds : [recipientId],
                isGroupChat: conversation.isGroupChat
            )
            
            // Clear edit state
            messageToEdit = nil
            messageText = ""
        } catch {
            print("   ❌ Error editing message: \(error)")
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
        print("   From: \(payload.senderId), Current user: \(currentUserId)")
        print("   Content: \(payload.content)")
        print("   Message Type: \(payload.messageType ?? "text")")
        if let audioUrl = payload.audioUrl {
            print("   Audio URL: \(audioUrl)")
        }
        if let duration = payload.audioDuration {
            print("   Duration: \(duration)s")
        }
        
        // Check if this is a voice message
        if payload.messageType == "voice" {
            print("🎤 VOICE MESSAGE RECEIVED - Processing as voice message")
        } else {
            print("📝 TEXT MESSAGE RECEIVED - Processing as text message")
        }
        
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
            replyToSenderName: payload.replyToSenderName,
            // Voice message fields
            messageType: payload.messageType,
            audioUrl: payload.audioUrl,
            audioDuration: payload.audioDuration,
            transcript: payload.transcript,
            isTranscribing: payload.isTranscribing ?? false
        )
        
        // Debug the created message
        print("📝 Created MessageData:")
        print("   ID: \(newMessage.id)")
        print("   Message Type: \(newMessage.messageType ?? "nil")")
        print("   Audio URL: \(newMessage.audioUrl ?? "nil")")
        print("   Duration: \(newMessage.audioDuration ?? 0)s")
        print("   Content: \(newMessage.content)")
        
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
    
    private func handleEditedMessage(_ payload: EditPayload) {
        // Only handle edits for this conversation
        guard payload.conversationId == conversation.id else { return }
        
        print("✏️ Received edit notification for message: \(payload.messageId)")
        print("   New content: \(payload.newContent)")
        
        // Update DB with edited content
        do {
            let fetch = FetchDescriptor<MessageData>()
            if let msg = try modelContext.fetch(fetch).first(where: { $0.id == payload.messageId }) {
                msg.content = payload.newContent
                msg.isEdited = true
                
                // Parse editedAt timestamp
                if let editedDate = ISO8601DateFormatter().date(from: payload.editedAt) {
                    msg.editedAt = editedDate
                }
                
                try modelContext.save()
                print("   ✅ Message updated in database")
                
                // Update in visible messages
                if let index = visibleMessages.firstIndex(where: { $0.id == payload.messageId }) {
                    visibleMessages[index].content = payload.newContent
                    visibleMessages[index].isEdited = true
                    if let editedDate = ISO8601DateFormatter().date(from: payload.editedAt) {
                        visibleMessages[index].editedAt = editedDate
                    }
                }
                
                // Update conversation's lastMessage if this was the most recent message
                if let lastMsg = visibleMessages.last, lastMsg.id == payload.messageId {
                    conversation.lastMessage = payload.newContent
                    print("   📝 Updated conversation preview from edit: \(payload.newContent)")
                }
                
                // Trigger UI refresh
                refreshTick += 1
            }
        } catch {
            print("❌ Error applying edit: \(error)")
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
                // Find the specific message from the payload
                if let msg = msgs.first(where: { $0.id == payload.messageId }) {
                    print("   Found message to mark as read: \(msg.id)")
                    
                    // For outgoing messages from current user
                    if msg.senderId == currentUserId {
                        // For direct messages, clear previous read flags
                        if !conversation.isGroupChat {
                            for m in msgs where m.senderId == currentUserId {
                                m.isRead = false
                                m.readAt = nil
                            }
                        }
                        
                        msg.status = "read"
                        msg.isRead = true
                        
                        // Always set a readAt timestamp
                        if let s = payload.readAt {
                            if let d = ISO8601DateFormatter().date(from: s) {
                                msg.readAt = d
                                print("   ✅ Set readAt from server=\(d) for message \(msg.id)")
                            } else {
                                msg.readAt = Date()
                                print("   ⚠️ Failed to parse readAt timestamp: \(s), using current time")
                            }
                        } else {
                            msg.readAt = Date()
                            print("   ⚠️ No readAt timestamp in payload, using current time")
                        }
                    }
                    
                    // For group chats, ALWAYS update who has read the message (regardless of sender)
                    if conversation.isGroupChat {
                        if let readByUserIds = payload.readByUserIds {
                            msg.readByUserIds = readByUserIds
                            print("   👥 Read by user IDs: \(readByUserIds.joined(separator: ", "))")
                        }
                        if let readByUserNames = payload.readByUserNames {
                            msg.readByUserNames = readByUserNames
                            print("   👥 Read by: \(readByUserNames.joined(separator: ", "))")
                        }
                        if let readTimestamps = payload.readTimestamps {
                            // Convert String timestamps to Date
                            var timestamps: [String: Date] = [:]
                            for (userId, timestampStr) in readTimestamps {
                                if let date = ISO8601DateFormatter().date(from: timestampStr) {
                                    timestamps[userId] = date
                                    print("   ⏰ Timestamp for \(userId): \(date)")
                                } else {
                                    print("   ⚠️ Failed to parse timestamp: \(timestampStr)")
                                }
                            }
                            msg.readTimestamps = timestamps
                            print("   👥 Read timestamps stored for \(timestamps.count) users")
                            print("   📝 Message.readTimestamps now has: \(msg.readTimestamps)")
                        } else {
                            print("   ⚠️ No readTimestamps in payload")
                        }
                    }
                } else {
                    print("   ⚠️ Message not found: \(payload.messageId)")
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
            readerName: currentUserName,
            messageReads: reads.map { ["messageId": $0.id, "senderId": $0.senderId] },
            isGroupChat: conversation.isGroupChat
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
    
    // MARK: - Voice Message Functions
    
    private func startVoiceRecording() {
        guard !voiceRecorder.isRecording else { 
            print("⚠️ Recording already in progress - ignoring start request")
            return 
        }
        
        // Check permission first
        guard voiceRecorder.hasPermission else {
            print("❌ No microphone permission - requesting...")
            voiceRecorder.requestMicrophonePermission()
            return
        }
        
        print("🎤 Starting voice recording")
        voiceRecorder.startRecording()
        isInputFocused = false // Dismiss keyboard
    }
    
    private func stopVoiceRecording() {
        guard voiceRecorder.isRecording else { 
            print("⚠️ No recording in progress")
            return 
        }
        
        print("🎤 Stopping voice recording...")
        
        let duration = voiceRecorder.recordingDuration
        
        // Step 1: Cancel any ongoing transcription first
        print("🔧 Step 1: Cancelling ongoing transcription...")
        voiceToTextService.cancelTranscription()
        print("✅ Transcription cancelled")
        
        // Step 2: Stop recording
        print("🔧 Step 2: Stopping voice recording...")
        if let audioURL = voiceRecorder.stopRecording() {
            // Check minimum duration (1 second)
            if duration >= 1.0 {
                print("✅ Voice message recorded: \(String(format: "%.1f", duration))s")
                recordedVoiceURL = audioURL
                recordedVoiceDuration = duration
                
                print("📁 Voice file saved at: \(audioURL.path)")
                print("🎤 Sending voice message for transcription")
                
                // Step 3: Add delay before starting transcription
                print("🔧 Step 3: Adding 0.1s delay before transcription...")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    self.sendVoiceMessage(audioURL: audioURL, duration: duration)
                }
            } else {
                print("⚠️ Recording too short (< 1s), cancelling")
                voiceRecorder.cancelRecording()
            }
        } else {
            print("❌ Failed to stop recording - no audio file returned")
            voiceRecorder.cancelRecording()
        }
    }
    
    private func cancelVoicePreview() {
        print("🗑️ Cancelling voice preview")
        
        // Stop playback if playing (no longer needed for voice-to-text)
        
        // Delete the recording file
        if let url = recordedVoiceURL {
            try? FileManager.default.removeItem(at: url)
            print("🗑️ Deleted voice recording")
        }
        
        // Reset state
        recordedVoiceURL = nil
        recordedVoiceDuration = 0
        showVoicePreview = false
    }
    
    private func sendVoiceMessageFromPreview() {
        guard let audioURL = recordedVoiceURL else { return }
        
        print("📤 Sending voice message from preview")
        
        // Stop playback if playing (no longer needed for voice-to-text)
        
        // Send the voice message
        sendVoiceMessage(audioURL: audioURL, duration: recordedVoiceDuration)
        
        // Reset preview state
        showVoicePreview = false
    }
    
    private func sendVoiceMessage(audioURL: URL, duration: TimeInterval) {
        print("📤 Converting voice to text:")
        print("   Duration: \(String(format: "%.1f", duration))s")
        print("   File: \(audioURL.lastPathComponent)")
        
        // Check if audio file exists and has content
        do {
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: audioURL.path)
            let fileSize = fileAttributes[.size] as? Int64 ?? 0
            
            if fileSize > 0 {
                print("   ✅ Audio file exists and has content: \(fileSize) bytes")
            } else {
                print("   ❌ Audio file is empty")
                throw NSError(domain: "AudioError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Audio file is empty"])
            }
        } catch {
            print("   ❌ Audio file validation failed: \(error)")
            print("   📝 Sending as placeholder text due to invalid audio")
            
            // Send placeholder instead of trying to transcribe invalid audio
            let messageId = UUID().uuidString
            sendVoiceToTextPlaceholder(duration: duration, messageId: messageId)
            cleanupVoiceRecording()
            return
        }
        
        if let fileSize = voiceRecorder.getFileSize(url: audioURL) {
            print("   Size: \(fileSize) bytes (\(Double(fileSize) / 1024.0) KB)")
        }
        
        // Generate unique message ID
        let messageId = UUID().uuidString
        
        // Convert voice to text with timeout protection
        voiceToTextService.transcribeAudioFile(url: audioURL) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let transcribedText):
                    print("✅ Voice transcribed successfully: \(transcribedText)")
                    sendTranscribedText(transcribedText: transcribedText, messageId: messageId)
                case .failure(let error):
                    print("❌ Voice transcription failed: \(error)")
                    // Fallback to placeholder text
                    sendVoiceToTextPlaceholder(duration: duration, messageId: messageId)
                }
                cleanupVoiceRecording()
            }
        }
        
        // Add a safety timeout to prevent hanging
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if voiceToTextService.isTranscribing {
                print("⏰ Transcription timeout - falling back to placeholder")
                voiceToTextService.cancelTranscription()
                sendVoiceToTextPlaceholder(duration: duration, messageId: messageId)
                cleanupVoiceRecording()
            }
        }
    }
    
    private func sendTranscribedText(transcribedText: String, messageId: String) {
        // Create text message with transcribed content
        let message = MessageData(
            id: messageId,
            conversationId: conversation.id,
            senderId: currentUserId,
            senderName: currentUserName,
            content: transcribedText,
            timestamp: Date(),
            status: "sending",
            messageType: "voice-to-text", // Mark as voice-to-text for identification
            audioUrl: nil,
            audioDuration: nil
        )
        
        do {
            modelContext.insert(message)
            try modelContext.save()
            
            // Send as regular text message via WebSocket
            webSocketService.sendMessage(
                messageId: messageId,
                conversationId: conversation.id,
                senderId: currentUserId,
                senderName: currentUserName,
                recipientId: recipientId,
                recipientIds: conversation.isGroupChat ? conversation.participantIds : [recipientId],
                isGroupChat: conversation.isGroupChat,
                content: transcribedText,
                timestamp: Date(),
                messageType: "voice-to-text"
            )
            
            conversation.lastMessage = transcribedText
            conversation.lastMessageTime = Date()
            try modelContext.save()
            
            print("✅ Voice-to-text message sent: \(transcribedText)")
            
        } catch {
            print("❌ Error sending voice-to-text message: \(error)")
        }
    }
    
    private func sendVoiceToTextPlaceholder(duration: TimeInterval, messageId: String) {
        // Fallback: Send text placeholder when transcription fails
        let placeholderText = "🎤 Voice message (\(formatRecordingDuration(duration))) - Transcription failed"
        
        let message = MessageData(
            id: messageId,
            conversationId: conversation.id,
            senderId: currentUserId,
            senderName: currentUserName,
            content: placeholderText,
            timestamp: Date(),
            status: "sending",
            messageType: "voice-to-text"
        )
        
        do {
            modelContext.insert(message)
            try modelContext.save()
            
            webSocketService.sendMessage(
                messageId: messageId,
                conversationId: conversation.id,
                senderId: currentUserId,
                senderName: currentUserName,
                recipientId: recipientId,
                recipientIds: conversation.isGroupChat ? conversation.participantIds : [recipientId],
                isGroupChat: conversation.isGroupChat,
                content: placeholderText,
                timestamp: Date(),
                messageType: "voice-to-text"
            )
            
            conversation.lastMessage = placeholderText
            conversation.lastMessageTime = Date()
            try modelContext.save()
            
            print("✅ Voice-to-text placeholder sent")
            
        } catch {
            print("❌ Error sending voice-to-text placeholder: \(error)")
        }
    }
    
    private func sendVoiceMessageWithURL(s3URL: String, duration: TimeInterval, messageId: String) {
        // Create voice message with actual S3 URL
        let message = MessageData(
            id: messageId,
            conversationId: conversation.id,
            senderId: currentUserId,
            senderName: currentUserName,
            content: "🎤 Voice message", // Placeholder text for notifications
            timestamp: Date(),
            status: "sending",
            messageType: "voice",
            audioUrl: s3URL,
            audioDuration: duration
        )
        
        do {
            modelContext.insert(message)
            try modelContext.save()
            
            // TODO: Update WebSocket to send voice message with URL
            // For now, send as regular message
            // Use the same recipientId logic as regular messages
            
            webSocketService.sendMessage(
                messageId: messageId,
                conversationId: conversation.id,
                senderId: currentUserId,
                senderName: currentUserName,
                recipientId: recipientId,
                recipientIds: conversation.isGroupChat ? conversation.participantIds : [recipientId],
                isGroupChat: conversation.isGroupChat,
                content: "🎤 Voice message (\(formatRecordingDuration(duration)))",
                timestamp: Date(),
                messageType: "voice",
                audioUrl: s3URL,
                audioDuration: duration
            )
            
            conversation.lastMessage = "🎤 Voice message"
            conversation.lastMessageTime = Date()
            try modelContext.save()
            
            print("✅ Voice message with S3 URL sent")
            cleanupVoiceRecording()
            
        } catch {
            print("❌ Error sending voice message: \(error)")
        }
    }
    
    private func sendVoiceMessagePlaceholder(duration: TimeInterval, messageId: String) {
        // Fallback: Send text placeholder (Phase A behavior)
        let placeholderText = "🎤 Voice message (\(formatRecordingDuration(duration)))"
        
        let message = MessageData(
            id: messageId,
            conversationId: conversation.id,
            senderId: currentUserId,
            senderName: currentUserName,
            content: placeholderText,
            timestamp: Date(),
            status: "sending"
        )
        
        do {
            modelContext.insert(message)
            try modelContext.save()
            
            // Use the same recipientId logic as regular messages
            webSocketService.sendMessage(
                messageId: messageId,
                conversationId: conversation.id,
                senderId: currentUserId,
                senderName: currentUserName,
                recipientId: recipientId,
                recipientIds: conversation.isGroupChat ? conversation.participantIds : [recipientId],
                isGroupChat: conversation.isGroupChat,
                content: placeholderText,
                timestamp: Date()
            )
            
            conversation.lastMessage = placeholderText
            conversation.lastMessageTime = Date()
            try modelContext.save()
            
            print("✅ Voice message placeholder sent")
            cleanupVoiceRecording()
            
        } catch {
            print("❌ Error sending voice message: \(error)")
        }
    }
    
    private func cleanupVoiceRecording() {
        print("🔧 Cleaning up voice recording...")
        
        // Step 1: Cancel any ongoing transcription
        print("🔧 Step 1: Cancelling transcription...")
        voiceToTextService.cancelTranscription()
        print("✅ Transcription cancelled")
        
        // Step 2: Reset all voice recording state
        print("🔧 Step 2: Resetting recording state...")
        recordedVoiceURL = nil
        recordedVoiceDuration = 0
        showVoicePreview = false
        print("✅ Recording state reset")
        
        print("🧹 Voice recording cleanup completed")
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: MessageData
    let currentUserId: String // ✅ Added to determine bubble placement
    let conversation: ConversationData // Added to show sender names in group chats
    let lastReadMessageId: String?
    let refreshKey: Int
    let messageBubbleColor: Color // Custom message color
    let onReply: () -> Void
    let onDelete: () -> Void
    let onEmphasize: () -> Void
    let onForward: () -> Void
    let onEdit: () -> Void
    let onTapReply: (String) -> Void
    let onTranslate: () -> Void
    let onExplainSlang: () -> Void
    let onTranslateAndExplain: () -> Void
    
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
                    // Show sender name for group chats (only for other users' messages)
                    if conversation.isGroupChat && !isFromCurrentUser {
                        Text(message.senderName)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .padding(.leading, 16)
                            .padding(.bottom, 2)
                    }
                    
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
                        // Voice message or text message
                        if message.messageType == "voice" {
                            VoiceMessageBubble(
                                message: message,
                                isFromCurrentUser: isFromCurrentUser,
                                messageBubbleColor: messageBubbleColor
                            )
                            .onAppear {
                                print("🎤 RENDERING VoiceMessageBubble for message: \(message.id)")
                                print("🎤 Message type: \(message.messageType ?? "nil")")
                                print("🎤 Audio URL: \(message.audioUrl ?? "nil")")
                            }
                        } else if message.messageType == "voice-to-text" {
                            // Voice-to-text message - show with special indicator
                            HStack(spacing: 8) {
                                Image(systemName: "waveform")
                                    .foregroundColor(isFromCurrentUser ? .white.opacity(0.8) : .blue)
                                    .font(.system(size: 14))
                                
                                Text(message.content)
                                    .font(.body)
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(isFromCurrentUser ? messageBubbleColor : Color(.systemGray5))
                            .foregroundColor(isFromCurrentUser ? .white : .primary)
                            .cornerRadius(20)
                            .onAppear {
                                print("🎤 RENDERING Voice-to-text message for message: \(message.id)")
                                print("🎤 Content: \(message.content)")
                            }
                        } else {
                            Text(message.content)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(isFromCurrentUser ? messageBubbleColor : Color(.systemGray5))
                                .foregroundColor(isFromCurrentUser ? .white : .primary)
                                .cornerRadius(20)
                                .onAppear {
                                    print("📝 RENDERING Text message for message: \(message.id)")
                                    print("📝 Message type: \(message.messageType ?? "nil")")
                                }
                        }
                        
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
                // "Edited" label - shown for all users if message was edited
                if message.isEdited && !isLastOutgoingRead {
                    Text("Edited")
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .padding(.top, 2)
                }
                // Read receipt with profile icons - shown only for the most recent outgoing message
                if isFromCurrentUser, isLastOutgoingRead {
                    HStack(spacing: 6) {
                        // For group chats, show profile icons of who has read
                        if conversation.isGroupChat && !message.readByUserNames.isEmpty {
                            Text("Read by")
                                .font(.caption2)
                                .foregroundColor(.gray)
                            
                            // Show profile picture icons (up to 3)
                            HStack(spacing: -8) {
                                ForEach(Array(message.readByUserNames.prefix(3)), id: \.self) { userName in
                                    // Skip current user if somehow in the list
                                    if userName != currentUserId {
                                        ProfileIcon(name: userName, size: 20)
                                    }
                                }
                                
                                // If more than 3 readers, show count
                                if message.readByUserNames.count > 3 {
                                    ZStack {
                                        Circle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 20, height: 20)
                                        Text("+\(message.readByUserNames.count - 3)")
                                            .font(.system(size: 9, weight: .medium))
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                        } else {
                            Text("Read")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                        
                        if let t = message.readAt {
                            Text(readTime(t))
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.top, 4)
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
                    // AI Understanding options - only for incoming messages
                    if !isFromCurrentUser && !message.isDeleted {
                        Button(action: onTranslateAndExplain) {
                            Label("Translate & Explain", systemImage: "sparkles")
                        }
                        
                        Divider()
                    }
                    
                    // View Read Receipts - only for group chats and sender's own messages
                    if conversation.isGroupChat && isFromCurrentUser && !message.isDeleted {
                        NavigationLink(destination: ReadReceiptDetailsView(message: message, conversation: conversation)) {
                            Label("View Read Receipts", systemImage: "eye.fill")
                        }
                        
                        Divider()
                    }
                    
                    // Edit option - only for sender's own messages
                    if isFromCurrentUser && !message.isDeleted {
                        Button(action: onEdit) {
                            Label("Edit", systemImage: "pencil")
                        }
                    }
                    
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
        } // End of else (non-deleted messages)
    } // End of body
    
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
    
    // Format read by names for group chats
    private func formatReadByNames(_ names: [String]) -> String {
        guard !names.isEmpty else { return "" }
        
        // Filter out current user's name
        let otherNames = names.filter { $0 != currentUserId }
        
        if otherNames.isEmpty {
            return ""
        } else if otherNames.count == 1 {
            return otherNames[0]
        } else if otherNames.count == 2 {
            return "\(otherNames[0]) and \(otherNames[1])"
        } else {
            // Show first 2 names and count of others
            return "\(otherNames[0]), \(otherNames[1]) and \(otherNames.count - 2) other\(otherNames.count - 2 == 1 ? "" : "s")"
        }
    }
} // End of MessageBubble struct

// MARK: - Typing Dot Animation

// Removed TypingDot struct - using simplified inline animation instead

// MARK: - Profile Icon for Read Receipts

struct ProfileIcon: View {
    let name: String
    let size: CGFloat
    
    private var initials: String {
        let words = name.split(separator: " ")
        let firstInitial = words.first?.prefix(1).uppercased() ?? ""
        let lastInitial = words.count > 1 ? words.last?.prefix(1).uppercased() ?? "" : ""
        return firstInitial + lastInitial
    }
    
    private var backgroundColor: Color {
        // Generate a consistent color based on the name
        let hash = name.hashValue
        let colors: [Color] = [.blue, .green, .purple, .orange, .pink, .red, .cyan, .indigo]
        return colors[abs(hash) % colors.count]
    }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor.gradient)
                .frame(width: size, height: size)
            
            Text(initials)
                .font(.system(size: size * 0.4, weight: .semibold, design: .rounded))
                .foregroundColor(.white)
        }
        .overlay(
            Circle()
                .stroke(Color.white, lineWidth: 1)
        )
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

// MARK: - Voice Message Bubble Component
struct VoiceMessageBubble: View {
    let message: MessageData
    let isFromCurrentUser: Bool
    let messageBubbleColor: Color
    
    @StateObject private var voicePlayer = VoiceMessagePlayer()
    @State private var isPlaying = false
    @State private var currentTime: TimeInterval = 0
    @State private var duration: TimeInterval = 0
    @State private var isLoading = false
    @State private var hasError = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Play/Pause button
            Button(action: togglePlayback) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.title2)
                    .foregroundColor(isFromCurrentUser ? .white : .blue)
            }
            .disabled(isLoading)
            .onAppear {
                print("🎤 VoiceMessageBubble BODY rendered for message: \(message.id)")
                print("🎤 Audio URL: \(message.audioUrl ?? "nil")")
                print("🎤 Duration: \(message.audioDuration ?? 0)s")
            }
            
            // Waveform and duration
            VStack(alignment: .leading, spacing: 4) {
                // Waveform visualization
                if isLoading {
                    HStack(spacing: 2) {
                        ForEach(0..<8, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(isFromCurrentUser ? Color.white.opacity(0.6) : Color.gray.opacity(0.6))
                                .frame(width: 3, height: 8)
                                .animation(.easeInOut(duration: 0.5).repeatForever(), value: isLoading)
                        }
                    }
                } else if hasError {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("🎤 Voice message")
                            .font(.subheadline)
                            .foregroundColor(isFromCurrentUser ? .white : .primary)
                        
                        Button("Retry") {
                            hasError = false
                            playVoiceMessage()
                        }
                        .font(.caption)
                        .foregroundColor(isFromCurrentUser ? .white.opacity(0.8) : .blue)
                    }
                } else {
                    VoicePlaybackWaveformView(
                        isPlaying: isPlaying,
                        currentTime: currentTime,
                        duration: duration
                    )
                }
                
                // Duration
                Text(formatDuration(currentTime))
                    .font(.caption)
                    .foregroundColor(isFromCurrentUser ? .white.opacity(0.8) : .secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(isFromCurrentUser ? messageBubbleColor : Color(.systemGray5))
        .cornerRadius(20)
        .onAppear {
            setupAudioPlayer()
        }
        .onDisappear {
            voicePlayer.stop()
        }
    }
    
    private func setupAudioPlayer() {
        duration = message.audioDuration ?? 0
        
        print("🎵 Setting up voice player for message: \(message.id)")
        print("🎵 Audio URL: \(message.audioUrl ?? "nil")")
        print("🎵 Duration: \(duration)s")
        print("🎵 Message type: \(message.messageType ?? "nil")")
        
        // Set up player callbacks
        voicePlayer.onPlaybackStateChanged = { playing in
            print("🎵 Playback state changed: \(playing)")
            isPlaying = playing
        }
        
        voicePlayer.onTimeUpdate = { time in
            currentTime = time
        }
        
        voicePlayer.onError = { error in
            print("❌ Voice playback error: \(error)")
            hasError = true
            isLoading = false
        }
    }
    
    private func togglePlayback() {
        if isPlaying {
            voicePlayer.pause()
        } else {
            playVoiceMessage()
        }
    }
    
    private func playVoiceMessage() {
        guard let audioURLString = message.audioUrl,
              let audioURL = URL(string: audioURLString) else {
            print("❌ Voice message has no audio URL")
            hasError = true
            return
        }
        
        print("🎵 Playing voice message from: \(audioURLString)")
        print("🎵 Message ID: \(message.id)")
        print("🎵 Duration: \(message.audioDuration ?? 0)s")
        isLoading = true
        hasError = false
        
        // Try to play from URL (handles both local and S3 URLs)
        voicePlayer.play(url: audioURL) { success in
            DispatchQueue.main.async {
                isLoading = false
                if success {
                    print("✅ Voice message playback started successfully")
                } else {
                    print("❌ Voice message playback failed")
                    hasError = true
                }
            }
        }
    }
    
    private func generateMockWaveform() -> [Float] {
        // Generate a simple waveform pattern
        let count = 20
        return (0..<count).map { _ in Float.random(in: 0.1...1.0) }
    }
    
    private func formatDuration(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Voice Playback Waveform Component
struct VoicePlaybackWaveformView: View {
    let isPlaying: Bool
    let currentTime: TimeInterval
    let duration: TimeInterval
    
    @State private var animationPhase: CGFloat = 0
    
    private let barCount = 20
    private let barWidth: CGFloat = 3
    private let barSpacing: CGFloat = 2
    
    var body: some View {
        HStack(spacing: barSpacing) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: barWidth / 2)
                    .fill(Color.blue.opacity(0.7))
                    .frame(width: barWidth, height: barHeight(for: index))
                    .animation(
                        .easeInOut(duration: 0.3)
                        .delay(Double(index) * 0.01),
                        value: animationPhase
                    )
            }
        }
        .frame(height: 30)
        .onAppear {
            if isPlaying {
                startAnimation()
            }
        }
        .onChange(of: isPlaying) { _, newValue in
            if newValue {
                startAnimation()
            } else {
                stopAnimation()
            }
        }
    }
    
    private func startAnimation() {
        withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
            animationPhase = 1
        }
    }
    
    private func stopAnimation() {
        withAnimation(.easeOut(duration: 0.3)) {
            animationPhase = 0
        }
    }
    
    private func barHeight(for index: Int) -> CGFloat {
        let baseHeight: CGFloat = 4
        let maxHeight: CGFloat = 30
        
        if !isPlaying {
            return baseHeight
        }
        
        // Create wave pattern based on index and animation phase
        let normalizedIndex = CGFloat(index) / CGFloat(barCount)
        let waveOffset = sin(normalizedIndex * .pi * 4 + animationPhase * .pi * 2)
        
        // Add some randomness for more natural look
        let randomFactor = CGFloat.random(in: 0.7...1.0)
        let height = baseHeight + (maxHeight - baseHeight) * abs(waveOffset) * randomFactor
        
        return max(baseHeight, height)
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

