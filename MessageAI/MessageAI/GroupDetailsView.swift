//
//  GroupDetailsView.swift
//  MessageAI
//
//  View and manage group chat details
//

import SwiftUI
import SwiftData

struct GroupDetailsView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var webSocketService: WebSocketService
    
    @Bindable var conversation: ConversationData
    @State private var isEditingGroupName = false
    @State private var newGroupName = ""
    @State private var showingAddMembers = false
    @State private var showingError = false
    @State private var errorMessage = ""
    
    // Track online status for each member
    private var onlineMembers: Set<String> {
        Set(conversation.participantIds.filter { userId in
            // Current user is always online if connected
            if userId == authViewModel.currentUser?.id {
                return webSocketService.connectionState == .connected
            }
            return webSocketService.userPresence[userId] ?? false
        })
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Group info section
                Section {
                    // Group name (editable)
                    HStack {
                        if isEditingGroupName {
                            TextField("Group name", text: $newGroupName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .onSubmit {
                                    saveGroupName()
                                }
                            
                            Button("Save") {
                                saveGroupName()
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Button("Cancel") {
                                isEditingGroupName = false
                                newGroupName = conversation.groupName ?? ""
                            }
                            .buttonStyle(.bordered)
                        } else {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Group Name")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                
                                Text(conversation.groupName ?? "Unnamed Group")
                                    .font(.headline)
                            }
                            
                            Spacer()
                            
                            Button("Edit") {
                                newGroupName = conversation.groupName ?? ""
                                isEditingGroupName = true
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                    .padding(.vertical, 4)
                    
                    // Group creation info
                    if let createdBy = conversation.createdByName,
                       let createdAt = conversation.createdAt {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Created by \(createdBy)")
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Text(formatDate(createdAt))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                } header: {
                    Text("Group Information")
                }
                
                // Members section
                Section {
                    ForEach(Array(zip(conversation.participantIds, conversation.participantNames)), id: \.0) { userId, userName in
                        MemberRow(
                            userId: userId,
                            userName: userName,
                            isOnline: onlineMembers.contains(userId),
                            isAdmin: conversation.groupAdmins.contains(userId),
                            isCurrentUser: userId == authViewModel.currentUser?.id,
                            modelContext: modelContext
                        )
                    }
                    
                    // Add members button
                    Button(action: {
                        showingAddMembers = true
                    }) {
                        HStack {
                            Image(systemName: "person.badge.plus")
                                .font(.body)
                                .foregroundColor(.blue)
                            
                            Text("Add Members")
                                .foregroundColor(.blue)
                        }
                    }
                } header: {
                    HStack {
                        Text("Members")
                        Spacer()
                        Text("\(conversation.participantIds.count) members • \(onlineMembers.count) online")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                
                // Options section
                Section {
                    // Mute notifications
                    Button(action: {
                        // TODO: Implement mute functionality
                        print("Mute notifications tapped")
                    }) {
                        HStack {
                            Image(systemName: "bell.slash.fill")
                                .foregroundColor(.orange)
                            Text("Mute Notifications")
                        }
                    }
                    
                    // View all read receipts
                    NavigationLink(destination: GroupReadReceiptsView(conversation: conversation)) {
                        HStack {
                            Image(systemName: "eye.fill")
                                .foregroundColor(.blue)
                            Text("View Read Receipts")
                        }
                    }
                    
                    // Leave group (delete-style action at bottom)
                    Button(action: {
                        leaveGroup()
                    }) {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .foregroundColor(.red)
                            Text("Leave Group")
                                .foregroundColor(.red)
                        }
                    }
                } header: {
                    Text("Options")
                }
            }
            .navigationTitle("Group Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAddMembers) {
                AddMembersView(conversation: conversation)
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func saveGroupName() {
        guard !newGroupName.isEmpty else {
            isEditingGroupName = false
            return
        }
        
        conversation.groupName = newGroupName
        conversation.lastUpdatedBy = authViewModel.currentUser?.id
        conversation.lastUpdatedAt = Date()
        
        do {
            try modelContext.save()
            
            // Send update via WebSocket
            webSocketService.sendGroupUpdate(
                conversationId: conversation.id,
                groupName: newGroupName,
                updatedBy: authViewModel.currentUser?.id ?? "",
                updatedByName: authViewModel.currentUser?.name ?? "Unknown",
                participantIds: conversation.participantIds
            )
            
            isEditingGroupName = false
        } catch {
            errorMessage = "Failed to update group name"
            showingError = true
        }
    }
    
    private func leaveGroup() {
        guard let currentUserId = authViewModel.currentUser?.id else { return }
        
        // Remove current user from participants
        conversation.participantIds.removeAll { $0 == currentUserId }
        conversation.participantNames.removeAll { $0 == authViewModel.currentUser?.name }
        
        // If user was admin, remove from admins
        conversation.groupAdmins.removeAll { $0 == currentUserId }
        
        do {
            try modelContext.save()
            
            // Send leave notification
            webSocketService.sendGroupMemberLeft(
                conversationId: conversation.id,
                userId: currentUserId,
                userName: authViewModel.currentUser?.name ?? "Unknown",
                remainingMemberIds: conversation.participantIds
            )
            
            dismiss()
        } catch {
            errorMessage = "Failed to leave group"
            showingError = true
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Member Row View

struct MemberRow: View {
    let userId: String
    let userName: String
    let isOnline: Bool
    let isAdmin: Bool
    let isCurrentUser: Bool
    let modelContext: ModelContext
    
    // Get display name (nickname if set, otherwise real name)
    private var displayName: String {
        UserCustomizationManager.shared.getNickname(
            for: userId,
            realName: userName,
            modelContext: modelContext
        )
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar with online indicator
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Text(displayName.prefix(1).uppercased())
                            .font(.headline)
                            .foregroundColor(.blue)
                    )
                
                if isOnline {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color(.systemBackground), lineWidth: 2)
                        )
                }
            }
            
            // User info
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(displayName)
                        .font(.body)
                    
                    if isCurrentUser {
                        Text("(You)")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    
                    if isAdmin {
                        Image(systemName: "star.fill")
                            .font(.caption)
                            .foregroundColor(.yellow)
                    }
                }
                
                // Show real name if nickname is set
                if displayName != userName {
                    Text(userName)
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                
                Text(isOnline ? "Active now" : "Offline")
                    .font(.caption)
                    .foregroundColor(isOnline ? .green : .gray)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Add Members View

struct AddMembersView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var webSocketService: WebSocketService
    
    let conversation: ConversationData
    @State private var searchText = ""
    @State private var selectedUsers: Set<ContactData> = []
    @Query(sort: \ContactData.name) private var allContacts: [ContactData]
    
    // Filter out existing members
    private var availableContacts: [ContactData] {
        allContacts.filter { contact in
            !conversation.participantIds.contains(contact.id) &&
            (searchText.isEmpty || 
             contact.name.localizedCaseInsensitiveContains(searchText) ||
             contact.email.localizedCaseInsensitiveContains(searchText))
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search users to add...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding()
                
                // Selected users
                if !selectedUsers.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(Array(selectedUsers), id: \.id) { user in
                                UserChip(user: user) {
                                    selectedUsers.remove(user)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Available contacts
                List {
                    ForEach(availableContacts) { contact in
                        ContactRow(
                            contact: contact,
                            isSelected: selectedUsers.contains(contact),
                            onTap: {
                                if selectedUsers.contains(contact) {
                                    selectedUsers.remove(contact)
                                } else {
                                    selectedUsers.insert(contact)
                                }
                            }
                        )
                    }
                }
                .listStyle(.plain)
            }
            .navigationTitle("Add Members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Add") {
                        addMembers()
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedUsers.isEmpty)
                }
            }
        }
    }
    
    private func addMembers() {
        let newUserIds = selectedUsers.map { $0.id }
        let newUserNames = selectedUsers.map { $0.name }
        
        // Add to conversation
        conversation.participantIds.append(contentsOf: newUserIds)
        conversation.participantNames.append(contentsOf: newUserNames)
        conversation.lastUpdatedBy = authViewModel.currentUser?.id
        conversation.lastUpdatedAt = Date()
        
        do {
            try modelContext.save()
            
            // Send update via WebSocket
            webSocketService.sendGroupMembersAdded(
                conversationId: conversation.id,
                newMemberIds: newUserIds,
                newMemberNames: newUserNames,
                addedBy: authViewModel.currentUser?.id ?? "",
                addedByName: authViewModel.currentUser?.name ?? "Unknown",
                allMemberIds: conversation.participantIds
            )
            
            dismiss()
        } catch {
            print("Error adding members: \(error)")
        }
    }
}

#Preview {
    GroupDetailsView(conversation: ConversationData(
        participantIds: ["1", "2", "3"],
        participantNames: ["Alice", "Bob", "Charlie"],
        isGroupChat: true,
        groupName: "Test Group"
    ))
    .environmentObject(AuthViewModel())
    .environmentObject(WebSocketService())
}
