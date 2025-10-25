//
//  ChatHeaderView.swift
//  MessageAI
//
//  Chat header with user icon and online status
//

import SwiftUI

struct ChatHeaderView: View {
    let conversation: ConversationData
    let onlineUserIds: Set<String>
    let currentUserId: String
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    private var otherUserId: String? {
        conversation.participantIds.first(where: { $0 != currentUserId })
    }
    
    private var otherUserName: String {
        if let id = otherUserId,
           let index = conversation.participantIds.firstIndex(of: id),
           index < conversation.participantNames.count {
            let realName = conversation.participantNames[index]
            // Use custom nickname if set
            return UserCustomizationManager.shared.getNickname(
                for: id,
                realName: realName,
                modelContext: modelContext
            )
        }
        return "User"
    }
    
    private var isOnline: Bool {
        if let id = otherUserId {
            return onlineUserIds.contains(id)
        }
        return false
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Back button
            Button(action: { dismiss() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.semibold))
                    Text("Back")
                }
                .foregroundColor(.blue)
            }
            
            Spacer()
            
            // User info for 1-on-1 chats
            if !conversation.isGroupChat, let userId = otherUserId {
                HStack(spacing: 8) {
                    // Profile icon with online status ring
                    ZStack(alignment: .bottomTrailing) {
                        // Profile photo or initial
                        ProfileIconWithCustomization(
                            userId: userId,
                            userName: otherUserName,
                            size: 36
                        )
                        
                        // Online status indicator
                        Circle()
                            .fill(isOnline ? Color.green : Color.gray)
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 2)
                            )
                    }
                    
                    VStack(alignment: .center, spacing: 2) {
                        Text(otherUserName)
                            .font(.headline)
                            .lineLimit(1)
                        
                        Text(isOnline ? "Online" : "Offline")
                            .font(.caption)
                            .foregroundColor(isOnline ? .green : .secondary)
                    }
                }
                .onTapGesture {
                    // Future: Show user profile details
                }
            } else {
                // Group chat header
                VStack(spacing: 2) {
                    Text(conversation.groupName ?? "Group Chat")
                        .font(.headline)
                        .lineLimit(1)
                    
                    Text("\(conversation.participantIds.count) members")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Info button (placeholder for future features)
            Button(action: {
                // Future: Show conversation details
            }) {
                Image(systemName: "info.circle")
                    .font(.title3)
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(.systemBackground))
    }
}

// Profile icon that checks for custom photo first
struct ProfileIconWithCustomization: View {
    let userId: String
    let userName: String
    let size: CGFloat
    @Environment(\.modelContext) private var modelContext
    @StateObject private var preferences = UserPreferences.shared
    
    var body: some View {
        // Check for custom photo for this user
        if let photoData = UserCustomizationManager.shared.getCustomPhoto(for: userId, modelContext: modelContext),
           let uiImage = UIImage(data: photoData) {
            // Custom photo
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
        } else {
            // Default: colored initial
            Circle()
                .fill(preferences.messageBubbleColor.opacity(0.8))
                .frame(width: size, height: size)
                .overlay(
                    Text(userName.prefix(1).uppercased())
                        .font(.system(size: size * 0.4, weight: .semibold))
                        .foregroundColor(.white)
                )
        }
    }
}

#Preview {
    let conv = ConversationData(
        id: "test",
        participantIds: ["user1", "user2"],
        participantNames: ["Current User", "Other User"],
        isGroupChat: false
    )
    
    return ChatHeaderView(
        conversation: conv,
        onlineUserIds: ["user2"],
        currentUserId: "user1"
    )
}

