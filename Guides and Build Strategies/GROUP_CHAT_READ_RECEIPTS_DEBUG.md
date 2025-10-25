# Group Chat Read Receipts - Debugging Guide

## 🐛 Issue Description

**Problem**: In group chats, when recipients mark messages as read, the sender doesn't see the "Read by" indicator with user profile icons.

**Expected**: Sender sees "Read by [Name1] [Name2]" with overlapping profile icons  
**Actual**: No read receipt shown even after recipients open the message

---

## 🔍 How Read Receipts Work

### Data Flow:

```
1. Recipient opens chat
   ↓
2. iOS app calls markVisibleIncomingAsRead()
   ↓
3. WebSocket sends markRead action:
   {
     action: "markRead",
     conversationId: "xxx",
     readerId: "recipient-user-id",
     readerName: "Recipient Name",
     messageIds: ["msg1", "msg2"],
     isGroupChat: true
   }
   ↓
4. markRead Lambda:
   a. Updates per-recipient record: {messageId}_${recipientId}
   b. Queries ALL per-recipient records for the original messageId
   c. Aggregates who has read it (readByUserIds, readByUserNames)
   d. Sends messageStatus WebSocket to SENDER
   ↓
5. Sender's iOS app receives:
   {
     type: "messageStatus",
     data: {
       messageId: "xxx",
       status: "read",
       readByUserIds: ["user1", "user2"],
       readByUserNames: ["Name1", "Name2"],
       readTimestamps: {...}
     }
   }
   ↓
6. iOS updates message.readByUserNames
   ↓
7. UI shows "Read by" with profile icons
```

---

## 🔧 Debugging Steps

### Step 1: Verify Recipients Are Marking as Read

**In Recipient's Console:**
```
Look for:
📖 Marking 3 incoming messages as read
📤 Sending markRead via WebSocket: {...}
✅ markRead sent successfully
```

**If missing:**
- Recipients aren't calling markVisibleIncomingAsRead()
- Check if recipients are scrolled to bottom
- Check if messages are marked as incoming (senderId != currentUserId)

### Step 2: Verify Backend is Receiving markRead

**Check Lambda logs:**
```bash
aws logs tail /aws/lambda/websocket-markRead_AlexHo --since 5m --region us-east-1 --follow
```

**Look for:**
```
[markRead] Marking 3 messages as read
   Reader: Recipient Name
   Conversation: xxx
   Is Group Chat: true
[markRead] Marking message {id} as read by Recipient Name
```

**If missing:**
- WebSocket route not working
- Check markRead route exists
- Verify Lambda permissions

### Step 3: Verify Aggregation is Working

**In Lambda logs, look for:**
```
[aggregated] Aggregated readers for {messageId}:
   Total records found: 6
   Records marked as read: 2
   User IDs: user1, user2
   Names: Name1, Name2
   Participant map had 3 entries
```

