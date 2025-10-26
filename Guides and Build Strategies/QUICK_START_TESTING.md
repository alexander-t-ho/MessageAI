# Cloudy - Quick Start Testing Guide
**Ready to test in 5 minutes!** ⚡

---

## 🚀 Quick Start (3 steps)

### Step 1: Open Xcode
```bash
cd /Users/alexho/MessageAI/MessageAI
open MessageAI.xcodeproj
```

### Step 2: Select Simulator
- Click on "MessageAI" next to the play button
- Select "iPhone 15 Pro" (or any recent iPhone)

### Step 3: Build & Run
- Press `Cmd + R` (or click the play button ▶️)
- Wait ~30 seconds for build
- App launches! 🎉

---

## ✅ Quick Test (10 items, 5 minutes)

### 1. Launch App ✓
- [ ] App opens to login screen
- [ ] Shows "Cloudy" branding
- [ ] Shows tagline: "Nothing like a message to brighten a cloudy day!"

### 2. Sign Up ✓
- [ ] Tap "Sign Up"
- [ ] Enter: `test@example.com` / `Test123!` / `Test User`
- [ ] Tap "Sign Up"
- [ ] Navigate to home screen

### 3. Search Users ✓
- [ ] Tap "+" or "New Chat"
- [ ] Type username
- [ ] See results (if other users exist)

### 4. Send Message ✓
- [ ] Create/open conversation
- [ ] Type: "Hello, this is a test!"
- [ ] Tap send
- [ ] Message appears on right side

### 5. Message Status ✓
- [ ] Message shows "Sending..."
- [ ] Then "Sent"
- [ ] Then "Delivered" (if recipient connected)

### 6. AI Translation ✓
- [ ] Long press any message
- [ ] Tap "Translate & Explain" ✨
- [ ] Wait 2-4 seconds
- [ ] See translation sheet

### 7. Profile Picture ✓
- [ ] Tap "Profile" tab
- [ ] Tap profile picture
- [ ] "Choose from Library"
- [ ] Select image
- [ ] Image updates

### 8. Message Color ✓
- [ ] Profile → "Message Color"
- [ ] Select a color
- [ ] Send message
- [ ] Message is that color

### 9. Dark Mode ✓
- [ ] Profile → Toggle dark mode
- [ ] UI switches immediately

### 10. App Restart ✓
- [ ] Close app completely
- [ ] Reopen app
- [ ] Auto-login (no login screen)
- [ ] All preferences saved

---

## 🎯 Core Features to Test

### Must Test (Critical)
- ✅ Authentication (sign up, log in)
- ✅ Send/receive messages
- ✅ AI translation
- ✅ Preferences persist

### Should Test (Important)
- ⭐ Message editing (long press → Edit)
- ⭐ Message deletion (long press → Delete)
- ⭐ Typing indicators
- ⭐ Read receipts

### Nice to Test (Optional)
- 💡 Group chat (if you have 3+ users)
- 💡 Offline mode
- 💡 Slang detection (send: "This is lit no cap")

---

## 🐛 What to Watch For

### Common Issues
1. **WebSocket not connecting**
   - Check console logs
   - Look for "💡 WebSocketService"
   - Should see "Connected"

2. **Messages not sending**
   - Check internet connection
   - Verify WebSocket connected
   - Try reconnecting

3. **AI features not working**
   - Translation takes 2-4 seconds (normal)
   - Check console for errors
   - Verify API key configured

4. **UI not updating**
   - Try closing and reopening conversation
   - Check if messages are in database

---

## 📊 Expected Results

### ✅ Good Signs
- App launches quickly (< 2 seconds)
- WebSocket connects immediately
- Messages send instantly (< 100ms)
- AI translation works (2-4 seconds)
- UI is smooth and responsive
- No crashes or freezes
- Preferences persist across restarts

### ❌ Bad Signs
- App crashes on launch
- WebSocket fails to connect
- Messages don't send
- AI features timeout
- UI freezes or lags
- Preferences don't save

---

## 🔧 Quick Fixes

### If WebSocket Won't Connect
1. Check `websocket-url.txt` has valid URL
2. Verify AWS Lambda functions deployed
3. Check internet connection

### If Messages Don't Send
1. Verify WebSocket connected
2. Check you have another user to message
3. Try logging out and back in

### If AI Features Fail
1. Check AWS Secrets Manager has OpenAI key
2. Verify Lambda has correct permissions
3. Check CloudWatch logs

### If App Crashes
1. Clean build folder (Cmd+Shift+K)
2. Rebuild (Cmd+B)
3. Check console for error messages

---

## 📱 Testing with Multiple Users

### Option 1: Two Simulators
1. Run app on first simulator
2. Click "Window" → "Duplicate Tab"
3. Select different simulator
4. Run again
5. Now you have 2 users!

### Option 2: Physical Device + Simulator
1. Connect iPhone via USB
2. Select iPhone as target
3. Run app
4. Also run on simulator
5. Message between them

### Option 3: Create Multiple Accounts
1. Sign up with different emails
2. Log out and log in as different users
3. Message between accounts

---

## 🎯 Success Criteria

### Minimum Viable (Must Pass)
- [x] App launches without crashing
- [x] Can sign up new user
- [x] Can log in existing user
- [x] Can send a message
- [x] Message appears in UI
- [x] Preferences persist on restart

### Fully Functional (Should Pass)
- [x] All minimum criteria above
- [x] WebSocket real-time messaging works
- [x] AI translation works
- [x] Can edit and delete messages
- [x] Profile customization works

### Production Ready (Ideal)
- [x] All functionality above
- [x] No crashes or freezes
- [x] Fast and responsive
- [x] Group chat works
- [x] Offline support works
- [x] Read receipts accurate

---

## 📚 Full Documentation

For comprehensive testing:
- **Full Test Suite**: `Guides and Build Strategies/TESTING_CHECKLIST_MAIN.md`
- **Project Status**: `Guides and Build Strategies/CURRENT_PROJECT_STATUS.md`
- **Implementation Summary**: `Guides and Build Strategies/PRE_VOICE_MESSAGES_SUMMARY.md`

For voice messages:
- **Implementation Guide**: `Guides and Build Strategies/VOICE_MESSAGES_FREE_STORAGE.md`
- **Roadmap**: `Guides and Build Strategies/VOICE_CHAT_ROADMAP.md`

---

## ✅ You're Done!

If all quick tests pass, you're ready to:
1. ✨ Implement voice messages
2. 🚀 Deploy to TestFlight
3. 📱 Share with beta testers

If tests fail:
1. 🐛 Check console logs
2. 📖 Review full testing guide
3. 🔧 Fix critical issues first

---

**Good luck testing Cloudy!** ☁️🎉

**Current Status**: ✅ On main branch, ready to test  
**Next Step**: Open Xcode and run the app  
**Time Needed**: 5-10 minutes for quick test

