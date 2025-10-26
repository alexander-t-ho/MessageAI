//
//  UserProfileView.swift
//  Cloudy
//
//  View user profile with nickname and photo customization
//

import SwiftUI
import SwiftData
import PhotosUI

struct UserProfileView: View {
    let userId: String
    let username: String // Real username (permanent)
    let isOnline: Bool
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var customNickname: String = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingNicknameEdit = false
    
    private var hasCustomNickname: Bool {
        UserCustomizationManager.shared.getNickname(for: userId, realName: username, modelContext: modelContext) != username
    }
    
    private var displayNickname: String {
        UserCustomizationManager.shared.getNickname(for: userId, realName: username, modelContext: modelContext)
    }
    
    var body: some View {
        NavigationStack {
            List {
                // Profile Photo Section
                Section {
                    VStack(spacing: 16) {
                        // Profile photo
                        if let photoData = UserCustomizationManager.shared.getCustomPhoto(for: userId, modelContext: modelContext),
                           let uiImage = UIImage(data: photoData) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(isOnline ? Color.green : Color.gray, lineWidth: 3)
                                )
                        } else {
                            Circle()
                                .fill(Color.blue.opacity(0.2))
                                .frame(width: 120, height: 120)
                                .overlay(
                                    Text(username.prefix(1).uppercased())
                                        .font(.system(size: 50, weight: .semibold))
                                        .foregroundColor(.blue)
                                )
                                .overlay(
                                    Circle()
                                        .stroke(isOnline ? Color.green : Color.gray, lineWidth: 3)
                                )
                        }
                        
                        // Status indicator
                        HStack(spacing: 6) {
                            Circle()
                                .fill(isOnline ? Color.green : Color.gray)
                                .frame(width: 12, height: 12)
                            Text(isOnline ? "Online" : "Offline")
                                .font(.subheadline)
                                .foregroundColor(isOnline ? .green : .secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                } header: {
                    Text("Profile")
                }
                
                // Username Section (Permanent)
                Section {
                    HStack {
                        Text("Username")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("@\(username)")
                            .fontWeight(.medium)
                    }
                } header: {
                    Text("Account")
                } footer: {
                    Text("Username cannot be changed")
                }
                
                // Nickname Section (Customizable)
                Section {
                    HStack {
                        Text("Nickname")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(displayNickname)
                            .fontWeight(.medium)
                            .foregroundColor(hasCustomNickname ? .blue : .primary)
                    }
                    
                    Button("Edit Nickname") {
                        showingNicknameEdit = true
                    }
                    
                    if hasCustomNickname {
                        Button("Reset to Real Name", role: .destructive) {
                            UserCustomizationManager.shared.setNickname(
                                for: userId,
                                nickname: nil,
                                modelContext: modelContext
                            )
                        }
                    }
                } header: {
                    Text("Display Name")
                } footer: {
                    Text("Set a custom nickname for this user. Only you will see it.")
                }
                
                // Custom Photo Section
                Section {
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label("Upload Custom Photo", systemImage: "photo")
                    }
                    
                    if UserCustomizationManager.shared.getCustomPhoto(for: userId, modelContext: modelContext) != nil {
                        Button("Remove Custom Photo", role: .destructive) {
                            UserCustomizationManager.shared.setCustomPhoto(
                                for: userId,
                                photoData: nil,
                                modelContext: modelContext
                            )
                        }
                    }
                } header: {
                    Text("Customization")
                } footer: {
                    Text("Upload a custom photo for this user. Only you will see it.")
                }
            }
            .navigationTitle("User Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingNicknameEdit) {
                EditNicknameView(
                    userId: userId,
                    currentName: displayNickname,
                    isPresented: $showingNicknameEdit
                )
            }
            .onChange(of: selectedPhoto) { _, newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self) {
                        UserCustomizationManager.shared.setCustomPhoto(
                            for: userId,
                            photoData: data,
                            modelContext: modelContext
                        )
                    }
                }
            }
        }
    }
}

#Preview {
    UserProfileView(
        userId: "test-user",
        username: "john_doe",
        isOnline: true
    )
}

