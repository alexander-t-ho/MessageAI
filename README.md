# MessageAI - iOS Messaging App

A production-quality iOS messaging app with real-time sync, offline support, and group chat capabilities built with SwiftUI and Firebase.

## Features

✅ **Feature 1: User Authentication**
- Email/password registration and login
- Persistent login sessions
- User profile creation with display names
- Secure logout functionality

✅ **Feature 2: User List & Online Presence**
- Real-time user list with online/offline status
- Green dot for online, gray for offline users
- Last seen timestamps
- Instant status updates

✅ **Feature 3: One-on-One Chat UI**
- Modern chat interface with message bubbles
- Sent messages (right, blue) vs received (left, gray)
- Auto-scroll to latest messages
- Timestamp display
- Sender name attribution

✅ **Feature 4: Real-Time Message Delivery**
- Instant message delivery (< 1 second)
- Optimistic UI updates
- Message persistence in Firestore
- Delivery status indicators (sending → sent → delivered → read)

✅ **Feature 5: Message Persistence & Offline Support**
- Local message caching with SwiftData
- Offline message viewing
- Message queue for offline sends
- Automatic sync when reconnecting
- Network status indicator

✅ **Feature 6: Typing Indicators**
- Real-time "typing..." indicator
- Auto-disappears after 3 seconds
- Only visible to chat recipient

✅ **Feature 7: Read Receipts**
- Single checkmark: sent
- Double gray checkmark: delivered
- Double blue checkmark: read
- Real-time status updates

✅ **Feature 8: Basic Group Chat**
- Create groups with 3+ users
- Group name and participant list
- Real-time message delivery to all participants
- Message attribution with sender names
- Group persistence

✅ **Feature 9-12: Polish Features**
- Message timestamps (relative and absolute)
- Image sharing in chats
- Profile pictures
- Settings page with photo upload

## Tech Stack

- **Frontend**: SwiftUI
- **Backend**: Firebase (Firestore, Auth, Storage)
- **Local Storage**: SwiftData
- **Platform**: iOS 17+
- **Language**: Swift

## Project Structure

```
MessageAI/
├── MessageAI/
│   ├── MessageAIApp.swift          # App entry point
│   ├── ContentView.swift           # Root view
│   ├── Models/                     # Data models
│   │   ├── User.swift
│   │   ├── Message.swift
│   │   ├── Chat.swift
│   │   ├── Group.swift
│   │   ├── CachedMessage.swift     # SwiftData model
│   │   ├── CachedChat.swift
│   │   └── CachedUser.swift
│   ├── Views/                      # SwiftUI views
│   │   ├── AuthenticationView.swift
│   │   ├── UserListView.swift
│   │   ├── ChatView.swift
│   │   ├── GroupListView.swift
│   │   ├── GroupChatView.swift
│   │   └── SettingsView.swift
│   ├── ViewModels/                 # Business logic
│   │   ├── AuthViewModel.swift
│   │   ├── UserListViewModel.swift
│   │   ├── ChatViewModel.swift
│   │   └── GroupViewModel.swift
│   ├── Services/                   # Backend services
│   │   ├── AuthService.swift
│   │   ├── FirestoreService.swift
│   │   ├── StorageService.swift
│   │   └── NetworkMonitor.swift
│   └── Utils/                      # Helpers
│       ├── DateFormatters.swift
│       └── AppLifecycleManager.swift
├── Info.plist
└── README.md
```

## Setup Instructions

### Prerequisites

- macOS with Xcode 15+
- iOS 17+ device or simulator
- Firebase account

### Step 1: Clone the Repository

```bash
git clone https://github.com/yourusername/MessageAI.git
cd MessageAI
```

### Step 2: Firebase Setup

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Create a new project named "MessageAI"
3. Add an iOS app with bundle ID: `com.yourname.MessageAI`
4. Download `GoogleService-Info.plist`
5. Add the file to the Xcode project root

### Step 3: Install Dependencies

1. Open `MessageAI.xcodeproj` in Xcode
2. Go to **File → Add Package Dependencies**
3. Add Firebase SDK:
   - URL: `https://github.com/firebase/firebase-ios-sdk`
   - Version: 10.0.0 or later
   - Select packages:
     - FirebaseAuth
     - FirebaseFirestore
     - FirebaseStorage
     - FirebaseMessaging

### Step 4: Configure Firestore Security Rules

