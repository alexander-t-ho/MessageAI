//
//  ContactsListView.swift
//  MessageAI
//
//  List of all available contacts
//

import SwiftUI
import SwiftData

struct ContactsListView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var webSocketService: WebSocketService
    
    @Query(sort: \ContactData.name) private var localContacts: [ContactData]
    @Query private var conversations: [ConversationData]
    @State private var searchText = ""
    @State private var selectedContact: ContactData?
    @State private var showUserProfile = false
    @State private var allUsers: [UserSearchResult] = []
    @State private var isLoadingUsers = false
    
    // Extract unique users from all conversations
    private var usersFromConversations: [UserSearchResult] {
        var userDict: [String: UserSearchResult] = [:]
        let currentUserId = authViewModel.currentUser?.id ?? ""
        
        for conversation in conversations {
            for (index, userId) in conversation.participantIds.enumerated() {
                // Skip current user
                if userId == currentUserId { continue }
                
                // Skip if already added
                if userDict[userId] != nil { continue }
                
                // Get name and email (use placeholder for email if not available)
                let name = index < conversation.participantNames.count ? conversation.participantNames[index] : "User"
                let email = "" // We don't have email from conversations
                
                userDict[userId] = UserSearchResult(userId: userId, name: name, email: email)
            }
        }
        
        return Array(userDict.values)
    }
    
    // Combined users: from conversations + from backend search
    private var combinedUsers: [UserSearchResult] {
        if allUsers.isEmpty {
            // Fallback to users from conversations
            return usersFromConversations
        } else {
            return allUsers
        }
    }
    
    // Filter users based on search (searches name, nickname, and email)
    private var filteredUsers: [UserSearchResult] {
        let usersToFilter = combinedUsers
        
        if searchText.isEmpty {
            return usersToFilter
        } else {
            return usersToFilter.filter { user in
                // Search by real name
                let matchesName = user.name.localizedCaseInsensitiveContains(searchText)
                
                // Search by email (if available)
                let matchesEmail = !user.email.isEmpty && user.email.localizedCaseInsensitiveContains(searchText)
                
                // Search by nickname (if set)
                let nickname = UserCustomizationManager.shared.getNickname(
                    for: user.userId,
                    realName: user.name,
                    modelContext: modelContext
                )
                let matchesNickname = nickname.localizedCaseInsensitiveContains(searchText)
                
                return matchesName || matchesEmail || matchesNickname
            }
        }
    }
    
    // Sort users: online first, then alphabetically
    private var sortedUsers: [UserSearchResult] {
        filteredUsers.sorted { user1, user2 in
            let isOnline1 = webSocketService.userPresence[user1.userId] ?? false
            let isOnline2 = webSocketService.userPresence[user2.userId] ?? false
            
            if isOnline1 == isOnline2 {
                // Same online status - sort alphabetically
                let name1 = UserCustomizationManager.shared.getNickname(for: user1.userId, realName: user1.name, modelContext: modelContext)
                let name2 = UserCustomizationManager.shared.getNickname(for: user2.userId, realName: user2.name, modelContext: modelContext)
                return name1 < name2
            }
            // Online users first
            return isOnline1 && !isOnline2
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search contacts...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .autocorrectionDisabled()
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Users list
                if isLoadingUsers {
                    ProgressView("Loading contacts...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if sortedUsers.isEmpty {
                    ContentUnavailableView(
                        searchText.isEmpty ? "No Users" : "No Results",
                        systemImage: "person.2.slash",
                        description: Text(searchText.isEmpty ? "No users found. Pull to refresh." : "No users match '\(searchText)'")
                    )
                } else {
                    List {
                        // Online section
                        let onlineUsers = sortedUsers.filter { webSocketService.userPresence[$0.userId] ?? false }
                        if !onlineUsers.isEmpty {
                            Section {
                                ForEach(onlineUsers, id: \.userId) { user in
                                    UserListRow(
                                        user: user,
                                        isOnline: true,
                                        onTap: {
                                            selectedContact = ContactData(id: user.userId, email: user.email, name: user.name)
                                            showUserProfile = true
                                        },
                                        modelContext: modelContext
                                    )
                                }
                            } header: {
                                Text("Online (\(onlineUsers.count))")
                            }
                        }
                        
                        // Offline section
                        let offlineUsers = sortedUsers.filter { !(webSocketService.userPresence[$0.userId] ?? false) }
                        if !offlineUsers.isEmpty {
                            Section {
                                ForEach(offlineUsers, id: \.userId) { user in
                                    UserListRow(
                                        user: user,
                                        isOnline: false,
                                        onTap: {
                                            selectedContact = ContactData(id: user.userId, email: user.email, name: user.name)
                                            showUserProfile = true
                                        },
                                        modelContext: modelContext
                                    )
                                }
                            } header: {
                                Text("Offline (\(offlineUsers.count))")
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                    .refreshable {
                        await loadAllUsers()
                    }
                }
            }
            .navigationTitle("Contacts")
            .navigationBarTitleDisplayMode(.large)
            .task {
                await loadAllUsers()
            }
            .sheet(isPresented: $showUserProfile) {
                if let contact = selectedContact {
                    ContactInfoView(
                        userId: contact.id,
                        username: contact.name,
                        email: contact.email,
                        isOnline: webSocketService.userPresence[contact.id] ?? false
                    )
                    .environmentObject(authViewModel)
                    .environmentObject(webSocketService)
                }
            }
        }
    }
    
    // Load all users from backend
    private func loadAllUsers() async {
        isLoadingUsers = true
        
        // For now, we use users from conversations as the source
        // Backend search requires a query, so we'll populate from conversations
        await MainActor.run {
            isLoadingUsers = false
            print("✅ Using users from conversations: \(usersFromConversations.count) users")
        }
        
        // Future: Could implement a "listAllUsers" backend endpoint
        // For now, users from conversations works well
    }
}

// MARK: - User List Row

struct UserListRow: View {
    let user: UserSearchResult
    let isOnline: Bool
    let onTap: () -> Void
    let modelContext: ModelContext
    
    // Get display name (nickname if set, otherwise real name)
    private var displayName: String {
        UserCustomizationManager.shared.getNickname(
            for: user.userId,
            realName: user.name,
            modelContext: modelContext
        )
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Avatar with online indicator
                ZStack(alignment: .bottomTrailing) {
                    Circle()
                        .fill(Color.blue.opacity(0.2))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Text(displayName.prefix(1).uppercased())
                                .font(.title3)
                                .foregroundColor(.blue)
                        )
                    
                    // Online indicator
                    if isOnline {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 14, height: 14)
                            .overlay(
                                Circle()
                                    .stroke(Color(.systemBackground), lineWidth: 2)
                            )
                    }
                }
                
                // Contact info
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    // Show real name if nickname is different
                    if displayName != user.name {
                        Text(user.name)
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                    
                    Text(user.email)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Status text
                Text(isOnline ? "Active now" : "Offline")
                    .font(.caption)
                    .foregroundColor(isOnline ? .green : .gray)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    NavigationStack {
        ContactsListView()
            .environmentObject(AuthViewModel())
            .environmentObject(WebSocketService())
    }
}

