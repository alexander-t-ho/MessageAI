# ✅ **Phase 3 Testing Checklist**

## 🚀 **Quick Start**

### **Option 1: Xcode (Easiest)**
1. Open Xcode
2. Select `MessageAI` project
3. Make sure "iPhone 17" simulator is selected
4. Press **▶️ Play** button (or Cmd+R)
5. Wait for app to build and launch

### **Option 2: Terminal**
```bash
cd /Users/alexho/MessageAI

# Build
xcodebuild -project MessageAI/MessageAI.xcodeproj \
  -scheme MessageAI \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  build

# Launch simulator
open -a Simulator
```

---

## 📋 **Testing Steps**

### **1. Tab Navigation** ✅
- [ ] After login, see 2 tabs at bottom
- [ ] Left tab: 💬 "Messages"
- [ ] Right tab: 👤 "Profile"
- [ ] Tap between tabs - smooth transition

---

### **2. Messages Tab (Empty State)** ✅
If no conversations yet:
- [ ] See large message bubble icon
- [ ] Text: "No Conversations Yet"
- [ ] Blue button: "Start New Chat"

---

### **3. Create Test Conversation** ✅
- [ ] Tap **"+"** button (top right)
- [ ] Sheet appears: "New Conversation"
- [ ] Enter:
  - **Recipient Name**: "Test User"
  - **Recipient ID**: "test-123"
- [ ] Tap **"Create"** button
- [ ] Sheet closes
- [ ] New conversation appears in list

**Expected Result:**
```
┌─────────────────────────────────┐
│ TU  Test User           Just now│
│     No messages yet             │
└─────────────────────────────────┘
```

---

### **4. Open Chat & Send Message** ✅
- [ ] Tap the conversation you created
- [ ] Chat view opens with "Test User" title
- [ ] See text input at bottom
- [ ] Type: "Hello! This is my first message 🎉"
- [ ] Blue send button appears (arrow circle)
- [ ] Tap send button

**Expected Result:**
```
                    ┌─────────────────────┐
                    │ Hello! This is my   │
                    │ first message 🎉    │
                    └─────────────────────┘
                      3:45 PM ✓
```
- [ ] Message appears as blue bubble on right side
- [ ] Shows timestamp
- [ ] Shows checkmark (sent status)

---

### **5. Test Draft Feature** 📝
- [ ] Open a conversation
- [ ] Type: "This is a draft - don't send!"
- [ ] **DO NOT tap send button**
- [ ] Tap **back arrow** (top left) to go to conversation list
- [ ] Tap the same conversation again to reopen

**Expected Result:**
- [ ] Input field pre-filled with: "This is a draft - don't send!"
- [ ] Draft persists even after app restart!

---

### **6. Send Multiple Messages** ✅
- [ ] Send these messages one by one:
  ```
  First message
  Second message
  Third message with emoji 🚀
  ```

**Expected Result:**
- [ ] All 3 appear as blue bubbles
- [ ] Stacked vertically
- [ ] Each has timestamp
- [ ] Chat auto-scrolls to bottom

---

### **7. Check Conversation List** ✅
- [ ] Go back to Messages tab
- [ ] Your conversation shows:
  - **Name**: "Test User"
  - **Last Message**: "Third message with emoji 🚀"
  - **Time**: "3:46 PM" (or similar)
  - **Avatar**: Circle with "T" initial

---

### **8. Create Multiple Conversations** ✅
- [ ] Tap **"+"** again
- [ ] Create conversation with:
  - Name: "Jane Doe"
  - ID: "jane-456"
- [ ] Repeat for:
  - Name: "John Smith"
  - ID: "john-789"

**Expected Result:**
- [ ] 3 conversations in list
- [ ] Each has unique colored avatar
- [ ] Sorted by last message time

---

### **9. Delete Conversation** ✅
- [ ] Swipe LEFT on any conversation
- [ ] Red "Delete" button appears
- [ ] Tap "Delete"

**Expected Result:**
- [ ] Conversation disappears from list
- [ ] Smooth animation

---

### **10. Profile Tab** ✅
- [ ] Tap **Profile** tab (bottom right)
- [ ] Verify you see:
  - [ ] Avatar circle with your initial
  - [ ] Your name
  - [ ] Your email
  - [ ] **Account** section
  - [ ] **Development Progress** section:
    ```
    ✓ Authentication          Complete
    ✓ Local Database          Complete
    ✓ Draft Messages          Complete
    🔨 One-on-One Messaging   In Progress
    ○ Real-Time Updates       Pending
    ○ Offline Support         Pending
    ```
  - [ ] **Developer Tools** section:
    - "Database Test" button
  - [ ] **Logout** button (red)

---

### **11. Database Test (Still Works!)** ✅
- [ ] In Profile tab, tap "Database Test"
- [ ] Sheet opens with test UI
- [ ] Verify draft section is there
- [ ] Close sheet

---

### **12. Logout & Re-login** ✅
- [ ] Tap "Logout" button
- [ ] Redirected to login screen
- [ ] Log back in with your credentials

**Expected Result:**
- [ ] All conversations still there
- [ ] All messages still there
- [ ] Drafts still saved
- [ ] **Everything persists! 🎉**

---

## 🎯 **Phase 3 Success Checklist**

**UI/UX:**
- [✅] Tab navigation smooth
- [✅] Conversation list looks professional
- [✅] Chat bubbles styled correctly (blue = you)
- [✅] Timestamps formatted nicely
- [✅] Avatars show colored circles with initials
- [✅] Empty state UI when no conversations

**Functionality:**
- [✅] Create conversations
- [✅] Send messages
- [✅] Messages appear immediately
- [✅] Drafts auto-save while typing
- [✅] Drafts restore when reopening chat
- [✅] Delete conversations
- [✅] Data persists after logout/restart

**Polish:**
- [✅] No crashes or freezes
- [✅] Smooth animations
- [✅] Loading spinners when appropriate
- [✅] Status indicators (clock/checkmarks)
- [✅] Auto-scroll to latest message

---

## 🐛 **If Something Goes Wrong**

### **App Won't Build:**
```bash
cd /Users/alexho/MessageAI
xcodebuild -project MessageAI/MessageAI.xcodeproj \
  -scheme MessageAI clean build 2>&1 | grep "error:"
```

### **Simulator Black Screen:**
```bash
# Reset simulator
xcrun simctl shutdown all
xcrun simctl erase all
xcrun simctl boot "iPhone 17"
open -a Simulator
```

### **Messages Not Showing:**
- Check Database Test view to verify data is saving
- Try creating a new conversation
- Restart the app

### **Draft Not Working:**
- Open Database Test
- Test draft save/load in that view first
- Check for any error messages in Xcode console

---

## ✅ **When You're Done Testing**

Reply with:
- ✅ "Everything works!" → Move to Phase 4
- ⚠️ "I found an issue..." → Describe what's not working
- 🤔 "I have a question..." → Ask away!

---

**Phase 3 Status:** ✅ Complete - Ready for Testing  
**Next Phase:** 🚀 Phase 4: Real-Time Messaging

