# 🧪 Test Checklist - Verify Main Branch

## 📱 Build Instructions
1. Open Xcode
2. Clean Build Folder: `Product → Clean Build Folder` (⌘⇧K)
3. Build and Run: `Product → Run` (⌘R)
4. Do this for all 3 devices

## ✅ Test 1: Direct Messages
**iPhone 17 → iPhone 16e**
- [ ] Send "Hello from iPhone 17"
- [ ] Message appears in blue (sent)
- [ ] Check marks appear (delivered)
- [ ] iPhone 16e receives message
- [ ] Reply from iPhone 16e
- [ ] iPhone 17 receives reply

## ✅ Test 2: Group Chat Creation
**From iPhone 17 Pro**
- [ ] Tap "Start New Chat"
- [ ] Search and select multiple users
- [ ] Create group chat
- [ ] Group appears on all devices
- [ ] All users see group name

## ✅ Test 3: Group Messages
**In Group Chat**
- [ ] Send message from iPhone 17 Pro
- [ ] All members receive it
- [ ] Send from iPhone 16e
- [ ] All members receive it
- [ ] Send from iPhone 17
- [ ] All members receive it

## ✅ Test 4: Read Receipts
**Direct Message**
- [ ] Send message from iPhone 17
- [ ] Open on iPhone 16e
- [ ] iPhone 17 shows "Read [time]" with blue checkmark

**Group Chat**
- [ ] Send message from iPhone 17 Pro
- [ ] Open on iPhone 16e and iPhone 17
- [ ] iPhone 17 Pro shows "Read by" with profile icons

## ✅ Test 5: Online Status
- [ ] All active devices show as online (green dot)
- [ ] Close app on one device
- [ ] Shows as offline after ~30 seconds
- [ ] Reopen app
- [ ] Shows as online again

## ✅ Test 6: Typing Indicators
- [ ] Start typing on iPhone 17
- [ ] iPhone 16e shows typing bubble
- [ ] Stop typing
- [ ] Typing bubble disappears after 1.5s

## ✅ Test 7: Message Features
- [ ] Long press message → context menu appears
- [ ] Reply to message works
- [ ] Delete message (shows "This message was deleted")
- [ ] Forward message works
- [ ] Emphasize message (heart icon)

## 🔍 Console Checks
Open Xcode console and verify:
- No red errors
- WebSocket connects: "✅ Connected to WebSocket"
- Messages send: "✅ Message sent via WebSocket"
- Status updates: "📬 Status update received"

## 📊 Results

### Working Features ✅
- [ ] Direct messages
- [ ] Group chats
- [ ] Read receipts
- [ ] Profile icons
- [ ] Online status
- [ ] Typing indicators
- [ ] Reply/Delete/Forward

### Issues Found ❌
- _List any problems here_

---

**Once all tests pass, we can safely add the edit feature!**
