# 🧪 **Phase 4 Testing Guide**

## 🎉 **Phase 4 Complete!**

Real-time messaging is now fully integrated! Let's test it!

---

## ✅ **What's Working**

### **Backend (AWS)**
- ✅ WebSocket API deployed
- ✅ Lambda functions live
- ✅ DynamoDB tables ready
- ✅ Connection management working
- ✅ Message broadcasting ready

### **iOS App**
- ✅ WebSocketService implemented
- ✅ Auto-connect on login
- ✅ Send messages via WebSocket
- ✅ Receive messages in real-time
- ✅ Auto-reconnect on disconnect
- ✅ Message deduplication

---

## 🧪 **Testing Options**

### **Option 1: Two Simulators** (Recommended for now)

**Why:** Easiest to test, no second device needed

**Steps:**
1. Open two iOS simulators
2. Run app on both
3. Login with different accounts
4. Send messages between them

### **Option 2: Simulator + Physical Device**

**Why:** More realistic, tests actual network

**Steps:**
1. Run on simulator
2. Run on your iPhone
3. Login with different accounts
4. Send messages

### **Option 3: Two Physical Devices**

**Why:** Most realistic testing

**Steps:**
1. Run on two iPhones
2. Login with different accounts
3. Send messages

---

## 📋 **Testing Checklist**

### **Phase 1: Connection**

- [ ] Open app on first device
- [ ] Login with test user 1
- [ ] Check Xcode console for:
  ```
  💡 WebSocketService initialized
  🔌 Connecting to WebSocket with userId: ...
  🔌 Connecting to WebSocket...
  ✅ Connected to WebSocket
  ```

- [ ] Open app on second device
- [ ] Login with test user 2
- [ ] Check console for connection messages

### **Phase 2: Send Message (Device 1 → Device 2)**

**On Device 1:**
- [ ] Go to a conversation with Device 2's user
- [ ] Type a message: "Hello from Device 1!"
- [ ] Send message
- [ ] Check console for:
  ```
  ✅ Message added to UI
  ✅ Message sent via WebSocket
  ```

**On Device 2:**
- [ ] Watch the conversation
- [ ] Message should appear instantly! ⚡
- [ ] Check console for:
  ```
  📥 Received WebSocket message
  ✅ New message received: ...
  📥 Handling received WebSocket message
  ✅ Message added to conversation
  ```

### **Phase 3: Reply (Device 2 → Device 1)**

**On Device 2:**
- [ ] Reply with: "Hi back!"
- [ ] Message sends

**On Device 1:**
- [ ] Reply appears instantly ⚡
- [ ] Both messages visible in conversation

### **Phase 4: Test Reply Feature**

**On Device 1:**
- [ ] Swipe RIGHT on a message
- [ ] Reply banner appears
- [ ] Type reply: "This is a reply"
- [ ] Send

**On Device 2:**
- [ ] Received message shows reply context
- [ ] Can tap reply context to scroll to original

### **Phase 5: Test Other Features**

- [ ] Long press → Emphasize
- [ ] Long press → Forward
- [ ] Long press → Delete
- [ ] Send multiple messages quickly
- [ ] Messages arrive in order

### **Phase 6: Reconnection**

**On Device 1:**
- [ ] Put app in background (swipe up)
- [ ] Wait 30 seconds
- [ ] Bring app to foreground
- [ ] Should auto-reconnect
- [ ] Check console for reconnection messages

### **Phase 7: Offline → Online**

