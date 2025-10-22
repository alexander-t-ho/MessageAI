# MessageAI Testing Guide

Comprehensive testing checklist for all features in the MessageAI MVP.

## Testing Environment Setup

### Requirements
- 2 iOS simulators running (iPhone 15 Pro and iPhone 15)
- Both logged in with different users
- Stable internet connection
- Firebase Console access for verification

### Test Users
Create these test accounts:
1. **Alice**: alice@test.com / password123
2. **Bob**: bob@test.com / password123
3. **Charlie**: charlie@test.com / password123

---

## Feature 1: User Authentication

### Test 1.1: Registration Flow
**Steps:**
1. Open app on Simulator 1
2. Tap "Don't have an account? Register"
3. Enter:
   - Display Name: Alice
   - Email: alice@test.com
   - Password: password123
   - Confirm Password: password123
4. Tap "Register"

**Expected Result:**
- ✅ Registration completes successfully
- ✅ User is logged in automatically
- ✅ Main tab view appears with Messages, Groups, Settings tabs
- ✅ No error messages displayed

**Firebase Verification:**
- Go to Firebase Console → Authentication → Users
- ✅ New user appears with correct email

### Test 1.2: Login Flow
**Steps:**
1. Logout from Alice's account
2. Enter credentials:
   - Email: alice@test.com
   - Password: password123
3. Tap "Login"

**Expected Result:**
- ✅ Login completes successfully
- ✅ User is redirected to main tab view
- ✅ User profile data loads correctly

### Test 1.3: Persistent Login
**Steps:**
1. Login as Alice
2. Force quit app (swipe up from bottom of simulator)
3. Reopen app

**Expected Result:**
- ✅ User remains logged in
- ✅ No login screen shown
- ✅ Main view loads immediately

### Test 1.4: Logout
**Steps:**
1. Go to Settings tab
2. Tap "Logout"
3. Confirm logout

**Expected Result:**
- ✅ User is logged out
- ✅ Returns to login screen
- ✅ Cannot access protected screens

### Test 1.5: Invalid Credentials
**Steps:**
1. Try logging in with wrong password
2. Try logging in with non-existent email

**Expected Result:**
- ✅ Error message displayed
- ✅ User remains on login screen
- ✅ Can retry with correct credentials

---

## Feature 2: User List & Online Presence

### Test 2.1: User List Display
**Steps:**
1. Login as Alice on Simulator 1
2. Login as Bob on Simulator 2
3. In Alice's app, go to Messages tab
4. Check "All Users" section

**Expected Result:**
- ✅ Bob appears in user list
- ✅ Alice does NOT appear in her own list
- ✅ Bob's display name shown correctly
- ✅ Bob's profile picture or initials shown

### Test 2.2: Online Status - Going Online
**Steps:**
1. Bob's app is closed
2. Open Bob's app and login
3. In Alice's app, observe Bob's status

**Expected Result:**
- ✅ Bob's status shows green dot and "Online"
- ✅ Status updates within 1-2 seconds
- ✅ No manual refresh needed

### Test 2.3: Online Status - Going Offline
**Steps:**
1. Bob is logged in
2. Close Bob's app (swipe up to quit)
3. In Alice's app, observe Bob's status after 5 seconds

**Expected Result:**
- ✅ Bob's status shows gray dot
- ✅ Shows "Last seen X seconds ago"
- ✅ Status updates automatically

### Test 2.4: Last Seen Timestamp
**Steps:**
1. Bob goes offline
2. Wait 1 minute
3. Check Bob's status in Alice's app

**Expected Result:**
- ✅ Shows "Last seen 1m ago" (approximate)
- ✅ Timestamp updates as time passes
- ✅ Format is human-readable

---

## Feature 3: One-on-One Chat UI

### Test 3.1: Opening Chat
**Steps:**
1. In Alice's app, tap on Bob in user list
2. Chat screen should open

**Expected Result:**
- ✅ Chat screen opens with Bob's name in navigation bar
- ✅ Message input field visible at bottom
- ✅ Send button visible (grayed out when empty)
- ✅ Photo picker button visible

### Test 3.2: Message Bubble Alignment
**Steps:**
1. Send message "Hi Bob!" from Alice
2. Send reply "Hello Alice!" from Bob
3. Observe message bubbles in both apps

