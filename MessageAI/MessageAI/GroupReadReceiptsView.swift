//
//  GroupReadReceiptsView.swift
//  MessageAI
//
//  View all read receipts for group chat messages
//

import SwiftUI
import SwiftData

struct GroupReadReceiptsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject var authViewModel: AuthViewModel
    
    let conversation: ConversationData
    
    @Query private var allMessages: [MessageData]
    
    // Filter messages for this conversation sent by current user
    private var myMessages: [MessageData] {
        guard let currentUserId = authViewModel.currentUser?.id else { return [] }
        
        return allMessages
            .filter { $0.conversationId == conversation.id && $0.senderId == currentUserId && !$0.isDeleted }
            .sorted { $0.timestamp > $1.timestamp }  // Newest first
    }
    
    var body: some View {
        List {
            if myMessages.isEmpty {
                ContentUnavailableView(
                    "No Messages",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("You haven't sent any messages in this group yet.")
                )
            } else {
                ForEach(myMessages) { message in
                    MessageReadStatusRow(
                        message: message,
                        conversation: conversation
                    )
                }
            }
        }
        .navigationTitle("Read Receipts")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Message Read Status Row

struct MessageReadStatusRow: View {
    let message: MessageData
    let conversation: ConversationData
    
    private var readCount: Int {
        message.readByUserIds.count
    }
    
    private var totalRecipients: Int {
        // Total recipients is all participants minus the sender
        conversation.participantIds.count - 1
    }
    
    private var formattedTimestamp: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: message.timestamp)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Message preview
            Text(message.content)
                .font(.body)
                .lineLimit(2)
                .foregroundColor(.primary)
            
            // Timestamp
            Text(formattedTimestamp)
                .font(.caption)
                .foregroundColor(.gray)
            
            // Read status
            HStack(spacing: 8) {
                // Read count indicator
                Image(systemName: readCount == totalRecipients ? "checkmark.circle.fill" : "eye.fill")
                    .foregroundColor(readCount == totalRecipients ? .green : .blue)
                    .font(.caption)
                
                if readCount == 0 {
                    Text("Not read yet")
                        .font(.caption)
                        .foregroundColor(.gray)
                } else if readCount == totalRecipients {
                    Text("Read by all \(totalRecipients) members")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Text("Read by \(readCount) of \(totalRecipients) members")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            
            // Show who has read it with timestamps
            if !message.readByUserNames.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(message.readByUserNames, id: \.self) { name in
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .font(.caption2)
                                        .foregroundColor(.green)
                                    Text(name)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                // Show timestamp if available
                                if let userId = getUserId(for: name),
                                   let timestamp = message.readTimestamps[userId] {
                                    Text(formatReadTime(timestamp))
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(12)
                        }
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
    
    // Get userId from participant name
    private func getUserId(for name: String) -> String? {
        if let index = conversation.participantNames.firstIndex(of: name),
           index < conversation.participantIds.count {
            return conversation.participantIds[index]
        }
        return nil
    }
    
    // Format timestamp for read time
    private func formatReadTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}

#Preview {
    NavigationStack {
        GroupReadReceiptsView(conversation: ConversationData(
            participantIds: ["1", "2", "3"],
            participantNames: ["Alice", "Bob", "Charlie"],
            isGroupChat: true,
            groupName: "Test Group"
        ))
        .environmentObject(AuthViewModel())
    }
}

