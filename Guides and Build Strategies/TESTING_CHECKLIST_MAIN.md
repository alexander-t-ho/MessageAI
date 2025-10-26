# Cloudy - Main Branch Testing Checklist
**Date**: October 26, 2025  
**Purpose**: Verify all functionality before implementing voice messages  
**Branch**: main (up to date)

---

## 🎯 Testing Objective

Test all existing features on the main branch to ensure everything works before adding voice message functionality.

---

## 🔧 Setup Instructions

### 1. Open Xcode Project
```bash
cd /Users/alexho/MessageAI/MessageAI
open MessageAI.xcodeproj
```

### 2. Select Simulator
- iPhone 15 Pro (or any recent simulator)
- iOS 17.0+

### 3. Build and Run
- Press `Cmd + R` or click Run button
- Wait for build to complete
- App should launch on simulator

---

## ✅ Test Cases

### 1. Authentication Flow

#### Sign Up
- [ ] Launch app
- [ ] Should see Cloudy branding and tagline
- [ ] Tap "Sign Up"
- [ ] Enter email: `test@example.com`
- [ ] Enter password: `Test123!`
- [ ] Enter name: `Test User`
- [ ] Tap "Sign Up"
- [ ] Should see success and navigate to home

#### Log In
- [ ] Log out if needed
- [ ] Tap "Log In"
- [ ] Enter credentials
- [ ] Tap "Log In"
- [ ] Should navigate to home

#### Session Persistence
- [ ] Close and reopen app
- [ ] Should automatically log in (no login screen)

---

### 2. User Search & Conversation Creation

#### Search Users
- [ ] Tap "+" or "New Chat" button
- [ ] Should see search interface
- [ ] Type a username
- [ ] Should see search results
- [ ] Tap on a user
- [ ] Should create conversation

**Note**: You'll need at least 2 users in your Cognito user pool to test messaging.

---

### 3. One-on-One Messaging

#### Send Message
- [ ] Open a conversation
- [ ] Type message in text field
- [ ] Tap send button
- [ ] Message should appear on screen
- [ ] Message status should update: sending → sent → delivered

#### Receive Message
- [ ] Have another user send you a message (or use another simulator)
- [ ] Message should appear in real-time
- [ ] No refresh needed
- [ ] Message sound/notification (if enabled)

#### Message Bubble Alignment
- [ ] Your messages: Right side (blue/custom color)
- [ ] Other messages: Left side (gray)

---

### 4. Message Features

#### Typing Indicators
- [ ] Start typing in text field
- [ ] Other user should see "User is typing..."
- [ ] Stop typing
- [ ] Indicator should disappear after 3 seconds

#### Read Receipts
- [ ] Send a message
- [ ] Should show "Delivered"
- [ ] When recipient reads it, should show "Read"
- [ ] Timestamp should update

#### Message Editing
- [ ] Long press your own message
- [ ] Tap "Edit"
- [ ] Change message text
- [ ] Tap "Save"
- [ ] Message should update with "Edited" label
- [ ] Edit timestamp should show

#### Message Deletion
- [ ] Long press your own message
- [ ] Tap "Delete"
- [ ] Confirm deletion
- [ ] Message should disappear
- [ ] Should disappear for recipient too (if supported)

#### Message Emphasis
- [ ] Long press a message
- [ ] Tap "Emphasis" or ❤️
- [ ] Message should show emphasis indicator
- [ ] Counter should increment

---

### 5. AI Translation & Slang Detection

#### Test Translation
- [ ] Receive a message (or send from another account)
- [ ] Long press the message
- [ ] Tap "Translate & Explain" ✨
- [ ] Wait 2-4 seconds
- [ ] Should see translation sheet with:
  - Original message
  - Translation in your preferred language
  - Slang explanations (if any slang detected)

#### Set Language Preference
- [ ] Tap "Profile" tab
- [ ] Tap "Language Preferences"
- [ ] Should see list of 25+ languages
- [ ] Select a language (e.g., Spanish)
- [ ] Tap "Favorite" star icon
- [ ] Go back
- [ ] Translate a message again
- [ ] Should translate to selected language

