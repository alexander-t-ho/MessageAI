//
//  GroupChatView.swift
//  MessageAI
//
//  Created on 10/20/2025.
//

import SwiftUI
import PhotosUI

struct GroupChatView: View {
    @StateObject private var viewModel: GroupViewModel
    @StateObject private var networkMonitor = NetworkMonitor()
    @State private var messageText = ""
    @State private var selectedImage: PhotosPickerItem?
    @State private var isUploading = false
    
    let groupId: String
    let currentUserId: String
    
    init(groupId: String, currentUserId: String) {
        self.groupId = groupId
        self.currentUserId = currentUserId
        _viewModel = StateObject(wrappedValue: GroupViewModel(currentUserId: currentUserId))
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
                            GroupMessageBubble(
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
        .navigationTitle("Group Chat")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            viewModel.startListeningToMessages(groupId: groupId)
        }
        .onDisappear {
            viewModel.stopListening()
        }
    }
    
    private func sendMessage() {
        let text = messageText
        messageText = ""
        
        Task {
            await viewModel.sendMessage(groupId: groupId, text: text)
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
                if let imageUrl = try? await storageService.uploadChatImage(uiImage, chatId: groupId) {
                    await viewModel.sendMessage(groupId: groupId, text: "Image", imageUrl: imageUrl)
                }
                
                isUploading = false
            }
            
            self.selectedImage = nil
        }
    }
}

struct GroupMessageBubble: View {
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
                        .fontWeight(.semibold)
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
                
                Text(message.timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: 250, alignment: isFromCurrentUser ? .trailing : .leading)
            
            if !isFromCurrentUser {
                Spacer()
            }
        }
    }
}

#Preview {
    NavigationStack {
        GroupChatView(groupId: "preview-group", currentUserId: "preview-user")
    }
}

