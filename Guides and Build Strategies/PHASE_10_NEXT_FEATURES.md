# Phase 10 - Next Features Implementation Guide

## ✅ What's Complete

- ✅ AI Translation & Slang Detection (WORKING!)
- ✅ Group Chat Read Receipts (FIXED!)
- ✅ Smart Notifications
- ✅ Profile Customization (Picture, Color, Dark Mode)
- ✅ Localized Translation Labels
- ✅ Improved GPT-4 prompts (no more "undefined")

---

## 🔨 Next Features to Implement

### 1. Fix "undefined" Slang Meanings ✅ IN PROGRESS
**Status**: Lambda updated, needs testing

**What was done**:
- Improved GPT-4 prompt to ensure actualMeaning is always filled
- Required all fields to be in target language
- Added explicit examples

**To test**:
- Try "I got rizz" again
- Should see Vietnamese translation of "charisma/charm"
- No more "undefined"

---

### 2. User Profile Sync (Colors & Photos)
**Goal**: User's chosen color and photo visible to other users

**Implementation needed**:

#### Backend Changes:
1. Add fields to Users table in DynamoDB:
   - `profilePhotoUrl` (S3 URL or base64)
   - `messageBubbleColor` (hex string)
   - `lastUpdated` (timestamp)

2. Create new Lambda: `updateUserProfile`
   - Update profile photo
   - Update message color
   - Broadcast changes to all user's connections

3. Create S3 bucket for profile photos (optional, better than base64)

#### Frontend Changes:
1. When user updates color/photo:
   - Save locally (UserPreferences)
   - Send to backend via WebSocket
   - Backend stores in Users table

2. When loading conversations:
   - Fetch other users' colors from backend
   - Use their color for their messages
   - Use their photo in profile icons

3. Add `UserProfileCache` service:
   - Cache user colors and photos
   - Refresh periodically
   - Handle updates via WebSocket

**WebSocket Actions to Add**:
```javascript
{
  "action": "updateProfile",
  "userId": "xxx",
  "profilePhotoUrl": "...",
  "messageBubbleColor": "#FF5733"
}

{
  "action": "requestUserProfile",
  "userIds": ["user1", "user2"]
}

// Response
{
  "type": "userProfiles",
  "profiles": {
    "user1": { color: "#...", photoUrl: "..." },
    "user2": { color: "#...", photoUrl: "..." }
  }
}
```

---

### 3. Nickname System (Local Override)
**Goal**: Users can set custom nicknames for others (visible only to them)

**Implementation**:
- ✅ Model created: `UserCustomizationData` (SwiftData)
- ✅ Manager created: `UserCustomizationManager`

**Next steps**:

#### UI to Add:
1. Long press on user's name in chat header → "Set Nickname"
2. Alert with text field to enter nickname
3. Save to SwiftData
4. Display nickname throughout app

#### Code changes:
```swift
// In ChatView header:
.contextMenu {
    Button("Set Nickname") {
        showNicknameAlert = true
    }
}

// Helper function:
func getDisplayName(for userId: String, realName: String) -> String {
    return UserCustomizationManager.shared.getNickname(
        for: userId,
        realName: realName,
        modelContext: modelContext
    )
}

// Use everywhere user name is displayed
```

#### Features:
- Edit nickname for any user
- Reset to real name
- Only visible to you
- Persists across app restarts
- Syncs across your devices (SwiftData)

---

### 4. User Icon with Online Status in Chat Header
**Goal**: Show user's profile icon with green/grey ring for online status

**Design**:
```
┌─────────────────────────┐
│ ← Back  [👤] John Doe 🟢│
│         Online          │
└─────────────────────────┘

Or if offline:
┌─────────────────────────┐
│ ← Back  [👤] John Doe ⚫│
│      Last seen 5m ago   │
└─────────────────────────┘
```

**Implementation**:

#### Chat Header Component:
```swift
struct ChatHeader: View {
    let conversation: ConversationData
    let onlineUserIds: Set<String>
    let lastSeenTimes: [String: Date]
    @StateObject private var customization = UserCustomizationManager.shared
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        HStack {
            // Back button
            Button(action: { /* dismiss */ }) {
                HStack {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
            }
            
            Spacer()
            
            // User info (for 1-on-1) or Group name
            if !conversation.isGroupChat {
                // Profile icon with online status
                ZStack(alignment: .bottomTrailing) {
                    ProfileIcon(userId: otherUserId, size: 36)
                    
                    // Online status indicator
                    Circle()
                        .fill(isOnline ? Color.green : Color.gray)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color.white, lineWidth: 2)
                        )
                }
                
                VStack(spacing: 2) {
                    Text(displayName)
                        .font(.headline)
                    
                    Text(statusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else {
                // Group chat header
                VStack {
                    Text(conversation.name)
                        .font(.headline)
                    Text("\(conversation.participantIds.count) members")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}
```