#### Test Slang Detection
**Known Slang Terms** (from `slang-database.json`):
- "no cap" → "no lie, for real"
- "bet" → "agreement, okay"
- "lit" → "exciting, awesome"
- "lowkey" → "secretly, somewhat"
- "highkey" → "obviously, very much"
- "slay" → "excel, do great"
- "bussin" → "really good"
- "fr" → "for real"
- "ong" → "on God, I swear"
- "ngl" → "not gonna lie"
- "iykyk" → "if you know you know"
- "oomf" → "one of my followers"
- "mid" → "mediocre, average"
- "sus" → "suspicious"
- "cap" → "lie"
- "stan" → "obsessive fan"
- "simp" → "overly eager to please"
- "periodt" → "end of discussion"
- "salty" → "upset, bitter"
- "flex" → "show off"
- "ghosted" → "ignored, cut off contact"

**Test Steps**:
- [ ] Send/receive message with slang: "This party is lit no cap"
- [ ] Translate & Explain
- [ ] Should see:
  - Translation
  - "lit" explained
  - "no cap" explained

---

### 6. Group Chat

#### Create Group
- [ ] Tap "+" or "New Group"
- [ ] Select multiple users (2+)
- [ ] Enter group name: "Test Group"
- [ ] Tap "Create"
- [ ] Should see group chat

#### Group Messaging
- [ ] Send message to group
- [ ] All members should receive
- [ ] Messages should show sender name

#### Group Read Receipts
- [ ] Send message in group
- [ ] When members read it, should show:
  - "Read by User1, User2"
  - Or read count: "Read by 2 of 3"

#### Group Management
- [ ] Tap group name/header
- [ ] Should see group details
- [ ] List of members
- [ ] Option to add more members
- [ ] Option to leave group

---

### 7. Personalization

#### Profile Picture
- [ ] Tap "Profile" tab
- [ ] Tap profile picture placeholder
- [ ] Should see options:
  - "Choose from Library"
  - "Cancel"
- [ ] Select "Choose from Library"
- [ ] Pick an image
- [ ] Image should update immediately
- [ ] Navigate away and back
- [ ] Image should persist

#### Message Color
- [ ] Go to Profile → "Message Color"
- [ ] Should see:
  - Color wheel
  - 12 preset colors
- [ ] Select a preset color
- [ ] Send a message
- [ ] Your messages should be that color
- [ ] Try custom color with color wheel
- [ ] Your messages should update

#### Nickname System
- [ ] Open a conversation
- [ ] Tap user's name in header
- [ ] Should see "Edit Nickname" option
- [ ] Enter nickname: "Best Friend"
- [ ] Save
- [ ] Name should update in conversation
- [ ] Navigate to conversation list
- [ ] Should show nickname there too

#### Dark Mode
- [ ] Go to Profile
- [ ] Toggle dark mode
- [ ] UI should switch immediately
- [ ] Try "System" option
- [ ] Should follow device setting

#### Preferences Persistence
- [ ] Set custom color, nickname, dark mode
- [ ] Close app completely
- [ ] Reopen app
- [ ] All preferences should be saved

---

### 8. Online Presence

#### Online Status
- [ ] Log in
- [ ] Should show green halo around your profile picture
- [ ] Other users should see you as online
- [ ] Close app
- [ ] Other users should see you as offline

#### Presence Indicators
- [ ] In conversation list
- [ ] Should see green dot next to online users
- [ ] Gray/no dot for offline users

---

### 9. Draft Messages

#### Create Draft
- [ ] Open conversation
- [ ] Type message but DON'T send
- [ ] Navigate away
- [ ] Go back to conversation
- [ ] Typed message should still be there

#### Draft Persistence
- [ ] Type draft in Conversation A
- [ ] Switch to Conversation B
- [ ] Type draft in Conversation B
- [ ] Both drafts should be saved separately

---

### 10. Offline Support

#### Queue Messages
- [ ] Enable Airplane Mode (or simulate offline in app)
- [ ] Send a message
- [ ] Should show "Queued" or "Sending" status
- [ ] Disable Airplane Mode
- [ ] Message should send automatically
- [ ] Status should update to "Sent"

