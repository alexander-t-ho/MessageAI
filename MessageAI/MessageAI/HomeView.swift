//
//  HomeView.swift
//  MessageAI
//
//  Main home screen after login
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @State private var showDatabaseTest = false
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 30) {
                    Spacer()
                    
                    // Welcome message
                    VStack(spacing: 15) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.green)
                        
                        Text("Welcome!")
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        
                        if let user = authViewModel.currentUser {
                            Text("Hello, \(user.name)! 👋")
                                .font(.title2)
                                .foregroundColor(.gray)
                            
                            VStack(spacing: 5) {
                                Text("Email: \(user.email)")
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                Text("User ID: \(user.id)")
                                    .font(.caption)
                                    .foregroundColor(.gray.opacity(0.7))
                            }
                            .padding(.top, 10)
                        }
                    }
                    
                    // Phase 1 Complete badge
                    VStack(spacing: 10) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.yellow)
                        
                        Text("🎉 Phase 1 Complete! 🎉")
                            .font(.headline)
                        
                        Text("Authentication Working!")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Color.white)
                    .cornerRadius(15)
                    .shadow(radius: 5)
                    .padding(.horizontal, 40)
                    
                    // Info card
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.blue)
                            Text("What's Next?")
                                .font(.headline)
                        }
                        
                        Text("✅ User registration")
                        Text("✅ User login")
                        Text("✅ Session management")
                        Text("🔨 Phase 2: Local Data Persistence")
                        Text("⏳ Phase 3: Messaging")
                        
                    }
                    .font(.subheadline)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.9))
                    .cornerRadius(15)
                    .shadow(radius: 5)
                    .padding(.horizontal, 40)
                    
                    // Database Test Button
                    Button(action: {
                        showDatabaseTest = true
                    }) {
                        HStack {
                            Image(systemName: "cylinder.fill")
                            Text("Test Database")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.purple)
                        .cornerRadius(10)
                        .shadow(radius: 3)
                    }
                    .padding(.horizontal, 40)
                    
                    Spacer()
                    
                    // Logout button
                    Button(action: {
                        authViewModel.logout()
                    }) {
                        HStack {
                            Image(systemName: "arrow.right.square")
                            Text("Logout")
                        }
                        .font(.headline)
                        .foregroundColor(.red)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.white)
                        .cornerRadius(10)
                        .shadow(radius: 3)
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("MessageAI")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showDatabaseTest) {
                DatabaseTestView()
            }
        }
    }
}

#Preview {
    HomeView()
        .environmentObject(AuthViewModel())
}

