# Group Chat Delete & Read Receipt Fixes - October 24, 2025

## 🐛 Issues Fixed

### 1. **Delete Message Not Broadcasting to All Group Members**
- **Problem**: When a message was deleted in a group chat, only one recipient saw the deletion
- **Root Cause**: deleteMessage Lambda only notified single `recipientId`, not all group members
- **Fix**: Updated to broadcast deletion to all `recipientIds` for group chats

### 2. **Read Receipts Not Working Properly**
- **Problem**: Read receipts were not updating in real-time or at all
- **Root Cause**: The markRead Lambda wasn't properly broadcasting to all group participants
- **Fix**: Fixed markRead Lambda to notify ALL group members (previously fixed)

---

## 📝 Changes Made

### Frontend (iOS App)

#### ChatView.swift - Delete Message:
```swift
// Now sends all recipient IDs for group chats
webSocketService.sendDeleteMessage(
    messageId: message.id,
    conversationId: conversation.id,
    senderId: currentUserId,
    recipientId: recipientId,
    recipientIds: conversation.isGroupChat ? conversation.participantIds.filter { $0 != currentUserId } : nil,
    isGroupChat: conversation.isGroupChat
)
```

#### WebSocketService.swift - Delete Message:
```swift
func sendDeleteMessage(
    messageId: String,
    conversationId: String,
    senderId: String,
    recipientId: String,
    recipientIds: [String]? = nil,
    isGroupChat: Bool = false
) {
    // Now includes recipientIds for group chats
}
```

### Backend (AWS Lambda)

#### deleteMessage.js Lambda:
```javascript
// For group chats, use recipientIds; for direct messages, use recipientId
const allRecipientIds = isGroupChat && recipientIds ? recipientIds : [recipientId];

// Notify all recipients
for (const recipId of allRecipientIds) {
    // Find this recipient's connections
    const recipientConnections = await docClient.send(new QueryCommand({
        TableName: CONNECTIONS_TABLE,
        IndexName: "userId-index",
        KeyConditionExpression: "userId = :u",
        ExpressionAttributeValues: { ":u": recipId }
    }));
    
    // Send delete notification to all connections
    for (const conn of recipientConnections.Items) {
        await api.send(new PostToConnectionCommand({
            ConnectionId: conn.connectionId,
            Data: Buffer.from(deleteData)
        }));
    }
}
```

---

## 🧪 Testing Instructions

### Test Delete in Group Chat:
1. Open group chat on 3+ devices
2. Send a message from Device A
3. Delete the message on Device A
4. ✅ ALL devices should see "This message was deleted"
5. ✅ Message should be grayed out for all members

### Test Read Receipts in Group Chat:
1. Send message in group chat from Device A
2. Open chat on Device B and Device C
3. ✅ Device A should see profile icons for both B and C
4. ✅ Device B should see profile icon for C
5. ✅ Device C should see profile icon for B

---

## 🚀 Deployment Status

### Lambda Functions Updated:
- **websocket-deleteMessage_AlexHo**: ✅ Updated
  - Runtime: Node.js 20.x
  - Handler: index.handler
  - Now broadcasts to all group members

- **websocket-markRead_AlexHo**: ✅ Previously fixed
  - Broadcasts read receipts to all group participants

### Frontend:
- **ChatView.swift**: ✅ Updated
- **WebSocketService.swift**: ✅ Updated
- **Changes**: Ready to commit

---

## 🔍 How It Works Now

### Delete Message Flow:
1. User deletes message in group chat
2. Frontend sends delete request with all `recipientIds`
3. Lambda receives request and loops through all recipients
4. Each recipient gets notified via their WebSocket connections
5. All devices update to show deleted message

### Read Receipt Flow:
1. User reads messages in group chat
2. markRead Lambda updates DynamoDB with reader info
3. Lambda broadcasts to ALL group participants
4. All members see who has read each message with profile icons

---

## 📊 Summary

The group chat functionality now properly handles:
- **Message Deletion**: All group members see deleted messages
- **Read Receipts**: All members see who has read messages
- **Real-time Updates**: Changes appear instantly via WebSocket
- **Complete Broadcasting**: Both delete and read actions notify all participants

Both critical issues have been fixed and deployed to AWS.
