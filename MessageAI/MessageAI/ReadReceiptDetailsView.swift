//
//  ReadReceiptDetailsView.swift
//  Cloudy
//
//  Shows who has read a message in group chat
//

import SwiftUI
import SwiftData

struct ReadReceiptDetailsView: View {
    let message: MessageData
    let conversation: ConversationData
    @Environment(\.modelContext) private var modelContext
    
    private var readCount: Int {
        message.readByUserNames.count
    }
    
    private var totalMembers: Int {
        conversation.participantIds.count - 1 // Exclude sender
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("Read By")
                    .font(.headline)
                Spacer()
                Text("\(readCount)/\(totalMembers)")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemGroupedBackground))
            .onAppear {
                print("📊 ReadReceiptDetailsView - readByUserNames: \(message.readByUserNames)")
                print("📊 ReadTimestamps dictionary: \(message.readTimestamps)")
                print("📊 Total timestamps: \(message.readTimestamps.count)")
            }
            
            // Scrollable list of readers
            ScrollView {
                VStack(spacing: 0) {
                    // Who has read
                    ForEach(Array(zip(message.readByUserNames, message.readByUserNames.indices)), id: \.1) { realName, index in
                        HStack {
                            // Checkmark
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title3)
                            
                            // Name (show nickname if set, otherwise real name)
                            VStack(alignment: .leading, spacing: 2) {
                                if let userId = getUserId(for: realName) {
                                    let displayName = UserCustomizationManager.shared.getNickname(
                                        for: userId,
                                        realName: realName,
                                        modelContext: modelContext
                                    )
                                    Text(displayName)
                                        .font(.body)
                                        .fontWeight(.medium)
                                    
                                    // Show real name in smaller text if nickname is set
                                    if displayName != realName {
                                        Text(realName)
                                            .font(.caption2)
                                            .foregroundColor(.gray)
                                    }
                                } else {
                                    Text(realName)
                                        .font(.body)
                                        .fontWeight(.medium)
                                }
                            }
                            
                            Spacer()
                            
                            // Timestamp when user read the message (NO checkmark, just time)
                            if let userId = getUserId(for: realName),
                               let timestamp = message.readTimestamps[userId] {
                                Text(formatTime(timestamp))
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                        
                        if index < message.readByUserNames.count - 1 {
                            Divider()
                        }
                    }
                    
                    // Who hasn't read (if we know the full member list)
                    let unreadMembers = getUnreadMembers()
                    if !unreadMembers.isEmpty {
                        Divider()
                            .padding(.vertical, 8)
                        
                        ForEach(Array(unreadMembers.enumerated()), id: \.offset) { index, realName in
                            HStack {
                                // Empty circle
                                Image(systemName: "circle")
                                    .foregroundColor(.gray)
                                    .font(.title3)
                                
                                // Name (show nickname if set)
                                VStack(alignment: .leading, spacing: 2) {
                                    if let userId = getUserId(for: realName) {
                                        let displayName = UserCustomizationManager.shared.getNickname(
                                            for: userId,
                                            realName: realName,
                                            modelContext: modelContext
                                        )
                                        Text(displayName)
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                        
                                        // Show real name if nickname is set
                                        if displayName != realName {
                                            Text(realName)
                                                .font(.caption2)
                                                .foregroundColor(.gray)
                                        }
                                    } else {
                                        Text(realName)
                                            .font(.body)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                Text("Not read")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                            
                            if index < unreadMembers.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
        .frame(height: 300)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private func getUserId(for name: String) -> String? {
        // Find user ID from conversation participants
        if let index = conversation.participantNames.firstIndex(of: name),
           index < conversation.participantIds.count {
            return conversation.participantIds[index]
        }
        return nil
    }
    
    private func getUnreadMembers() -> [String] {
        // Get list of members who haven't read
        let readNames = Set(message.readByUserNames)
        return conversation.participantNames.filter { name in
            !readNames.contains(name) && name != message.senderName
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

#Preview {
    let message = MessageData(
        conversationId: "test",
        senderId: "user1",
        senderName: "Sender",
        content: "Test message"
    )
    message.readByUserNames = ["John Doe", "Jane Smith"]
    
    let conversation = ConversationData(
        id: "test",
        participantIds: ["user1", "user2", "user3", "user4"],
        participantNames: ["Sender", "John Doe", "Jane Smith", "Mike Johnson"],
        isGroupChat: true
    )
    
    return ReadReceiptDetailsView(
        message: message,
        conversation: conversation
    )
    .padding()
}