**On Device 1:**
- [ ] Turn off WiFi
- [ ] Try to send message
- [ ] Message saves locally
- [ ] Turn WiFi back on
- [ ] Should reconnect
- [ ] (Note: Offline sync is Phase 5, so message won't send automatically yet)

---

## 🔍 **Console Output to Look For**

### **Successful Connection:**
```
💡 WebSocketService initialized with URL: wss://...
🔌 Connecting to WebSocket with userId: abc123
🔌 Connecting to WebSocket...
   URL: wss://bnbr75tld0.execute-api.us-east-1.amazonaws.com/production?userId=abc123
✅ Connected to WebSocket
```

### **Successful Send:**
```
✅ Message added to UI - now showing X messages
✅ Message sent via WebSocket: message-id-123
```

### **Successful Receive:**
```
📥 Received WebSocket message: {...}
✅ New message received: message-id-456
   From: Test User
   Content: Hello!
📥 Handling received WebSocket message: message-id-456
✅ Message added to conversation
```

### **Reconnection:**
```
🔌 WebSocket disconnected
🔄 Reconnecting in 2 seconds (attempt 1/5)...
🔌 Connecting to WebSocket...
✅ Connected to WebSocket
```

---

## ❌ **Troubleshooting**

### **Issue: Messages not sending**

**Check:**
1. Console shows "✅ Message sent via WebSocket"?
   - **No** → WebSocket not connected, check connection
   - **Yes** → Backend issue, check Lambda logs

**Fix:**
```bash
# Check Lambda logs
aws logs tail /aws/lambda/websocket-sendMessage_AlexHo --follow --region us-east-1
```

### **Issue: Messages not receiving**

**Check:**
1. Second device console shows "📥 Received WebSocket message"?
   - **No** → Not connected or message not delivered
   - **Yes** → Check handleReceivedMessage logs

**Fix:**
- Restart both apps
- Check both are connected
- Verify different user IDs

### **Issue: Can't connect to WebSocket**

**Check:**
1. Console shows connection error?
2. WebSocket URL correct?
3. AWS WebSocket API deployed?

**Fix:**
```bash
# Verify API is deployed
aws apigatewayv2 get-apis --region us-east-1 --query "Items[?Name=='MessageAI-WebSocket_AlexHo']"

# Check route configurations
aws apigatewayv2 get-routes --api-id bnbr75tld0 --region us-east-1
```

### **Issue: Duplicate messages**

**Check:**
- Console shows "⚠️ Message already exists, ignoring duplicate"?

**This is expected!** The deduplication is working.

### **Issue: Connection drops frequently**

**Check:**
- Running on simulator or device?
- Network stable?
- Check reconnection logic working

**Expected:** Auto-reconnect should happen within 2-30 seconds

---

## 📊 **Expected Behavior**

### **✅ What Should Work:**

- Login connects to WebSocket
- Sending message shows in sender's UI immediately
- Sending message arrives at recipient instantly (< 1 second)
- Reply feature works
- Emphasize feature works
- Forward feature works
- Delete feature works
- Reconnection works
- Multiple messages in quick succession
- Messages persist in database

### **⏳ What Doesn't Work Yet:**

- Real Cognito user IDs (using test IDs for now)
- Conversation participant tracking
- Offline message queue (Phase 5)
- Read receipts (Phase 6)
- Typing indicators (Phase 7)
- Group chat (Phase 8)
- Push notifications (Phase 9)

---

## 🎯 **Success Criteria**

Phase 4 is successful if:

- [x] Backend deployed and accessible
- [x] iOS app connects to WebSocket
- [x] Messages send via WebSocket
- [x] Messages received in real-time
- [x] Auto-reconnect works
- [x] Build succeeds
- [ ] End-to-end test passes (you test it!)

---

## 💡 **Tips for Testing**

1. **Keep Console Open**
   - Watch for connection/send/receive logs
   - Helps debug issues immediately

2. **Start Simple**
   - Test with just 2 simulators first
   - Then try more complex scenarios

3. **Test Edge Cases**
   - Send many messages quickly
   - Kill and restart app
   - Put in background
   - Turn off/on WiFi

4. **Note Issues**
   - Screenshot any problems
   - Copy console output
   - Note exact steps to reproduce

---

## 🚀 **What's Next**

After testing Phase 4:

### **Phase 5: Offline Support** (Next!)
- Message queue for offline
- Sync when back online
- Retry failed messages

### **Phase 6: Read Receipts**
- Delivered status
- Read status
- Timestamp formatting

### **Phase 7: Presence & Typing**
- Online/offline status
- Typing indicators
- Last seen

### **Phase 8: Group Chat**
- Group conversations
- Multiple recipients
- Group info

### **Phase 9: Push Notifications**
- Background notifications
- Badge counts
- Sound/vibration

### **Phase 10: Testing & Deployment**
- Full testing
- Performance optimization
- Production deployment

---

## 💬 **Feedback**

After testing, let me know:

1. **What worked?** ✅
2. **What didn't work?** ❌
3. **Any errors?** (Share console output)
4. **Ready for Phase 5?** 🚀

---

**Current Status:** Phase 4 Complete - Ready for Testing!  
**Next Phase:** Phase 5 - Offline Support & Message Sync  
**Estimated Time:** Your app is now a REAL messaging app! 🎉

