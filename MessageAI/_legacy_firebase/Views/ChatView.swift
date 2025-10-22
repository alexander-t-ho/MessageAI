//
//  ChatView.swift
//  MessageAI
//
//  Created on 10/20/2025.
//

import SwiftUI
import PhotosUI
import SwiftData

struct ChatView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var viewModel: ChatViewModel
    @StateObject private var networkMonitor = NetworkMonitor()
    @State private var messageText = ""
    @State private var selectedImage: PhotosPickerItem?
    @State private var showImagePicker = false
    @State private var isUploading = false
    
    let chatId: String
    let currentUserId: String
    
    init(chatId: String, currentUserId: String) {
        self.chatId = chatId
        self.currentUserId = currentUserId
        _viewModel = StateObject(wrappedValue: ChatViewModel(chatId: chatId, currentUserId: currentUserId))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Connection status banner
            if !networkMonitor.isConnected {
                HStack {
                    Image(systemName: "wifi.slash")
                    Text("No internet connection")
                    Spacer()
                }
                .font(.caption)
                .foregroundColor(.white)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.orange)
            }
            
            // Messages list
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(viewModel.messages) { message in
                            MessageBubble(
                                message: message,
                                isFromCurrentUser: message.senderId == currentUserId
                            )
                            .id(message.id)
                        }
                    }
                    .padding()
                }
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }
            
            // Typing indicator
            if viewModel.isOtherUserTyping {
                HStack {
                    Text("typing...")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .italic()
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.vertical, 4)
            }
            
            // Input area
            HStack(spacing: 12) {
                PhotosPicker(selection: $selectedImage, matching: .images) {
                    Image(systemName: "photo")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                .onChange(of: selectedImage) { _, newValue in
                    if newValue != nil {
                        handleImageSelection()
                    }
                }
                
                TextField("Message", text: $messageText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onChange(of: messageText) { _, newValue in
                        viewModel.updateTypingStatus(!newValue.isEmpty)
                    }
                
                Button(action: {
                    sendMessage()
                }) {
                    if viewModel.isSending {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                    } else {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundColor(messageText.isEmpty ? .gray : .blue)
                    }
                }
                .disabled(messageText.isEmpty || viewModel.isSending)
            }
            .padding()
            .background(Color(.systemBackground))
        }
        .navigationTitle("Chat")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.setModelContext(modelContext)
            viewModel.startListening()
            
            // Sync pending messages if back online
            if networkMonitor.isConnected {
                Task {
                    await viewModel.syncPendingMessages()
                }
            }
        }
        .onDisappear {
            viewModel.stopListening()
            viewModel.updateTypingStatus(false)
        }
    }
    
    private func sendMessage() {
        let text = messageText
        messageText = ""
        viewModel.updateTypingStatus(false)
        
        Task {
            await viewModel.sendMessage(text: text)
        }
    }
    
    private func handleImageSelection() {
        Task {
            if let selectedImage = selectedImage,
               let data = try? await selectedImage.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                
                isUploading = true
                
                // Upload image
                let storageService = StorageService()
                if let imageUrl = try? await storageService.uploadChatImage(uiImage, chatId: chatId) {
                    await viewModel.sendMessage(text: "Image", imageUrl: imageUrl)
                }
                
                isUploading = false
            }
            
            self.selectedImage = nil
        }
    }
}

struct MessageBubble: View {
    let message: Message
    let isFromCurrentUser: Bool
    
    var body: some View {
        HStack {
            if isFromCurrentUser {
                Spacer()
            }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                if !isFromCurrentUser {
                    Text(message.senderName)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                if message.type == .image, let imageUrl = message.imageUrl {
                    AsyncImage(url: URL(string: imageUrl)) { image in
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: 250)
                            .cornerRadius(12)
                    } placeholder: {
                        ProgressView()
                            .frame(width: 250, height: 250)
                    }
                } else {
                    Text(message.text)
                        .padding(12)
                        .background(isFromCurrentUser ? Color.blue : Color(.systemGray5))
                        .foregroundColor(isFromCurrentUser ? .white : .primary)
                        .cornerRadius(16)
                }
                
                HStack(spacing: 4) {
                    Text(message.timestamp, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.gray)
                    
                    if isFromCurrentUser {
                        Image(systemName: statusIcon)
                            .font(.caption2)
                            .foregroundColor(statusColor)
                    }
                }
            }
            .frame(maxWidth: 250, alignment: isFromCurrentUser ? .trailing : .leading)
            
            if !isFromCurrentUser {
                Spacer()
            }
        }
    }
    
    private var statusIcon: String {
        switch message.status {
        case .sending:
            return "clock"
        case .sent:
            return "checkmark"
        case .delivered:
            return "checkmark.checkmark"
        case .read:
            return "checkmark.checkmark"
        case .failed:
            return "exclamationmark.circle"
        }
    }
    
    private var statusColor: Color {
        switch message.status {
        case .read:
            return .blue
        case .failed:
            return .red
        default:
            return .gray
        }
    }
}

#Preview {
    NavigationStack {
        ChatView(chatId: "preview-chat", currentUserId: "preview-user")
            .modelContainer(for: [CachedMessage.self, CachedChat.self, CachedUser.self])
    }
}