#### Catch Up
- [ ] Close app while offline
- [ ] Have someone send you messages
- [ ] Reopen app with internet
- [ ] Should receive all missed messages
- [ ] Messages should sync automatically

---

### 11. Performance & Reliability

#### Load Time
- [ ] App launch: < 2 seconds ✅
- [ ] WebSocket connection: < 1 second ✅
- [ ] Message send: < 100ms ✅

#### Memory Usage
- [ ] Open Xcode → Debug Navigator
- [ ] Check memory usage
- [ ] Should be reasonable (< 100MB typical)

#### No Crashes
- [ ] Use app for 5-10 minutes
- [ ] Send multiple messages
- [ ] Edit, delete, emphasize
- [ ] Switch conversations
- [ ] No crashes should occur

---

## 🐛 Known Issues to Watch For

### High Priority Issues
1. **Group chat read receipts** - May be slow or incomplete
   - Aggregation needs optimization
   - Multiple users reading at once

2. **Push notifications** - May not work
   - Requires Apple Developer enrollment
   - Remote APNs not configured

3. **Banner notifications** - May show when app is open
   - Should only show when app in background
   - Need to implement foreground check

### Medium Priority Issues
- Large conversations (100+ messages) may be slow
- Profile pictures may take time to load
- Translation cache not always working

---

## 📊 Test Results Template

Use this template to document your testing:

```
## Test Session: [Date/Time]

### Authentication ✅ / ❌
- Sign up: ✅
- Log in: ✅
- Session persistence: ✅
- Issues: [None / Describe]

### Messaging ✅ / ❌
- Send message: ✅
- Receive message: ✅
- Typing indicators: ✅
- Read receipts: ✅
- Edit message: ✅
- Delete message: ✅
- Issues: [None / Describe]

### AI Features ✅ / ❌
- Translation: ✅
- Slang detection: ✅
- Language preferences: ✅
- Issues: [None / Describe]

### Group Chat ✅ / ❌
- Create group: ✅
- Send message: ✅
- Read receipts: ❌ [Too slow]
- Issues: [Describe]

### Personalization ✅ / ❌
- Profile picture: ✅
- Message color: ✅
- Nicknames: ✅
- Dark mode: ✅
- Persistence: ✅
- Issues: [None / Describe]

### Performance ✅ / ❌
- No crashes: ✅
- Fast response: ✅
- Memory usage: ✅
- Issues: [None / Describe]

### Overall Rating: [Excellent / Good / Fair / Poor]
### Ready for voice messages: [Yes / No]
### Blockers: [None / Describe]
```

---

## 🚀 Next Steps After Testing

### If All Tests Pass ✅
1. Document any minor issues
2. Proceed with voice message implementation
3. Follow `VOICE_MESSAGES_FREE_STORAGE.md`
4. Follow `VOICE_CHAT_ROADMAP.md`

### If Tests Fail ❌
1. Document all issues
2. Prioritize critical bugs
3. Fix blockers before proceeding
4. Re-test after fixes

---

## 📚 Additional Resources

- **Implementation Guides**: `Guides and Build Strategies/`
- **Voice Messages Guide**: `VOICE_MESSAGES_FREE_STORAGE.md`
- **Voice Roadmap**: `VOICE_CHAT_ROADMAP.md`
- **Current Status**: `CURRENT_PROJECT_STATUS.md`
- **Backend Testing**: `test-group-backend.sh`

---

## 🔍 Debugging Tips

### WebSocket Issues
- Check console logs: "💡 WebSocketService"
- Verify URL: `websocket-url.txt`
- Check AWS Lambda logs

### Message Not Sending
- Check internet connection
- Verify WebSocket connected
- Check console for errors
- Try reconnecting

### AI Features Not Working
- Verify OpenAI API key in AWS Secrets Manager
- Check Lambda logs for `translateAndExplainSimple`
- Verify slang database populated

### UI Not Updating
- Check SwiftData model context
- Verify @Published properties
- Try closing and reopening conversation

---

**Testing Status**: ⏳ Pending  
**Last Updated**: October 26, 2025  
**Next**: Run through all test cases and document results

