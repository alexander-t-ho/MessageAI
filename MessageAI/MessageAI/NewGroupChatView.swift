//
//  NewGroupChatView.swift
//  MessageAI
//
//  Create new group chats with multi-user search
//

import SwiftUI
import SwiftData

struct NewGroupChatView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authViewModel: AuthViewModel
    @EnvironmentObject var webSocketService: WebSocketService
    
    @State private var searchText = ""
    @State private var groupName = ""
    @State private var selectedUsers: Set<ContactData> = []
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var isCreatingGroup = false
    
    // All contacts available for selection
    @Query(sort: \ContactData.name) private var allContacts: [ContactData]
    
    // Filtered contacts based on search
    private var searchResults: [ContactData] {
        if searchText.isEmpty {
            return allContacts
        } else {
            return allContacts.filter { contact in
                contact.name.localizedCaseInsensitiveContains(searchText) ||
                contact.email.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Group name field
                VStack(alignment: .leading, spacing: 8) {
                    Text("Group Name (Optional)")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                    
                    TextField("Enter group name...", text: $groupName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                }
                .padding(.top)
                
                // Selected users chips
                if !selectedUsers.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(Array(selectedUsers), id: \.id) { user in
                                UserChip(user: user) {
                                    selectedUsers.remove(user)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 8)
                }
                
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    
                    TextField("Search users to add...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .autocapitalization(.none)
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                // User list
                List {
                    ForEach(searchResults) { contact in
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
            .navigationTitle("New Group Chat")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createGroupChat()
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedUsers.count < 2 || isCreatingGroup)
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .overlay {
                if isCreatingGroup {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .overlay {
                            ProgressView("Creating group...")
                                .padding()
                                .background(Color(.systemBackground))
                                .cornerRadius(10)
                                .shadow(radius: 5)
                        }
                }
            }
        }
    }
    
    private func createGroupChat() {
        guard let currentUser = authViewModel.currentUser else {
            errorMessage = "User not authenticated"
            showingError = true
            return
        }
        
        guard selectedUsers.count >= 2 else {
            errorMessage = "Please select at least 2 users for a group chat"
            showingError = true
            return
        }
        
        isCreatingGroup = true
        
        // Prepare participant data
        var participantIds = selectedUsers.map { $0.id }
        var participantNames = selectedUsers.map { $0.name }
        
        // Add current user to participants
        participantIds.append(currentUser.id)
        participantNames.append(currentUser.displayName)
        
        // Create conversation ID (deterministic for group)
        let conversationId = UUID().uuidString
        
        // Create group name if not provided
        let finalGroupName = groupName.isEmpty
            ? participantNames.prefix(3).joined(separator: ", ") + (participantNames.count > 3 ? "..." : "")
            : groupName
        
        // Create new conversation
        let newConversation = ConversationData(
            id: conversationId,
            participantIds: participantIds,
            participantNames: participantNames,
            isGroupChat: true,
            groupName: finalGroupName,
            lastMessage: nil,
            lastMessageTime: Date(),
            unreadCount: 0,
            createdBy: currentUser.id,
            createdByName: currentUser.displayName,
            createdAt: Date(),
            groupAdmins: [currentUser.id] // Creator is admin by default
        )
        
        // Save to database
        modelContext.insert(newConversation)
        
        do {
            try modelContext.save()
            
            // Send group creation notification via WebSocket
            webSocketService.sendGroupCreated(
                conversationId: conversationId,
                groupName: finalGroupName,
                participantIds: participantIds,
                participantNames: participantNames,
                createdBy: currentUser.id,
                createdByName: currentUser.displayName
            )
            
            isCreatingGroup = false
            dismiss()
        } catch {
            isCreatingGroup = false
            errorMessage = "Failed to create group: \(error.localizedDescription)"
            showingError = true
        }
    }
}

// MARK: - Supporting Views

struct UserChip: View {
    let user: ContactData
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 4) {
            Text(user.name)
                .font(.caption)
                .lineLimit(1)
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(15)
    }
}

struct ContactRow: View {
    let contact: ContactData
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                // Avatar
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(contact.name.prefix(1).uppercased())
                            .font(.headline)
                            .foregroundColor(.blue)
                    )
                
                // Contact info
                VStack(alignment: .leading, spacing: 2) {
                    Text(contact.name)
                        .font(.body)
                        .foregroundColor(.primary)
                    
                    Text(contact.email)
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // Selection indicator
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                } else {
                    Image(systemName: "circle")
                        .font(.title2)
                        .foregroundColor(.gray.opacity(0.4))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    NewGroupChatView()
        .environmentObject(AuthViewModel())
        .environmentObject(WebSocketService())
}