**Expected Result:**
- ✅ Alice's messages appear on right side (blue bubbles)
- ✅ Bob's messages appear on left side (gray bubbles)
- ✅ Sender name NOT shown on own messages
- ✅ Sender name shown on received messages

### Test 3.3: Auto-Scroll
**Steps:**
1. Send 10+ messages back and forth
2. Observe scroll behavior

**Expected Result:**
- ✅ Chat auto-scrolls to latest message
- ✅ Newest message always visible
- ✅ Smooth scrolling animation
- ✅ Can manually scroll up to see older messages

### Test 3.4: Keyboard Handling
**Steps:**
1. Tap input field to open keyboard
2. Type a message
3. Send message

**Expected Result:**
- ✅ Keyboard doesn't cover input field
- ✅ Chat adjusts height for keyboard
- ✅ Input field remains accessible
- ✅ Keyboard dismisses after sending

---

## Feature 4: Real-Time Message Delivery

### Test 4.1: Basic Message Sending
**Steps:**
1. Alice types "Hello Bob!"
2. Tap send button

**Expected Result:**
- ✅ Message appears immediately in Alice's chat (optimistic update)
- ✅ Message appears in Bob's chat within 1 second
- ✅ Message text is identical in both chats
- ✅ Timestamp shows on both sides

### Test 4.2: Rapid Message Sending
**Steps:**
1. Send 10 messages quickly from Alice
2. Observe delivery in Bob's chat

**Expected Result:**
- ✅ All 10 messages delivered
- ✅ Messages appear in correct order
- ✅ No messages lost or duplicated
- ✅ No lag or freezing

### Test 4.3: Message Persistence
**Steps:**
1. Send 5 messages from Alice to Bob
2. Force quit both apps
3. Reopen both apps
4. Navigate to chat

**Expected Result:**
- ✅ All 5 messages still visible
- ✅ Messages in correct order
- ✅ Timestamps preserved
- ✅ No data loss

### Test 4.4: Firebase Verification
**Steps:**
1. Send a message
2. Go to Firebase Console → Firestore → chats collection
3. Check message document

**Expected Result:**
- ✅ Chat document created with correct chatId
- ✅ Message document created in messages subcollection
- ✅ Correct senderId, text, timestamp
- ✅ Status field present

---

## Feature 5: Message Persistence & Offline Support

### Test 5.1: Loading Cached Messages
**Steps:**
1. Send 10 messages between Alice and Bob
2. Enable Airplane Mode on Simulator 1
3. Close and reopen Alice's app
4. Navigate to chat with Bob

**Expected Result:**
- ✅ All 10 messages load from cache
- ✅ Messages display correctly
- ✅ No loading spinner indefinitely
- ✅ "No internet connection" banner shows

### Test 5.2: Sending Message Offline
**Steps:**
1. Enable Airplane Mode on Alice's simulator
2. Try sending message "Offline test"
3. Observe message status

**Expected Result:**
- ✅ Message appears in Alice's chat
- ✅ Status shows "sending" or clock icon
- ✅ Message queued locally
- ✅ "No internet connection" banner visible

### Test 5.3: Automatic Sync on Reconnect
**Steps:**
1. Send 3 messages while offline
2. Disable Airplane Mode
3. Wait 5 seconds

**Expected Result:**
- ✅ All 3 messages send automatically
- ✅ Status changes from "sending" to "sent"
- ✅ Messages appear in Bob's chat
- ✅ No duplicate messages

### Test 5.4: Network Status Indicator
**Steps:**
1. Toggle Airplane Mode on/off
2. Observe app UI

**Expected Result:**
- ✅ Orange banner appears when offline
- ✅ Banner shows "No internet connection"
- ✅ Banner disappears when back online
- ✅ Updates within 1-2 seconds

---

## Feature 6: Typing Indicators

