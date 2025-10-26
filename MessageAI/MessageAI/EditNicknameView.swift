//
//  EditNicknameView.swift
//  Cloudy
//
//  Edit custom nickname for another user
//

import SwiftUI
import SwiftData

struct EditNicknameView: View {
    let userId: String
    let currentName: String
    @Binding var isPresented: Bool
    @State private var nickname: String = ""
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nickname", text: $nickname)
                        .autocapitalization(.words)
                } header: {
                    Text("Custom Nickname")
                } footer: {
                    Text("Set a custom name for this user. Only you will see it.")
                }
                
                if !nickname.isEmpty && nickname != currentName {
                    Section {
                        Button("Save Nickname") {
                            UserCustomizationManager.shared.setNickname(
                                for: userId,
                                nickname: nickname,
                                modelContext: modelContext
                            )
                            isPresented = false
                        }
                        .font(.headline)
                    }
                }
                
                if currentName != getUserRealName() {
                    Section {
                        Button("Reset to Real Name", role: .destructive) {
                            UserCustomizationManager.shared.setNickname(
                                for: userId,
                                nickname: nil,
                                modelContext: modelContext
                            )
                            isPresented = false
                        }
                    } footer: {
                        Text("Real name: \(getUserRealName())")
                    }
                }
            }
            .navigationTitle("Edit Nickname")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
            }
            .onAppear {
                nickname = currentName
            }
        }
    }
    
    private func getUserRealName() -> String {
        // For now, just return current name
        // In future, could fetch from Conversations table
        return currentName
    }
}

#Preview {
    EditNicknameView(
        userId: "test-user",
        currentName: "John Doe",
        isPresented: .constant(true)
    )
}