**Check each line:**
- `Total records found` should be (# participants) * (# messages)
- `Records marked as read` should match number of recipients who opened
- `Names` should have actual names, not user IDs

**If user IDs instead of names:**
- Conversation table doesn't have participantNames
- Need to populate participantNames when conversation is created

### Step 4: Verify Sender is Receiving WebSocket Message

**In Sender's Console:**
```
Look for:
📥 Received WebSocket message: [type: messageStatus, ...]
📊 Read receipt update: messageId=xxx
   readByUserIds: ["user1", "user2"]
   readByUserNames: ["Name1", "Name2"]
✅ Updated message read status
```

**If missing:**
- markRead Lambda not sending to sender's connection
- Sender's WebSocket might be disconnected
- Check sender has active connections in Connections table

### Step 5: Verify iOS is Updating the UI

**In Sender's Console:**
```
Look for:
✅ Updated message XXX read status
   readByUserNames: ["Name1", "Name2"]
```

**Check UI:**
- Does `message.readByUserNames` array have values?
- Is `isLastOutgoingRead` true for the message?
- Is the conversation marked as group chat?

---

## 🧪 Manual Testing

### Test Scenario:
1. **Sender** (Device A): Send message in 3-person group chat
2. **Recipient 1** (Device B): Open the group chat
3. **Recipient 2** (Device C): Open the group chat
4. **Sender** (Device A): Should see "Read by" with 2 profile icons

### What to Watch:

**On each device console:**
- Recipient 1: "📖 Marking messages as read"
- Recipient 2: "📖 Marking messages as read"
- Sender: "📥 Received WebSocket message: [type: messageStatus]"
- Sender: "👥 Read by: Name1, Name2"

### Common Issues:

#### Sender doesn't get update
**Cause**: Sender's WebSocket disconnected or stale connection  
**Fix**:
1. Check sender's connection in DynamoDB
2. Verify sender reconnects after disconnect
3. Test with sender on WiFi (not cellular)

#### Names show as UUIDs
**Cause**: Conversation doesn't have participantNames  
**Fix**:
1. Check conversation table: `participantNames` field
2. Update groupCreated Lambda to store names
3. Update groupUpdate Lambda to maintain names

#### No readers even though they opened
**Cause**: Per-recipient records not created or not marked as read  
**Fix**:
1. Check Messages table for `{messageId}_{recipientId}` records
2. Verify sendMessage Lambda creates per-recipient records
3. Check status field is being updated

---

## 🔧 Potential Fixes

### Fix 1: Ensure participantNames is Populated

**In groupCreated Lambda:**
```javascript
// When creating group conversation
const item = {
  conversationId: groupId,
  participantIds: [senderId, ...recipientIds],
  participantNames: [senderName, ...recipientNames], // ADD THIS
  // ...
};
```

### Fix 2: Add More Logging

**In ChatView.swift:**
```swift
// In handleMessageStatusUpdate
print("📊 Read receipt update: messageId=\(messageId)")
print("   readByUserIds: \(readByUserIds)")
print("   readByUserNames: \(readByUserNames)")
print("   Current message.readByUserNames: \(message.readByUserNames)")
```

### Fix 3: Force Refresh on Read Receipt

**In ChatView.swift:**
```swift
// After updating readByUserNames
DispatchQueue.main.async {
    // Force UI update
    objectWillChange.send()
}
```

### Fix 4: Debug Query in markRead Lambda

**Add this logging:**
```javascript
console.log(`[query] Looking for records with:`);
console.log(`  conversationId: ${conversationId}`);
console.log(`  originalMessageId: ${messageId}`);
console.log(`  Found ${allRecords.Items?.length} total records`);
allRecords.Items?.forEach((record, i) => {
  console.log(`  [${i}] recipientId=${record.recipientId}, status=${record.status}, readAt=${record.readAt}`);
});
```

---

## 🎯 Quick Diagnostic Commands

### Check if per-recipient records exist:
```bash
aws dynamodb query \
  --table-name Messages_AlexHo \
  --index-name conversationId-timestamp-index \
  --key-condition-expression "conversationId = :cid" \
  --expression-attribute-values '{":cid": {"S": "YOUR_CONVERSATION_ID"}}' \
  --region us-east-1
```

### Check conversation has participant names:
```bash
aws dynamodb get-item \
  --table-name Conversations_AlexHo \
  --key '{"conversationId": {"S": "YOUR_CONVERSATION_ID"}}' \
  --region us-east-1
```

### Watch markRead Lambda live:
```bash
aws logs tail /aws/lambda/websocket-markRead_AlexHo \
  --follow \
  --region us-east-1 \
  --format short
```

---

## ✅ Verification Checklist

Before concluding read receipts are broken:
- [ ] Recipients actually scrolled to bottom and saw messages
- [ ] Recipients' apps show "📖 Marking messages as read" in console
- [ ] markRead Lambda logs show messages being marked
- [ ] markRead Lambda logs show aggregated readers list
- [ ] Sender's console shows "📥 Received WebSocket message: messageStatus"
- [ ] Sender's console shows readByUserNames array with values
- [ ] Message object has `readByUserNames` populated
- [ ] Message is the last outgoing message (isLastOutgoingRead = true)
- [ ] Conversation is marked as group chat

---

## 🚀 Next Steps

1. **Enable verbose logging** in ChatView and markRead Lambda
2. **Test with 3 devices** to isolate the issue
3. **Watch all logs simultaneously** to see where the flow breaks
4. **Verify DynamoDB tables** have expected data
5. **Fix the broken link** in the chain

---

## 📝 Notes

- Read receipts work fine for 1-on-1 chats
- Issue is specific to group chats
- Backend aggregation logic looks correct
- Likely either:
  - Frontend not parsing response correctly
  - Backend not sending to all sender connections
  - Participant names not in conversation table

---

**Date**: October 25, 2025  
**Status**: Under investigation  
**Priority**: High - Critical feature