In Firebase Console → Firestore Database → Rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users collection
    match /users/{userId} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Chats collection
    match /chats/{chatId} {
      allow read, write: if request.auth != null && 
        request.auth.uid in resource.data.participants;
      
      match /messages/{messageId} {
        allow read: if request.auth != null && 
          request.auth.uid in get(/databases/$(database)/documents/chats/$(chatId)).data.participants;
        allow create: if request.auth != null && 
          request.auth.uid in get(/databases/$(database)/documents/chats/$(chatId)).data.participants;
        allow update: if request.auth != null;
      }
    }
    
    // Groups collection
    match /groups/{groupId} {
      allow read: if request.auth != null && 
        request.auth.uid in resource.data.participants;
      allow create: if request.auth != null;
      allow update: if request.auth != null && 
        request.auth.uid in resource.data.participants;
      
      match /messages/{messageId} {
        allow read: if request.auth != null && 
          request.auth.uid in get(/databases/$(database)/documents/groups/$(groupId)).data.participants;
        allow create: if request.auth != null && 
          request.auth.uid in get(/databases/$(database)/documents/groups/$(groupId)).data.participants;
      }
    }
  }
}
```

### Step 5: Configure Firebase Storage Rules

In Firebase Console → Storage → Rules:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    match /profile_pictures/{userId}/{allPaths=**} {
      allow read: if request.auth != null;
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    match /chat_images/{chatId}/{allPaths=**} {
      allow read, write: if request.auth != null;
    }
    
    match /group_images/{groupId}/{allPaths=**} {
      allow read, write: if request.auth != null;
    }
  }
}
```

### Step 6: Build and Run

1. Select a simulator or connected device
2. Press **Cmd+R** or click the Play button
3. App should build and launch successfully

### Step 7: Testing with Two Simulators

1. Launch first simulator (iPhone 15 Pro)
2. Register a user and stay logged in
3. In Xcode, change device to second simulator (iPhone 15)
4. Run the app again (**Cmd+R**)
5. Register a different user
6. Both users should now be able to message each other

## Testing Checklist

### Feature 1: Authentication
- [x] Register new user with email/password
- [x] Login with existing credentials
- [x] Persistent login after app restart
- [x] Display name saved correctly
- [x] Logout returns to login screen

### Feature 2: User List & Online Presence
- [x] User list displays all users except current user
- [x] Online status shows green dot
- [x] Offline status shows gray dot
- [x] Last seen timestamp displays correctly
- [x] Status updates in real-time

### Feature 3: One-on-One Chat UI
- [x] Chat screen opens from user list
- [x] Message bubbles aligned correctly
- [x] Sent messages on right (blue)
- [x] Received messages on left (gray)
- [x] Auto-scroll to newest message

### Feature 4: Real-Time Message Delivery
- [x] Message appears immediately for sender
- [x] Message appears on recipient within 1 second
- [x] Messages persist after app restart
- [x] Rapid message sending works correctly

### Feature 5: Offline Support
- [x] Cached messages load when offline
- [x] Messages sent offline are queued
- [x] Queued messages send when back online
- [x] No duplicate messages after sync

### Feature 6: Typing Indicators
- [x] Typing indicator shows when user types
- [x] Indicator disappears after 3 seconds
- [x] Sender doesn't see own typing indicator

### Feature 7: Read Receipts
- [x] Sent messages show checkmark
- [x] Delivered messages show double gray checkmark
- [x] Read messages show double blue checkmark
- [x] Status updates in real-time

### Feature 8: Group Chat
- [x] Create group with 3+ users
- [x] All participants receive messages
- [x] Sender name displayed on each message
- [x] Group chat persists after restart

## Performance Benchmarks

- **Message Delivery**: < 1 second
- **App Launch**: < 2 seconds
- **Chat Load Time**: < 500ms
- **Image Upload**: < 5 seconds (1MB image)

## Known Issues

1. Push notifications only work in foreground (background notifications require Cloud Functions)
2. Image compression may reduce quality
3. Network status indicator may have slight delay

## Troubleshooting

### Firebase won't connect
- Verify `GoogleService-Info.plist` is in the project
- Check bundle ID matches Firebase console
- Ensure Firebase SDK packages are installed

### Simulators won't run simultaneously
- Make sure different device types are selected
- Check available disk space (need 10GB+)
- Restart Xcode if simulators freeze

### Messages not syncing
- Check Firestore security rules
- Verify user is authenticated
- Check network connectivity in simulator (Settings → Wi-Fi)

### SwiftData not persisting
- Verify `@Model` macros are applied correctly
- Check `ModelContainer` is configured in App struct
- Ensure proper error handling

## Future Enhancements

- [ ] Voice messages
- [ ] Video calls
- [ ] End-to-end encryption
- [ ] Message search
- [ ] Push notifications (background)
- [ ] Message reactions
- [ ] File sharing
- [ ] Dark mode
- [ ] Custom themes

## License

MIT License - feel free to use this project for learning or as a starting point for your own app.

## Contact

For questions or issues, please open a GitHub issue or contact the development team.

---

Built with ❤️ using SwiftUI and Firebase

