//
//  AuthenticationView.swift
//  MessageAI
//
//  Login and Signup UI
//

import SwiftUI

struct AuthenticationView: View {
    @EnvironmentObject var viewModel: AuthViewModel
    @State private var isSignUpMode = false
    
    // Form fields
    @State private var email = ""
    @State private var password = ""
    @State private var name = ""
    
    var body: some View {
        ZStack {
            // Background gradient - Sunset theme for Cloudy
            LinearGradient(
                colors: [
                    Color(red: 0.545, green: 0.361, blue: 0.965), // Purple
                    Color(red: 0.231, green: 0.51, blue: 0.965),  // Blue
                    Color(red: 0.976, green: 0.451, blue: 0.094)  // Orange
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Spacer()
                
                // Logo and title
                VStack(spacing: 16) {
                    // Cloud icon with gradient
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 100))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.white, .white.opacity(0.8)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .shadow(color: .black.opacity(0.1), radius: 10, y: 5)
                    
                    Text("Cloudy")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("Nothing like a message to brighten a cloudy day")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.9))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                        .padding(.bottom, 8)
                    
                    if !isSignUpMode {
                        Text("Welcome back!")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
                .padding(.bottom, 30)
                
                // Form card
                VStack(spacing: 20) {
                    // Toggle between Login and Signup
                    Picker("Mode", selection: $isSignUpMode) {
                        Text("Login").tag(false)
                        Text("Sign Up").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    
                    // Name field (only for signup)
                    if isSignUpMode {
                        TextField("Name", text: $name)
                            .textFieldStyle(RoundedTextFieldStyle())
                            .autocapitalization(.words)
                            .disabled(viewModel.isLoading)
                    }
                    
                    // Email field
                    TextField("Email", text: $email)
                        .textFieldStyle(RoundedTextFieldStyle())
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                        .disabled(viewModel.isLoading)
                    
                    // Password field
                    SecureField("Password", text: $password)
                        .textFieldStyle(RoundedTextFieldStyle())
                        .disabled(viewModel.isLoading)
                    
                    // Error message
                    if let errorMessage = viewModel.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Success message
                    if let successMessage = viewModel.successMessage {
                        Text(successMessage)
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding(.horizontal)
                            .multilineTextAlignment(.center)
                    }
                    
                    // Submit button
                    Button(action: handleSubmit) {
                        HStack {
                            if viewModel.isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            Text(isSignUpMode ? "Create Account" : "Login")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isFormValid ? Color.blue : Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .disabled(!isFormValid || viewModel.isLoading)
                    .padding(.horizontal)
                    
                    // Password requirements (only for signup)
                    if isSignUpMode {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Password must have:")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("• At least 8 characters")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("• 1 uppercase, 1 lowercase, 1 number, 1 symbol")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical, 30)
                .background(Color.white)
                .cornerRadius(20)
                .shadow(radius: 10)
                .padding(.horizontal, 30)
                
                Spacer()
                
                // Footer
                Text("MessageAI © 2025")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.bottom, 20)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var isFormValid: Bool {
        if isSignUpMode {
            return !email.isEmpty && !password.isEmpty && !name.isEmpty
        } else {
            return !email.isEmpty && !password.isEmpty
        }
    }
    
    // MARK: - Actions
    
    private func handleSubmit() {
        // Clear messages
        viewModel.errorMessage = nil
        viewModel.successMessage = nil
        
        Task {
            if isSignUpMode {
                await viewModel.signup(email: email, password: password, name: name)
                // If signup successful, switch to login mode
                if viewModel.successMessage != nil {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        isSignUpMode = false
                        password = "" // Clear password for security
                    }
                }
            } else {
                await viewModel.login(email: email, password: password)
            }
        }
    }
}

// MARK: - Custom Text Field Style

struct RoundedTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(10)
            .padding(.horizontal)
    }
}

// MARK: - Preview

#Preview {
    AuthenticationView()
        .environmentObject(AuthViewModel())
}

