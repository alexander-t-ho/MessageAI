//
//  ReadReceiptDetailsView.swift
//  Cloudy
//
//  Shows who has read a message in group chat
//

import SwiftUI

struct ReadReceiptDetailsView: View {
    let message: MessageData
    let conversation: ConversationData
    
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
            
            // Scrollable list of readers
            ScrollView {
                VStack(spacing: 0) {
                    // Who has read
                    ForEach(Array(zip(message.readByUserNames, message.readByUserNames.indices)), id: \.1) { name, index in
                        HStack {
                            // Checkmark
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.title3)
                            
                            // Name
                            Text(name)
                                .font(.body)
                            
                            Spacer()
                            
                            // Checkmark indicator
                            Image(systemName: "checkmark")
                                .font(.caption)
                                .foregroundColor(.green)
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
                        
                        ForEach(Array(unreadMembers.enumerated()), id: \.offset) { index, name in
                            HStack {
                                // Empty circle
                                Image(systemName: "circle")
                                    .foregroundColor(.gray)
                                    .font(.title3)
                                
                                // Name
                                Text(name)
                                    .font(.body)
                                    .foregroundColor(.secondary)
                                
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

