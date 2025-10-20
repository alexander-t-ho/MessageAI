# Firebase Setup for MessageAI

Your Firebase project is connected! Follow these steps to enable services.

## ✅ Configuration File Added
- **File:** `GoogleService-Info.plist` 
- **Project ID:** messagai-de428
- **Bundle ID:** com.alexho.MessageAI
- **Status:** ✅ Configured

---

## 🔥 Enable Firebase Services

### Step 1: Enable Authentication

1. Go to: https://console.firebase.google.com/u/0/project/messagai-de428/authentication
2. Click **"Get started"**
3. Click **"Email/Password"** provider
4. Toggle **"Enable"** to ON
5. Click **"Save"**

**Test it works:**
- You'll be able to register and login in the app

---

### Step 2: Create Firestore Database

1. Go to: https://console.firebase.google.com/u/0/project/messagai-de428/firestore
2. Click **"Create database"**
3. Select **"Start in production mode"** (we'll add rules next)
4. Choose location: **us-central1** (or closest to you)
5. Click **"Enable"**

---

### Step 3: Set Firestore Security Rules

After creating the database:

1. Click the **"Rules"** tab
2. Replace ALL the content with this:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Helper function to check if user is authenticated
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // Helper function to check if user is participant in chat
    function isParticipant(chatData) {
      return request.auth.uid in chatData.participants;
    }
    
    // Users collection
    match /users/{userId} {
      // Anyone authenticated can read user profiles
      allow read: if isAuthenticated();
      // Users can only write to their own profile
      allow write: if isAuthenticated() && request.auth.uid == userId;
    }
    
    // Chats collection
    match /chats/{chatId} {
      // Users can read/write if they are participants
      allow read, write: if isAuthenticated() && isParticipant(resource.data);
      allow create: if isAuthenticated();
      
      // Messages subcollection
      match /messages/{messageId} {
        // Users can read messages if they are participants in the chat
        allow read: if isAuthenticated() && 
          isParticipant(get(/databases/$(database)/documents/chats/$(chatId)).data);
        
        // Users can create messages if they are participants
        allow create: if isAuthenticated() && 
          isParticipant(get(/databases/$(database)/documents/chats/$(chatId)).data);
        
        // Anyone can update message status (for read receipts)
        allow update: if isAuthenticated();
      }
    }
    
    // Groups collection
    match /groups/{groupId} {
      // Users can read if they are participants
      allow read: if isAuthenticated() && isParticipant(resource.data);
      // Anyone can create a group
      allow create: if isAuthenticated();
      // Participants can update group
      allow update: if isAuthenticated() && isParticipant(resource.data);
      
      // Group messages subcollection
      match /messages/{messageId} {
        // Users can read if they are group participants
        allow read: if isAuthenticated() && 
          isParticipant(get(/databases/$(database)/documents/groups/$(groupId)).data);
        
        // Users can create messages if they are group participants
        allow create: if isAuthenticated() && 
          isParticipant(get(/databases/$(database)/documents/groups/$(groupId)).data);
      }
    }
  }
}
```

3. Click **"Publish"**
4. You should see "Rules updated successfully"

---

### Step 4: Enable Cloud Storage

1. Go to: https://console.firebase.google.com/u/0/project/messagai-de428/storage
2. Click **"Get started"**
3. Select **"Start in production mode"**
4. Use the same location as Firestore
5. Click **"Done"**

---

### Step 5: Set Storage Security Rules

After enabling Storage:

1. Click the **"Rules"** tab
2. Replace ALL the content with this:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // Helper function to check authentication
    function isAuthenticated() {
      return request.auth != null;
    }
    
    // Helper function to check file size (max 5MB)
    function isValidSize() {
      return request.resource.size < 5 * 1024 * 1024;
    }
    
    // Helper function to check if file is an image
    function isImage() {
      return request.resource.contentType.matches('image/.*');
    }
    
    // Profile pictures
    match /profile_pictures/{userId}.jpg {
      // Anyone authenticated can read profile pictures
      allow read: if isAuthenticated();
      // Users can only write to their own profile picture
      allow write: if isAuthenticated() 
        && request.auth.uid == userId 
        && isValidSize() 
        && isImage();
    }
    
    // Chat images
    match /chat_images/{chatId}/{imageId} {
      // Anyone authenticated can read chat images
      allow read: if isAuthenticated();
      // Anyone authenticated can upload chat images (chat permissions handled in Firestore)
      allow write: if isAuthenticated() && isValidSize() && isImage();
    }
    
    // Group images
    match /group_images/{groupId}.jpg {
      // Anyone authenticated can read group images
      allow read: if isAuthenticated();
      // Anyone authenticated can write (group permissions handled in Firestore)
      allow write: if isAuthenticated() && isValidSize() && isImage();
    }
  }
}
```

3. Click **"Publish"**
4. You should see "Rules updated successfully"

---

## ✅ Verification Checklist

After completing all steps:

- [ ] Authentication enabled with Email/Password provider
- [ ] Firestore database created
- [ ] Firestore security rules published
- [ ] Cloud Storage enabled
- [ ] Storage security rules published

---

## 🧪 Test Your Setup

You can now test the app:

1. Open Xcode project
2. Make sure `GoogleService-Info.plist` is in the project
3. Add Firebase packages (if not already):
   - FirebaseAuth
   - FirebaseFirestore
   - FirebaseStorage
4. Run on simulator
5. Register a new user - it should work!

---

## 🔗 Quick Links

- **Firebase Console:** https://console.firebase.google.com/u/0/project/messagai-de428
- **Authentication:** https://console.firebase.google.com/u/0/project/messagai-de428/authentication
- **Firestore:** https://console.firebase.google.com/u/0/project/messagai-de428/firestore
- **Storage:** https://console.firebase.google.com/u/0/project/messagai-de428/storage

---

## 📊 Monitor Your App

After users start using the app, you can monitor:

- **Users:** See registered users in Authentication tab
- **Database:** View messages and chats in Firestore Data tab
- **Storage:** See uploaded images in Storage tab

---

## 🆘 Troubleshooting

**Problem: "Permission denied" errors**
- Make sure security rules are published
- Verify user is authenticated before making requests

**Problem: Can't upload images**
- Check Storage rules are published
- Verify file size is under 5MB
- Make sure file is an image type

**Problem: Messages not saving**
- Check Firestore rules are published
- Verify user is authenticated
- Check console for error messages

---

All set! Your Firebase backend is ready for MessageAI! 🚀

