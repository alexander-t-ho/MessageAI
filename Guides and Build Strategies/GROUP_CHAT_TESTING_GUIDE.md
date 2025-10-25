# Group Chat Testing Guide

## 🎯 Current Status

**Backend**: ✅ Fully Deployed
- `groupCreated` Lambda: Active
- `groupUpdate` Lambda: Active
- API Gateway routes: Configured
- Permissions: Granted

**Frontend**: ✅ Code Updated
- Enhanced logging enabled
- Group synchronization logic ready
- Presence detection fixed

## 🔧 Before Testing

### 1. **Rebuild All Devices**
You MUST rebuild the iOS app on all 3 devices to get the latest code:
- iPhone 17
- iPhone 16e  
- iPhone 17 Pro

**Steps:**
1. Open Xcode
2. Product → Clean Build Folder (⇧⌘K)
3. Product → Build (⌘B)
4. Deploy to each device

### 2. **Delete Old Group Chats**
On all 3 devices:
1. Swipe left on any existing "Group chat 1" or "Test User" conversations
2. Delete them
3. Start fresh

## 🧪 Test Plan

### Test 1: Create New Group Chat

**On iPhone 17:**
1. Tap the **compose button** (+)
2. In the "To:" field, type and add users:
   - Search "Test User 2" → Tap to add
   - Search "Test User" → Tap to add
3. You should see 2 chips in the To: field
4. Tap **"Create"**
5. **Check console logs** for:
   ```
   📤 Sending groupCreated notification:
      Group Name: ...
      Participants: 3
      Participant IDs: [...]
   ✅ groupCreated notification sent
   ```

**On iPhone 16e & iPhone 17 Pro:**
1. Within 1-2 seconds, you should see:
   - **New conversation appears** in Messages list
   - Shows group name: "Alex Test, Test User 2, Test User"
   - Blue group icon (not individual avatar)
   - Shows "3 members" when you tap into it

2. **Check console logs** for:
   ```
   📥 Received WebSocket message: [type: groupCreated]
   👥 Group created notification received
   📥 groupCreatedEvents count changed: 0 → 1
   📥 Processing group creation event...
   ✅ Group conversation created locally: [group name]
   ```

### Test 2: Send Message in Group

**On iPhone 17:**
1. Open the group chat
2. Type "Hello everyone!" and send
3. **Check logs** for:
   ```
   📤 Sending GROUP message to 2 recipients
   ```

**On iPhone 16e:**
1. Message should appear instantly
2. Shows sender name in the bubble or header
3. Can reply and everyone sees it

**On iPhone 17 Pro:**
1. Same - message appears instantly
2. Can interact with the group

### Test 3: Edit Group Name

**On Any Device:**
1. Open group chat
2. Tap the group name in header
3. Tap "Edit" → Change name to "My Test Group"
4. Tap "Save"

**On All Other Devices:**
1. Group name updates instantly
2. All see "My Test Group"

### Test 4: Check Member Status

**On Any Device:**
1. Open group chat
2. Tap group name → Opens Group Details
3. Should show:
   - All 3 members listed
   - "(You)" indicator for yourself
   - "Active now" for online members (green dot)
   - "Offline" for offline members
4. The current user (You) should show as "Active now"

## 🐛 Debugging

### If Group Doesn't Appear on Other Devices:

1. **Check iPhone 17 console logs:**
   - Look for "📤 Sending groupCreated notification"
   - If missing: WebSocket not connected
   - If present: Backend should be receiving it

2. **Check iPhone 16e/17 Pro console logs:**
   - Look for "📥 Received WebSocket message"
   - Look for "👥 Group created notification received"
   - If missing: Backend isn't broadcasting

3. **Check CloudWatch Logs:**
   ```bash
   cd /Users/alexho/MessageAI
   ./test-group-backend.sh
   ```
   - Shows if Lambda was called
   - Shows if there were any errors

4. **Check API Gateway Logs:**
   ```bash
   aws logs tail /aws/apigatewayv2/bnbr75tld0/production --since 5m --format short --region us-east-1
   ```

### If Messages Don't Appear:

1. **Check sender logs:**
   ```
   📤 Sending GROUP message to X recipients
   Participant IDs: [...]
   ```

2. **Check backend logs:**
   ```bash
   aws logs tail /aws/lambda/websocket-sendMessage_AlexHo --since 5m --region us-east-1
   ```
   - Should show: "Sending to X recipient(s)"
   - Should show: "Message sent to connection"

### If Presence Shows "Offline":

1. Check if WebSocket is connected (look for green icon in Messages list)
2. Check presence logs:
   ```
   👥 Presence update received: [userId] is now ONLINE
   ```
3. In GroupDetailsView, current user should always show "Active now" when connected

## 📊 Expected Console Output

### On Group Creator (iPhone 17):
```
📤 Sending groupCreated notification:
   Group Name: Alex Test, Test User 2, Test User
   Participants: 3
   Participant IDs: [id1, id2, id3]
✅ groupCreated notification sent
📤 Sending GROUP message to 2 recipients
```

### On Group Members (iPhone 16e, iPhone 17 Pro):
```
📥 Received WebSocket message: [type: groupCreated, data: ...]
👥 Group created notification received
📥 groupCreatedEvents count changed: 0 → 1
📥 Processing group creation event...
✅ Group conversation created locally: Alex Test, Test User 2, Test User
   With 0 messages and 0 unread
```

## ✅ Success Criteria

- [ ] All 3 devices show the SAME group chat
- [ ] Group name matches on all devices
- [ ] Member count shows "3 members"
- [ ] Messages from any member appear on all devices
- [ ] Everyone can reply and see each other's messages
- [ ] Green dot shows in header when members online
- [ ] Group Details shows all members with correct status
- [ ] Current user shows as "Active now" in Group Details
- [ ] Group name edits sync across all devices

## 🚀 Next Steps

After successful testing:
1. Test adding members to existing group
2. Test leaving a group
3. Implement per-user read receipts
4. Test with more than 3 members

---

**Last Updated**: October 23, 2025
**Branch**: `phase-8-group-chat`