### Test 6.1: Typing Indicator Appears
**Steps:**
1. Alice opens chat with Bob
2. Bob opens chat with Alice
3. Alice starts typing (don't send)
4. Observe Bob's chat

**Expected Result:**
- ✅ "typing..." indicator appears in Bob's chat
- ✅ Appears within 1 second
- ✅ Displayed below message list, above input field
- ✅ Styled in gray italic text

### Test 6.2: Typing Indicator Disappears
**Steps:**
1. Alice is typing
2. Alice stops typing (doesn't send, just stops)
3. Wait 3 seconds
4. Observe Bob's chat

**Expected Result:**
- ✅ "typing..." indicator disappears after 3 seconds
- ✅ Disappears automatically, no manual action needed

### Test 6.3: No Self-Typing Indicator
**Steps:**
1. Alice types in her own chat
2. Observe Alice's chat

**Expected Result:**
- ✅ Alice does NOT see "typing..." indicator
- ✅ Only the recipient sees it

### Test 6.4: Typing While Sending
**Steps:**
1. Alice types message
2. Tap send
3. Observe Bob's chat

**Expected Result:**
- ✅ "typing..." disappears when message sent
- ✅ Message appears immediately after
- ✅ No lingering indicator

---

## Feature 7: Read Receipts

### Test 7.1: Sent Status
**Steps:**
1. Alice sends message to Bob
2. Immediately observe status icon in Alice's chat

**Expected Result:**
- ✅ Single checkmark (✓) appears
- ✅ Gray color
- ✅ Shows "sent" status

### Test 7.2: Delivered Status
**Steps:**
1. Alice sends message
2. Message reaches Firebase
3. Bob's app is open
4. Observe status in Alice's chat

**Expected Result:**
- ✅ Double checkmark (✓✓) appears
- ✅ Gray color
- ✅ Shows "delivered" status

### Test 7.3: Read Status
**Steps:**
1. Alice sends message to Bob
2. Bob opens the chat (if not already open)
3. Observe status in Alice's chat after 1-2 seconds

**Expected Result:**
- ✅ Double checkmark (✓✓) turns blue
- ✅ Shows "read" status
- ✅ Updates automatically

### Test 7.4: Batch Read Receipts
**Steps:**
1. Bob's app is closed
2. Alice sends 5 messages
3. Bob opens app and navigates to chat
4. Observe status in Alice's chat

**Expected Result:**
- ✅ All 5 messages marked as "read"
- ✅ All show blue double checkmarks
- ✅ Updates within 2 seconds

---

## Feature 8: Basic Group Chat

### Test 8.1: Creating Group
**Steps:**
1. Login 3 users: Alice, Bob, Charlie
2. In Alice's app, go to Groups tab
3. Tap "+" button
4. Enter group name: "Team Chat"
5. Select Bob and Charlie
6. Tap "Create"

**Expected Result:**
- ✅ Group created successfully
- ✅ Group appears in Alice's group list
- ✅ Group shows "3 members"
- ✅ All participants listed

### Test 8.2: Group Appears for All Participants
**Steps:**
1. After creating group, check Bob's and Charlie's apps
2. Navigate to Groups tab

**Expected Result:**
- ✅ "Team Chat" appears in both Bob's and Charlie's group lists
- ✅ Shows correct participant count
- ✅ Shows group name correctly

### Test 8.3: Sending Group Messages
**Steps:**
1. Alice opens "Team Chat"
2. Sends message: "Hello team!"
3. Observe in Bob's and Charlie's apps

**Expected Result:**
- ✅ Message appears in all three chats
- ✅ Message shows sender name ("Alice")
- ✅ Delivered within 1 second
- ✅ Timestamp shown

### Test 8.4: Multiple Senders in Group
**Steps:**
1. Alice sends: "Message from Alice"
2. Bob sends: "Message from Bob"
3. Charlie sends: "Message from Charlie"
4. Observe all three apps

**Expected Result:**
- ✅ All messages appear in all chats
- ✅ Correct sender name shown on each message
- ✅ Messages in chronological order
- ✅ Different colors/styles for different senders

### Test 8.5: Group Persistence
**Steps:**
1. Send 10 messages in group
2. Close all apps
3. Reopen Alice's app
4. Navigate to Groups → Team Chat

**Expected Result:**
- ✅ All 10 messages still visible
- ✅ Group metadata preserved
- ✅ Participant list intact

---

## Feature 9: Message Timestamps

### Test 9.1: Just Now
**Steps:**
1. Send a message
2. Immediately check timestamp

**Expected Result:**
- ✅ Shows "Just now" or "0m ago"
- ✅ Updates to "1m ago" after 1 minute

### Test 9.2: Relative Time
**Steps:**
1. Send messages at different times
2. Check timestamps after:
   - 5 minutes
   - 30 minutes
   - 1 hour

**Expected Result:**
- ✅ Shows "5m ago" after 5 minutes
- ✅ Shows "30m ago" after 30 minutes
- ✅ Shows "1h ago" after 1 hour

### Test 9.3: Yesterday
**Steps:**
1. Manually change device date to yesterday
2. Send message
3. Change date back to today
4. Check timestamp

**Expected Result:**
- ✅ Shows "Yesterday"
- ✅ Format is clear and readable

### Test 9.4: Absolute Date
**Steps:**
1. Check messages older than 1 day

**Expected Result:**
- ✅ Shows format like "Jan 15"
- ✅ Month abbreviated correctly
- ✅ Date accurate

---

## Feature 10: Image Sharing

### Test 10.1: Selecting Image
**Steps:**
1. In chat, tap photo icon
2. Photo picker should open
3. Select an image

**Expected Result:**
- ✅ Photo picker opens
- ✅ Can browse images
- ✅ Can select image
- ✅ Picker dismisses after selection

### Test 10.2: Uploading Image
**Steps:**
1. Select image
2. Observe upload process

**Expected Result:**
- ✅ Loading indicator shows while uploading
- ✅ Image appears as thumbnail in chat
- ✅ Image clickable to view full size
- ✅ Recipient receives image

### Test 10.3: Viewing Full Image
**Steps:**
1. Tap on image thumbnail
2. Full image should open

**Expected Result:**
- ✅ Full-size image displays
- ✅ Clear and not pixelated
- ✅ Can pinch to zoom
- ✅ Can dismiss back to chat

### Test 10.4: Image Persistence
**Steps:**
1. Send image
2. Close and reopen app
3. Check chat

**Expected Result:**
- ✅ Image still visible
- ✅ Loads from cache or URL
- ✅ No broken image icon

---

## Feature 11: Profile Pictures

### Test 11.1: Uploading Profile Picture
**Steps:**
1. Go to Settings tab
2. Tap "Change Photo"
3. Select image
4. Wait for upload

**Expected Result:**
- ✅ Photo picker opens
- ✅ Loading indicator shows
- ✅ Profile picture updates in Settings
- ✅ No error messages

### Test 11.2: Profile Picture in User List
**Steps:**
1. Alice uploads profile picture
2. In Bob's app, check user list

**Expected Result:**
- ✅ Alice's profile picture appears
- ✅ Picture is circular
- ✅ Good quality, not pixelated
- ✅ Updates within 5 seconds

### Test 11.3: Profile Picture in Chat
**Steps:**
1. Alice has profile picture
2. Bob opens chat with Alice
3. Check next to received messages

**Expected Result:**
- ✅ Alice's profile picture shows next to her messages
- ✅ Picture is small and circular
- ✅ Does NOT show on Bob's own messages

### Test 11.4: Default Avatar
**Steps:**
1. Create new user without profile picture
2. Check user list and chat

**Expected Result:**
- ✅ Default avatar shows (circle with initials)
- ✅ Initials are correct (first letter of first/last name)
- ✅ Background color consistent
- ✅ Initials are white and readable

---

## Performance Testing

### Test P.1: Message Delivery Speed
**Steps:**
1. Send 10 messages from Alice to Bob
2. Measure time from send to receive

**Expected Result:**
- ✅ Average delivery time < 1 second
- ✅ No messages take > 2 seconds
- ✅ Consistent performance

### Test P.2: App Launch Time
**Steps:**
1. Close app completely
2. Reopen app
3. Measure time to main screen

**Expected Result:**
- ✅ Cold launch < 3 seconds
- ✅ Warm launch < 1 second
- ✅ No splash screen hang

### Test P.3: Chat Load Time
**Steps:**
1. Open chat with 100+ messages
2. Measure load time

**Expected Result:**
- ✅ Chat loads < 1 second
- ✅ Scrolling is smooth
- ✅ No lag when scrolling

### Test P.4: Image Upload Speed
**Steps:**
1. Upload 1MB image
2. Measure upload time

**Expected Result:**
- ✅ Upload completes < 5 seconds
- ✅ Progress indicator shows
- ✅ Can send messages while uploading

---

## Edge Cases & Error Handling

### Test E.1: Empty Messages
**Steps:**
1. Try sending empty message
2. Try sending only whitespace

**Expected Result:**
- ✅ Send button disabled when empty
- ✅ Cannot send empty message
- ✅ No error message needed

### Test E.2: Very Long Messages
**Steps:**
1. Type message with 1000+ characters
2. Send message

**Expected Result:**
- ✅ Message sends successfully
- ✅ Text wraps correctly in bubble
- ✅ Readable in both chats
- ✅ No truncation

### Test E.3: Special Characters
**Steps:**
1. Send message with emojis: "Hello 😀🎉"
2. Send message with symbols: "Price: $100 & €50"
3. Send message in different language

**Expected Result:**
- ✅ All characters display correctly
- ✅ Emojis render properly
- ✅ No encoding issues
- ✅ Special characters preserved

### Test E.4: Poor Network Conditions
**Steps:**
1. Use Network Link Conditioner to simulate 3G
2. Send messages
3. Check delivery

**Expected Result:**
- ✅ Messages still deliver (slower)
- ✅ Status indicators update correctly
- ✅ No crashes or errors
- ✅ Queue works properly

### Test E.5: Large Image Upload
**Steps:**
1. Try uploading 10MB image

**Expected Result:**
- ✅ Error message if too large
- ✅ Suggests resizing
- ✅ No crash
- ✅ Can try again with smaller image

---

## Security Testing

### Test S.1: Unauthorized Access
**Steps:**
1. Logout
2. Try accessing protected screens via deep link

**Expected Result:**
- ✅ Redirected to login screen
- ✅ Cannot access user data
- ✅ Cannot send messages

### Test S.2: Cross-User Data Access
**Steps:**
1. Login as Alice
2. Try to access Bob's private chats (via Firebase console or debug)

**Expected Result:**
- ✅ Firestore rules prevent access
- ✅ Error in console if attempted
- ✅ No data leakage

### Test S.3: Firebase Rules Validation
**Steps:**
1. Go to Firebase Console → Firestore → Rules
2. Click "Rules Playground"
3. Test unauthorized read/write

**Expected Result:**
- ✅ Unauthorized reads denied
- ✅ Unauthorized writes denied
- ✅ Rules are properly configured

---

## Final Acceptance Testing

### Scenario 1: Complete User Journey
1. ✅ Register new account
2. ✅ Upload profile picture
3. ✅ View user list
4. ✅ Start chat with user
5. ✅ Send text messages
6. ✅ Send images
7. ✅ Create group
8. ✅ Send group messages
9. ✅ Logout
10. ✅ Login again
11. ✅ All data persists

### Scenario 2: Multi-User Interaction
1. ✅ 3 users online simultaneously
2. ✅ All can see each other's online status
3. ✅ Messages deliver to all participants
4. ✅ Group chat works with all 3
5. ✅ Typing indicators work for all
6. ✅ Read receipts update for all

### Scenario 3: Offline-Online Cycle
1. ✅ Send messages while online
2. ✅ Go offline
3. ✅ Send messages while offline
4. ✅ View cached messages
5. ✅ Go back online
6. ✅ All offline messages sync
7. ✅ No data loss

---

## Test Summary Report

After completing all tests, fill out this summary:

| Feature | Tests Passed | Tests Failed | Notes |
|---------|-------------|-------------|-------|
| Feature 1: Auth | __ / 5 | __ | |
| Feature 2: User List | __ / 4 | __ | |
| Feature 3: Chat UI | __ / 4 | __ | |
| Feature 4: Real-Time | __ / 4 | __ | |
| Feature 5: Offline | __ / 4 | __ | |
| Feature 6: Typing | __ / 4 | __ | |
| Feature 7: Read Receipts | __ / 4 | __ | |
| Feature 8: Group Chat | __ / 5 | __ | |
| Feature 9: Timestamps | __ / 4 | __ | |
| Feature 10: Images | __ / 4 | __ | |
| Feature 11: Profiles | __ / 4 | __ | |
| Performance | __ / 4 | __ | |
| Edge Cases | __ / 5 | __ | |
| Security | __ / 3 | __ | |
| **TOTAL** | **__ / 58** | **__** | |

**Overall Status:** [ ] PASS [ ] FAIL

**Ready for Demo:** [ ] YES [ ] NO

**Ready for Production:** [ ] YES [ ] NO

---

## Bug Reporting Template

If you find bugs during testing, document them like this:

```
Bug ID: BUG-001
Title: [Brief description]
Severity: Critical / High / Medium / Low
Steps to Reproduce:
1. ...
2. ...
3. ...

Expected Result: ...
Actual Result: ...
Screenshots: [Attach if applicable]
Simulator/Device: iPhone 15 Pro, iOS 17.0
User Account: alice@test.com
Date Found: YYYY-MM-DD
Status: Open / In Progress / Fixed / Closed
```

---

**Happy Testing! 🧪**

