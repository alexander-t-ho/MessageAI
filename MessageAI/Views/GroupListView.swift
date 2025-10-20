//
//  GroupListView.swift
//  MessageAI
//
//  Created on 10/20/2025.
//

import SwiftUI

struct GroupListView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var viewModel: GroupViewModel
    @State private var showCreateGroup = false
    
    init() {
        _viewModel = StateObject(wrappedValue: GroupViewModel(currentUserId: ""))
    }
    
    var body: some View {
        NavigationStack {
            Group {
                if viewModel.isLoading {
                    ProgressView("Loading groups...")
                } else if viewModel.groups.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "person.3")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 100, height: 100)
                            .foregroundColor(.gray)
                        
                        Text("No groups yet")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Button(action: {
                            showCreateGroup = true
                        }) {
                            Label("Create Group", systemImage: "plus.circle.fill")
                                .font(.headline)
                                .foregroundColor(.white)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                    }
                } else {
                    List {
                        ForEach(viewModel.groups) { group in
                            NavigationLink(value: group.id) {
                                GroupRow(group: group)
                            }
                        }
                    }
                    .navigationDestination(for: String.self) { groupId in
                        GroupChatView(
                            groupId: groupId,
                            currentUserId: authViewModel.currentUser?.id ?? ""
                        )
                    }
                }
            }
            .navigationTitle("Groups")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showCreateGroup = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateGroup) {
                CreateGroupView(viewModel: viewModel)
            }
        }
        .onAppear {
            if let userId = authViewModel.currentUser?.id {
                // Update viewModel's currentUserId
                let newViewModel = GroupViewModel(currentUserId: userId)
                viewModel.startListeningToGroups()
            }
        }
        .onDisappear {
            viewModel.stopListening()
        }
    }
}

struct GroupRow: View {
    let group: Group
    
    var body: some View {
        HStack(spacing: 12) {
            // Group icon
            ZStack {
                Circle()
                    .fill(Color.green)
                    .frame(width: 50, height: 50)
                
                Image(systemName: "person.3.fill")
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(group.name)
                    .font(.headline)
                
                Text("\(group.participantCount) members")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                if let lastMessage = group.lastMessage {
                    Text(lastMessage)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            if let lastMessageTime = group.lastMessageTime {
                Text(lastMessageTime, style: .relative)
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 4)
    }
}

struct CreateGroupView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var userListViewModel = UserListViewModel()
    @ObservedObject var viewModel: GroupViewModel
    @EnvironmentObject var authViewModel: AuthViewModel
    
    @State private var groupName = ""
    @State private var selectedUserIds: Set<String> = []
    @State private var isCreating = false
    
    var body: some View {
        NavigationView {
            VStack {
                TextField("Group Name", text: $groupName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding()
                
                Text("Select Members")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal)
                
                List(userListViewModel.users) { user in
                    Button(action: {
                        if selectedUserIds.contains(user.id ?? "") {
                            selectedUserIds.remove(user.id ?? "")
                        } else {
                            selectedUserIds.insert(user.id ?? "")
                        }
                    }) {
                        HStack {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 40, height: 40)
                                .overlay(
                                    Text(user.initials)
                                        .foregroundColor(.white)
                                        .font(.subheadline)
                                )
                            
                            Text(user.displayName)
                            
                            Spacer()
                            
                            if selectedUserIds.contains(user.id ?? "") {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Create Group")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        createGroup()
                    }
                    .disabled(groupName.isEmpty || selectedUserIds.count < 2 || isCreating)
                }
            }
            .onAppear {
                if let userId = authViewModel.currentUser?.id {
                    userListViewModel.startListening(currentUserId: userId)
                }
            }
        }
    }
    
    private func createGroup() {
        isCreating = true
        
        var participantIds = Array(selectedUserIds)
        if let currentUserId = authViewModel.currentUser?.id {
            participantIds.append(currentUserId)
        }
        
        Task {
            if let groupId = await viewModel.createGroup(name: groupName, participantIds: participantIds) {
                await MainActor.run {
                    dismiss()
                }
            }
            isCreating = false
        }
    }
}

#Preview {
    GroupListView()
        .environmentObject(AuthViewModel())
}

