//
//  UserListView.swift
//  MessageAI
//
//  Created on 10/20/2025.
//

import SwiftUI

struct UserListView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel = UserListViewModel()
    @State private var selectedChatId: String?
    @State private var navigateToChatId: String?
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading...")
                } else if viewModel.users.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "person.2.slash")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .foregroundColor(.gray)
                        
                        Text("No users found")
                            .font(.headline)
                            .foregroundColor(.gray)
                    }
                } else {
                    List {
                        Section("Recent Chats") {
                            if viewModel.chats.isEmpty {
                                Text("No recent chats")
                                    .foregroundColor(.gray)
                                    .italic()
                            } else {
                                ForEach(viewModel.chats) { chat in
                                    NavigationLink(value: chat.id) {
                                        ChatPreviewRow(
                                            chat: chat,
                                            currentUserId: authViewModel.currentUser?.id ?? ""
                                        )
                                    }
                                }
                            }
                        }
                        
                        Section("All Users") {
                            ForEach(viewModel.users) { user in
                                Button(action: {
                                    Task {
                                        if let chatId = await viewModel.createChat(with: user.id ?? "") {
                                            navigateToChatId = chatId
                                        }
                                    }
                                }) {
                                    UserRow(user: user)
                                }
                            }
                        }
                    }
                    .navigationDestination(for: String.self) { chatId in
                        if let currentUserId = authViewModel.currentUser?.id {
                            ChatView(chatId: chatId, currentUserId: currentUserId)
                        }
                    }
                    .navigationDestination(item: $navigateToChatId) { chatId in
                        if let currentUserId = authViewModel.currentUser?.id {
                            ChatView(chatId: chatId, currentUserId: currentUserId)
                        }
                    }
                }
            }
            .navigationTitle("Messages")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // Refresh
                        if let userId = authViewModel.currentUser?.id {
                            viewModel.stopListening()
                            viewModel.startListening(currentUserId: userId)
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
        .onAppear {
            if let userId = authViewModel.currentUser?.id {
                viewModel.startListening(currentUserId: userId)
                
                Task {
                    await authViewModel.updateOnlineStatus(true)
                }
            }
        }
        .onDisappear {
            viewModel.stopListening()
        }
    }
}

struct UserRow: View {
    let user: User
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile Picture or Initials
            if let profileUrl = user.profilePictureUrl {
                AsyncImage(url: URL(string: profileUrl)) { image in
                    image
                        .resizable()
                        .scaledToFill()
                } placeholder: {
                    Circle()
                        .fill(Color.blue)
                        .overlay(
                            Text(user.initials)
                                .foregroundColor(.white)
                                .fontWeight(.semibold)
                        )
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.blue)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Text(user.initials)
                            .foregroundColor(.white)
                            .fontWeight(.semibold)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(user.displayName)
                    .font(.headline)
                
                if user.isOnline {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Online")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                } else {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(Color.gray)
                            .frame(width: 8, height: 8)
                        Text("Last seen \(user.lastSeen, style: .relative) ago")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct ChatPreviewRow: View {
    let chat: Chat
    let currentUserId: String
    
    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.blue)
                .frame(width: 50, height: 50)
                .overlay(
                    Text(chat.otherParticipantName(currentUserId: currentUserId).prefix(1))
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(chat.otherParticipantName(currentUserId: currentUserId))
                    .font(.headline)
                
                if chat.isTyping(userId: chat.otherParticipantId(currentUserId: currentUserId) ?? "") {
                    Text("typing...")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .italic()
                } else {
                    Text(chat.lastMessage)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(chat.lastMessageTime, style: .relative)
                    .font(.caption)
                    .foregroundColor(.gray)
                
                if let unreadCount = chat.unreadCount[currentUserId], unreadCount > 0 {
                    Text("\(unreadCount)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 20, height: 20)
                        .background(Color.blue)
                        .clipShape(Circle())
                }
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    UserListView()
        .environmentObject(AuthViewModel())
}

