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
    @StateObject private var aiService = AITranslationService.shared
    @State private var showDatabaseTest = false
    @State private var showLanguagePreferences = false
    
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
                                
                                // Language preference indicator
                                HStack(spacing: 4) {
                                    Text(aiService.preferredLanguage.flag)
                                        .font(.caption)
                                    Text(aiService.preferredLanguage.displayName)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.leading, 8)
                        }
                        .padding(.vertical, 8)
                    }
                } header: {
                    Text("Account")
                }
                
                // Language & Translation Section
                Section {
                    Button(action: { showLanguagePreferences = true }) {
                        HStack {
                            Image(systemName: "globe")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Language & Translation")
                                    .foregroundColor(.primary)
                                
                                HStack(spacing: 4) {
                                    Text("\(aiService.preferredLanguage.flag) \(aiService.preferredLanguage.displayName)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    if aiService.autoTranslateEnabled {
                                        Text("• Auto-translate ON")
                                            .font(.caption)
                                            .foregroundColor(.green)
                                    }
                                }
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Quick Language Selector
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundColor(.orange)
                            .frame(width: 24)
                        
                        Text("Quick Switch")
                            .font(.callout)
                        
                        Spacer()
                        
                        Menu {
                            ForEach(getQuickLanguages(), id: \.self) { language in
                                Button(action: {
                                    aiService.preferredLanguage = language
                                    aiService.savePreferences()
                                }) {
                                    Label {
                                        Text(language.displayName)
                                    } icon: {
                                        Text(language.flag)
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                ForEach(getQuickLanguages().prefix(3), id: \.self) { lang in
                                    Text(lang.flag)
                                        .font(.caption)
                                }
                                Image(systemName: "chevron.down")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(.systemGray6))
                            .cornerRadius(6)
                        }
                    }
                    .padding(.vertical, 4)
                } header: {
                    Text("AI Features")
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
            .sheet(isPresented: $showLanguagePreferences) {
                LanguagePreferencesView()
            }
            .onAppear {
                // Set auth token for AI service when profile loads
                if let token = authViewModel.authToken {
                    AITranslationService.shared.setAuthToken(token)
                }
            }
        }
    }
    
    private func getQuickLanguages() -> [SupportedLanguage] {
        // Return the user's most commonly used languages
        // For now, return a default set of popular languages
        var languages = [SupportedLanguage.english, .spanish, .french, .chinese, .arabic, .japanese]
        
        // Make sure current language is included
        if !languages.contains(aiService.preferredLanguage) {
            languages.insert(aiService.preferredLanguage, at: 0)
        }
        
        return languages
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

