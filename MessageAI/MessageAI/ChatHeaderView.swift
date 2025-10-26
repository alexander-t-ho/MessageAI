//
//  ChatHeaderView.swift
//  MessageAI
//
//  Chat header with user icon and online status
//

import SwiftUI

struct ChatHeaderView: View {
    let conversation: ConversationData
    let userPresence: [String: Bool]
    let currentUserId: String
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showNicknameEditor = false
    
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
            return userPresence[id] ?? false
        }
        return false
    }
    
    var body: some View {
        // User info for 1-on-1 chats
        if !conversation.isGroupChat, let userId = otherUserId {
            Button(action: {
                showNicknameEditor = true  // Shows full user profile
            }) {
                HStack(spacing: 10) {
                    // Profile icon with online status halo
                    ZStack {
                        // Online status halo behind profile (solid, more visible)
                        if isOnline {
                            Circle()
                                .fill(Color.green.opacity(0.5))
                                .frame(width: 46, height: 46)
                        }
                        
                        // Profile photo or initial
                        ProfileIconWithCustomization(
                            userId: userId,
                            userName: otherUserName,
                            size: 36
                        )
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(otherUserName)
                            .font(.headline)
                            .lineLimit(1)
                            .foregroundColor(.primary)
                        
                        Text(isOnline ? "Online" : "Offline")
                            .font(.caption)
                            .foregroundColor(isOnline ? .green : .secondary)
                    }
                }
            }
            .buttonStyle(PlainButtonStyle())
            .sheet(isPresented: $showNicknameEditor) {
                if let uid = otherUserId {
                    UserProfileView(
                        userId: uid,
                        username: otherUserName,
                        isOnline: isOnline
                    )
                }
            }
        } else {
            // Group chat header
            Button(action: {
                // Show group details
            }) {
                VStack(spacing: 2) {
                    Text(conversation.groupName ?? "Group Chat")
                        .font(.headline)
                        .lineLimit(1)
                        .foregroundColor(.primary)
                    
                    // Show online members count
                    let onlineCount = conversation.participantIds.filter { userPresence[$0] == true }.count
                    Text("\(onlineCount) online")
                        .font(.caption)
                        .foregroundColor(onlineCount > 0 ? .green : .secondary)
                }
            }
            .buttonStyle(PlainButtonStyle())
        }
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
        userPresence: ["user2": true],
        currentUserId: "user1"
    )
}

