//
//  SettingsView.swift
//  MessageAI
//
//  Created on 10/20/2025.
//

import SwiftUI
import PhotosUI

struct SettingsView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var selectedImage: PhotosPickerItem?
    @State private var isUploading = false
    @State private var showLogoutAlert = false
    
    var body: some View {
        NavigationView {
            List {
                Section {
                    HStack {
                        Spacer()
                        
                        VStack(spacing: 16) {
                            // Profile Picture
                            if let profileUrl = authViewModel.currentUser?.profilePictureUrl {
                                AsyncImage(url: URL(string: profileUrl)) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                } placeholder: {
                                    Circle()
                                        .fill(Color.blue)
                                        .overlay(
                                            Text(authViewModel.currentUser?.initials ?? "")
                                                .foregroundColor(.white)
                                                .font(.largeTitle)
                                                .fontWeight(.bold)
                                        )
                                }
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color.blue)
                                    .frame(width: 120, height: 120)
                                    .overlay(
                                        Text(authViewModel.currentUser?.initials ?? "")
                                            .foregroundColor(.white)
                                            .font(.largeTitle)
                                            .fontWeight(.bold)
                                    )
                            }
                            
                            PhotosPicker(selection: $selectedImage, matching: .images) {
                                if isUploading {
                                    ProgressView()
                                } else {
                                    Text("Change Photo")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                }
                            }
                            .onChange(of: selectedImage) { _, newValue in
                                if newValue != nil {
                                    uploadProfilePicture()
                                }
                            }
                            .disabled(isUploading)
                            
                            Text(authViewModel.currentUser?.displayName ?? "")
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text(authViewModel.currentUser?.email ?? "")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                
                Section("Account") {
                    HStack {
                        Text("User ID")
                        Spacer()
                        Text(authViewModel.currentUser?.id ?? "")
                            .foregroundColor(.gray)
                            .font(.caption)
                    }
                    
                    HStack {
                        Text("Status")
                        Spacer()
                        if authViewModel.currentUser?.isOnline ?? false {
                            Label("Online", systemImage: "circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)
                        } else {
                            Label("Offline", systemImage: "circle.fill")
                                .foregroundColor(.gray)
                                .font(.caption)
                        }
                    }
                }
                
                Section {
                    Button(role: .destructive, action: {
                        showLogoutAlert = true
                    }) {
                        HStack {
                            Spacer()
                            Text("Logout")
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Settings")
            .alert("Logout", isPresented: $showLogoutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Logout", role: .destructive) {
                    authViewModel.logout()
                }
            } message: {
                Text("Are you sure you want to logout?")
            }
        }
    }
    
    private func uploadProfilePicture() {
        Task {
            if let selectedImage = selectedImage,
               let data = try? await selectedImage.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                
                isUploading = true
                
                let storageService = StorageService()
                if let userId = authViewModel.currentUser?.id,
                   let imageUrl = try? await storageService.uploadProfilePicture(uiImage, userId: userId) {
                    await authViewModel.updateProfilePicture(url: imageUrl)
                }
                
                isUploading = false
            }
            
            self.selectedImage = nil
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AuthViewModel())
}

