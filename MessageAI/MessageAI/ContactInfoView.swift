//
//  ContactInfoView.swift
//  Cloudy
//
//  iOS-style contact information view for Contacts tab
//

import SwiftUI
import SwiftData

struct ContactInfoView: View {
    let userId: String
    let username: String
    let email: String
    let isOnline: Bool
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var webSocketService: WebSocketService
    
    @State private var navigateToChat = false
    @State private var conversation: ConversationData?
    @State private var showingNicknameEdit = false
    @State private var showingUserProfile = false
    @Query private var conversations: [ConversationData]
    
    // Get display name (nickname if set)
    private var displayName: String {
        UserCustomizationManager.shared.getNickname(
            for: userId,
            realName: username,
            modelContext: modelContext
        )
    }
    
    private var hasCustomNickname: Bool {
        displayName != username
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // iOS Contacts-style gradient background
                LinearGradient(
                    colors: [Color(white: 0.95), Color(white: 0.85)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header with photo and name
                    VStack(spacing: 16) {
                        // Profile photo
                        Circle()
                            .fill(Color.blue.opacity(0.2))
                            .frame(width: 140, height: 140)
                            .overlay(
                                Text(displayName.prefix(1).uppercased())
                                    .font(.system(size: 60, weight: .medium))
                                    .foregroundColor(.blue)
                            )
                            .overlay(
                                Circle()
                                    .stroke(isOnline ? Color.green : Color.gray, lineWidth: 4)
                            )
                            .padding(.top, 40)
                        
                        // Name
                        Text(displayName)
                            .font(.system(size: 28, weight: .semibold))
                        
                        // Show real name if nickname is set
                        if displayName != username {
                            Text(username)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.bottom, 30)
                    
                    // Message button
                    ActionButton(icon: "message.fill", label: "message") {
                        createOrOpenConversation()
                    }
                    .padding(.bottom, 30)
                    
                    // Info cards
                    VStack(spacing: 12) {
                        // Contact info card (iOS style)
                        VStack(alignment: .leading, spacing: 0) {
                            // Nickname
                            Button(action: {
                                showingNicknameEdit = true
                            }) {
                                HStack(spacing: 16) {
                                    Image(systemName: "person.text.rectangle")
                                        .foregroundColor(.gray)
                                        .frame(width: 24)
                                    
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("nickname")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                            .textCase(.lowercase)
                                        
                                        Text(hasCustomNickname ? displayName : "Add nickname")
                                            .font(.body)
                                            .foregroundColor(hasCustomNickname ? .primary : .blue)
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                .padding()
                            }
                            
                            Divider()
                                .padding(.leading, 56)
                            
                            // Email
                            if !email.isEmpty {
                                InfoRow(label: "email", value: email, icon: "envelope.fill")
                                
                                Divider()
                                    .padding(.leading, 56)
                            }
                            
                            // Status
                            InfoRow(
                                label: "status",
                                value: isOnline ? "Online" : "Offline",
                                icon: "circle.fill",
                                iconColor: isOnline ? .green : .gray
                            )
                        }
                        .background(Color.white)
                        .cornerRadius(12)
                        .padding(.horizontal)
                    }
                    
                    Spacer()
                }
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.blue)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Edit") {
                        showingUserProfile = true
                    }
                    .foregroundColor(.blue)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingNicknameEdit) {
                EditNicknameView(
                    userId: userId,
                    currentName: displayName,
                    isPresented: $showingNicknameEdit
                )
            }
            .sheet(isPresented: $showingUserProfile) {
                UserProfileView(
                    userId: userId,
                    username: username,
                    isOnline: isOnline
                )
            }
        }
        .onChange(of: navigateToChat) { _, shouldNavigate in
            if shouldNavigate {
                dismiss()
            }
        }
    }
    
    // Create or open conversation
    private func createOrOpenConversation() {
        guard let currentUser = authViewModel.currentUser else {
            print("❌ No current user")
            return
        }
        
        print("🔍 Looking for conversation with user: \(userId)")
        
        // Find existing conversation with this user
        let existingConv = conversations.first { conv in
            !conv.isGroupChat &&
            !conv.isDeleted &&
            conv.participantIds.contains(userId) &&
            conv.participantIds.contains(currentUser.id)
        }
        
        if let found = existingConv {
            print("✅ Found existing conversation: \(found.id)")
            conversation = found
            navigateToChat = true
        } else {
            print("📝 Creating new conversation")
            // Create new conversation
            let newConv = ConversationData(
                participantIds: [currentUser.id, userId],
                participantNames: [currentUser.name, username]
            )
            
            modelContext.insert(newConv)
            
            do {
                try modelContext.save()
                print("✅ Saved new conversation: \(newConv.id)")
                conversation = newConv
                
                // Post notification to open this conversation
                NotificationCenter.default.post(
                    name: Notification.Name("OpenConversation"),
                    object: nil,
                    userInfo: ["conversationId": newConv.id]
                )
                
                dismiss()
            } catch {
                print("❌ Error creating conversation: \(error)")
            }
        }
    }
}

// MARK: - Action Button (iOS Contacts style)

struct ActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Circle()
                    .fill(Color(white: 0.3))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: icon)
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                    )
                
                Text(label)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
        }
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let label: String
    let value: String
    let icon: String
    var iconColor: Color = .gray
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .textCase(.lowercase)
                
                Text(value)
                    .font(.body)
            }
            
            Spacer()
        }
        .padding()
    }
}

#Preview {
    ContactInfoView(
        userId: "test-user",
        username: "Josiah",
        email: "josiah@example.com",
        isOnline: true
    )
    .environmentObject(AuthViewModel())
    .environmentObject(WebSocketService())
}

