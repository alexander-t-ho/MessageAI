# Group Chat Read Receipt Testing Guide

## 🔍 **Issue**: Group chat read receipts not showing

### **What Works:**
- ✅ Direct message read receipts work perfectly
- ✅ Messages send and show "delivered" status
- ✅ Group chat messages are received by all participants

### **What Doesn't Work:**
- ❌ Sender doesn't see "Read by" with profile icons when recipients open the chat

---

## 📊 **How It Should Work**

### **Direct Messages (Working)**
1. User A sends message to User B
2. User B opens chat → `markVisibleIncomingAsRead()` is called
3. Client sends `markRead` action to Lambda
4. Lambda updates message status to "read"
5. Lambda sends `messageStatus` back to User A
6. User A's chat updates to show "Read" with timestamp
7. **Result**: Blue checkmark appears under User A's message

### **Group Chats (Should Work But Doesn't)**
1. User A sends message to Group (Users B, C, D)
2. User B opens chat → `markVisibleIncomingAsRead()` is called with `isGroupChat: true`
3. Client sends `markRead` action to Lambda with `isGroupChat: true`
4. Lambda:
   - Updates User B's per-recipient record to "read"
   - Queries ALL per-recipient records for the message
   - Aggregates: `readByUserIds: [B]`, `readByUserNames: ["User B"]`
   - Sends `messageStatus` to User A (sender) with aggregated data
5. User A's chat updates: `msg.readByUserIds = [B]`, `msg.readByUserNames = ["User B"]`
6. **UI should show**: "Read by" + User B's profile icon
7. User C opens chat → repeat process
8. **UI should show**: "Read by" + User B and C profile icons (overlapping)

---

## 🔍 **Testing Steps**

### **Step 1: Test Direct Messages (Baseline)**
1. Open direct message between User A and User B
2. User A sends "Test direct message"
3. User B opens the chat
4. **Expected**: User A sees "Read" with timestamp and blue checkmark
5. **Check Console**: Look for `📬 handleStatusUpdate` logs

### **Step 2: Test Group Messages**
1. Create group with Users A, B, C
2. User A sends "Test group message"
3. User B opens the chat
4. **Expected**: User A sees "Read by" + User B's profile icon
5. **Check Console**: 
   - User B: `📤 Sending markRead` with `isGroupChat: true`
   - User A: `📬 handleStatusUpdate` with `readByUserIds` and `readByUserNames`

### **Step 3: Check Lambda Logs**
```bash
aws logs tail /aws/lambda/websocket-markRead_AlexHo --since 5m --region us-east-1 --follow
```

Look for:
```
📖 Marking X messages as read
   Reader: User B
   Conversation: [conversation-id]
   Is Group Chat: true
📊 Aggregated readers for [message-id]:
   User IDs: [user-b-id]
   Names: User B
📤 Sending read status payload for message [message-id]:
   isGroupChat: true
   readByUserIds: ["user-b-id"]
   readByUserNames: ["User B"]
```

---

## 🐛 **Debugging Checklist**

### **Client Side (iOS)**

1. **Is markRead being called?**
   - Look for: `📤 Sending markRead for X messages`
   - Should see: `👥 Group chat - tracking read by [name]`

2. **Is the payload correct?**
   - Should include: `"isGroupChat": true`
   - Should include: `"readerName": "[actual name]"`

3. **Is the response received?**
   - Look for: `📥 Received WebSocket message`
   - Type should be: `messageStatus`
   - Should include: `readByUserIds`, `readByUserNames`

4. **Is the UI updated?**
   - Look for: `📬 handleStatusUpdate`
   - Should see: `👥 Read by user IDs: ...`
   - Should see: `👥 Read by: ...`

### **Server Side (Lambda)**

1. **Is markRead Lambda being invoked?**
   - Check CloudWatch logs
   - Should see: `📖 markRead Event received`

2. **Is it finding the conversation?**
   - Should see: `📋 Loaded X participant names from conversation`

3. **Is it aggregating correctly?**
   - Should see: `📊 Aggregated readers for [message-id]`
   - Should list user IDs and names

4. **Is it sending the response?**
   - Should see: `📤 Sending read status payload`
   - Should see: `✅ Sent read status to sender connection`

---

## 🔧 **Common Issues & Fixes**

### **Issue 1: Lambda Not Being Called**
**Symptom**: No Lambda logs when user opens chat
**Cause**: `markVisibleIncomingAsRead()` not being triggered
**Fix**: Ensure user scrolls to bottom of chat after opening

### **Issue 2: Lambda Crashes**
**Symptom**: "Internal server error" in client console
**Cause**: Lambda runtime error
**Fix**: Check CloudWatch logs for error details

### **Issue 3: Empty readByUserNames**
**Symptom**: readByUserNames is `[]` or has wrong names
**Cause**: Conversation table not being queried or missing participant names
**Fix**: Ensure Conversations table has correct `participantNames` array

### **Issue 4: Client Not Updating UI**
**Symptom**: Console shows correct data but UI doesn't update
**Cause**: Message not found in local database or refresh not triggered
**Fix**: Check that `msg.id == payload.messageId` matches correctly

---

## 📝 **Quick Test Commands**

### **Test 1: Verify Lambda is Deployed**
```bash
aws lambda get-function --function-name websocket-markRead_AlexHo --region us-east-1 --query 'Configuration.LastUpdateStatus'
```
Should return: `"Successful"`

### **Test 2: Check Lambda Handler**
```bash
aws lambda get-function-configuration --function-name websocket-markRead_AlexHo --region us-east-1 --query 'Handler'
```
Should return: `"markRead.handler"`

### **Test 3: Verify IAM Permissions**
```bash
aws iam get-role-policy --role-name MessageAI-WebSocket-Role_AlexHo --policy-name DynamoDBMarkReadAccess_AlexHo --region us-east-1
```
Should include: `Conversations_AlexHo` table in Resources

---

## 🎯 **Expected Console Output (Working)**

### **User B (Reader)**
```
👁️ Now viewing conversation: [id]
📤 markVisibleIncomingAsRead sending for 1 messages: ids=[message-id] isAtBottom=true
   👥 Group chat - tracking read by User B
```

### **User A (Sender)**
```
📥 Received WebSocket message: ["type": messageStatus, "data": { ... }]
📬 Raw status data received: [..., "readByUserIds": ["user-b-id"], "readByUserNames": ["User B"]]
📬 Status update decoded: id=[message-id] status=read readAt=[timestamp]
📬 handleStatusUpdate: messageId=[id] status=read readAt=[timestamp]
   Found message to mark as read: [id]
   ✅ Set readAt from server=[timestamp] for message [id]
   👥 Read by user IDs: user-b-id
   👥 Read by: User B
   👥 Read timestamps stored for 1 users
   ✅ Saved status update to database
```

---

## ✅ **Success Criteria**

- [ ] User B opens group chat
- [ ] Lambda logs show aggregation
- [ ] User A receives messageStatus with readByUserIds
- [ ] User A's console shows "👥 Read by: User B"
- [ ] User A's UI shows "Read by" with User B's profile icon
- [ ] User C opens chat
- [ ] User A's UI shows BOTH profile icons (overlapping)

---

**Next Steps**: Test in app and capture console output to see where the flow breaks.

