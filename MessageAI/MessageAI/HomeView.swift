//
//  HomeView.swift
//  MessageAI
//
//  Main home screen with tab navigation
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Messages Tab
            ConversationListView()
                .tabItem {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                    Text("Messages")
                }
                .tag(0)
            
            // Profile Tab
            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
                }
                .tag(1)
        }
    }
}

// MARK: - Profile View

struct ProfileView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showDatabaseTest = false
    
    var body: some View {
        NavigationStack {
            List {
                // User Info Section
                Section {
                    if let user = authViewModel.currentUser {
                        HStack {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 60, height: 60)
                                .overlay(
                                    Text(user.name.prefix(1).uppercased())
                                        .font(.title)
                                        .foregroundColor(.white)
                                )
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(user.name)
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                
                                Text(user.email)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            .padding(.leading, 8)
                        }
                        .padding(.vertical, 8)
                    }
                } header: {
                    Text("Account")
                }
                
                // Phase Progress Section
                Section {
                    ProgressRow(icon: "checkmark.circle.fill", text: "Authentication", status: .complete, color: .green)
                    ProgressRow(icon: "checkmark.circle.fill", text: "Local Database", status: .complete, color: .green)
                    ProgressRow(icon: "checkmark.circle.fill", text: "Draft Messages", status: .complete, color: .green)
                    ProgressRow(icon: "checkmark.circle.fill", text: "Real-Time Messaging", status: .complete, color: .green)
                    ProgressRow(icon: "checkmark.circle.fill", text: "Read Receipts & Timestamps", status: .complete, color: .green)
                    ProgressRow(icon: "checkmark.circle.fill", text: "Online/Offline Presence", status: .complete, color: .green)
                    ProgressRow(icon: "checkmark.circle.fill", text: "Typing Indicators", status: .complete, color: .green)
                    ProgressRow(icon: "checkmark.circle.fill", text: "Group Chat", status: .complete, color: .green)
                    ProgressRow(icon: "checkmark.circle.fill", text: "Message Editing", status: .complete, color: .green)
                    ProgressRow(icon: "hammer.circle.fill", text: "Push Notifications", status: .inProgress, color: .blue)
                } header: {
                    Text("Development Progress")
                }
                
                // Developer Tools Section
                Section {
                    Button(action: { showDatabaseTest = true }) {
                        HStack {
                            Image(systemName: "cylinder.fill")
                                .foregroundColor(.purple)
                            Text("Database Test")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                } header: {
                    Text("Developer Tools")
                }
                
                // Logout Section
                Section {
                    Button(action: { authViewModel.logout() }) {
                        HStack {
                            Image(systemName: "arrow.right.square")
                            Text("Logout")
                        }
                        .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Profile")
            .sheet(isPresented: $showDatabaseTest) {
                DatabaseTestView()
            }
        }
    }
}

// MARK: - Progress Row

struct ProgressRow: View {
    let icon: String
    let text: String
    let status: Status
    let color: Color
    
    enum Status {
        case complete
        case inProgress
        case pending
    }
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.title3)
            
            Text(text)
            
            Spacer()
            
            switch status {
            case .complete:
                Text("Complete")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.green)
            case .inProgress:
                Text("In Progress")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.blue)
            case .pending:
                Text("Pending")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
}