---

### 5. Last Seen Functionality
**Goal**: Show when user was last online

**Backend**:
Already tracking in `Connections` table via `presenceUpdate`

**Frontend**:
Add `lastSeenTimes` to WebSocketService:
```swift
@Published var lastSeenTimes: [String: Date] = [:]

// Update on presence messages:
if !isOnline, let lastSeen = json["lastSeen"] as? String {
    if let date = ISO8601DateFormatter().date(from: lastSeen) {
        lastSeenTimes[userId] = date
    }
}
```

**Display logic**:
```swift
func lastSeenText(for userId: String) -> String {
    guard let lastSeen = lastSeenTimes[userId] else {
        return "Offline"
    }
    
    let interval = Date().timeIntervalSince(lastSeen)
    
    if interval < 60 {
        return "Last seen a few seconds ago"
    } else if interval < 3600 {
        let minutes = Int(interval / 60)
        return "Last seen \(minutes)m ago"
    } else if interval < 86400 {
        let hours = Int(interval / 3600)
        return "Last seen \(hours)h ago"
    } else {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return "Last seen \(formatter.string(from: lastSeen))"
    }
}
```

---

### 6. Notification Deep Linking
**Goal**: Tapping notification opens specific conversation

**Current State**:
- ✅ Notification has `conversationId` in userInfo
- ✅ NotificationManager posts "OpenConversation" notification
- ⚠️ Need to handle in ConversationListView

**Implementation**:

```swift
// In ConversationListView
.onReceive(NotificationCenter.default.publisher(for: Notification.Name("OpenConversation"))) { notification in
    if let conversationId = notification.userInfo?["conversationId"] as? String {
        // Find the conversation
        if let conv = conversations.first(where: { $0.id == conversationId }) {
            // Navigate to it
            selectedConversation = conv
            showChat = true
        }
    }
}
```

**Alternative using NavigationPath**:
```swift
@State private var navigationPath = NavigationPath()

NavigationStack(path: $navigationPath) {
    // conversation list
}
.onReceive(NotificationCenter.default.publisher(for: Notification.Name("OpenConversation"))) { notification in
    if let conversationId = notification.userInfo?["conversationId"] as? String {
        if let conv = conversations.first(where: { $0.id == conversationId }) {
            navigationPath.append(conv)
        }
    }
}
```

---

## 📋 Implementation Priority

### High Priority (This Session):
1. ✅ Fix "undefined" slang - Lambda updated
2. 🔨 Test slang fix
3. 🔨 Notification deep linking (quick win)
4. 🔨 Add chat header with icons and status

### Medium Priority (Next Session):
5. User profile sync (backend + frontend)
6. Nickname UI implementation
7. Last seen tracking improvements

### Future Enhancements:
- S3 for profile photos (better than UserDefaults)
- Profile photo compression
- Custom ringtones per user
- User blocking
- Mute conversations

---

## 🚀 Quick Wins to Implement Now

### 1. Notification Deep Link (5 minutes)
Add to ContentView or ConversationListView

### 2. Chat Header Status (15 minutes)
Create ChatHeaderView component with icons

### 3. Test Slang Fix (2 minutes)
Try "I got rizz" again - should not show "undefined"

---

## 📝 Files to Create/Modify

### New Files:
- ✅ `UserCustomizationData.swift` (created)
- `ChatHeaderView.swift` (needed)
- `EditNicknameView.swift` (needed)

### Files to Modify:
- `ChatView.swift` - Add header with status
- `ConversationListView.swift` - Handle notification navigation
- `WebSocketService.swift` - Track last seen times
- `MessageAIApp.swift` - Add UserCustomizationData to model container

---

## 🎯 Expected Results

### After All Implementation:

#### Slang Detection:
- "I got rizz" → "Means: Sức quyến rũ" (Vietnamese)
- Never shows "undefined"
- All text in user's language

#### Nicknames:
- Long press name → "Set Nickname"
- Shows custom name everywhere
- Only you see it

#### Profile Sync:
- Your color → Visible to others
- Your photo → Visible to others
- Their updates → You see them

#### Chat Header:
```
┌──────────────────────────┐
│ ← Back   👤 John Doe  🟢 │
│           Online         │
└──────────────────────────┘
```

#### Notifications:
- Tap banner → Opens conversation ✅

---

## 📊 Current Status

**Ready to push**: 88 commits  
**Slang fix**: Deployed, needs testing  
**Nickname foundation**: Complete  
**Remaining**: UI implementation

---

**Next: Test slang fix, then implement remaining UI features!**

