# MessageAI Setup Guide

Complete step-by-step guide to set up and run the MessageAI iOS app.

## Prerequisites

- **macOS**: Ventura (13.0) or later
- **Xcode**: 15.0 or later
- **iOS**: 17.0+ (Simulator or physical device)
- **Firebase Account**: Free tier is sufficient
- **Git**: For version control

## Part 1: Development Environment Setup

### Step 1: Install Xcode

1. Open Mac App Store
2. Search for "Xcode"
3. Click "Get" or "Install" (may take 30-60 minutes)
4. After installation, open Xcode
5. Go to **Xcode → Settings → Locations**
6. Ensure "Command Line Tools" is set to your Xcode version

### Step 2: Configure iOS Simulators

1. Open Xcode
2. Go to **Window → Devices and Simulators**
3. Click the **Simulators** tab
4. Click the **"+"** button in the bottom-left
5. Add these simulators:
   - **Simulator Name**: iPhone 15 Pro
   - **Device Type**: iPhone 15 Pro
   - **OS Version**: iOS 17.0 (or latest)
6. Click the **"+"** button again
7. Add second simulator:
   - **Simulator Name**: iPhone 15
   - **Device Type**: iPhone 15
   - **OS Version**: iOS 17.0 (or latest)

### Step 3: Test Xcode Installation

1. In Xcode, go to **File → New → Project**
2. Select **iOS → App**
3. Click **Next**
4. Enter details:
   - **Product Name**: TestApp
   - **Interface**: SwiftUI
   - **Language**: Swift
5. Click **Next** and save anywhere
6. Click the **Play button (▶)** or press **Cmd+R**
7. Wait for simulator to boot (may take 2-3 minutes first time)
8. If you see "Hello, World!" on the simulator, you're all set!
9. Close the project (you don't need it)

## Part 2: Firebase Setup

### Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Sign in with your Google account
3. Click **"Add project"**
4. Enter project name: **MessageAI**
5. Click **Continue**
6. Disable Google Analytics (optional for MVP)
7. Click **Create project**
8. Wait for project creation (~30 seconds)
9. Click **Continue**

### Step 2: Add iOS App to Firebase

1. In Firebase Console, click the **iOS** icon (or + Add app)
2. Register app with:
   - **Bundle ID**: `com.yourname.MessageAI` (replace `yourname` with your name, no spaces)
   - **App nickname**: MessageAI (optional)
   - **App Store ID**: Leave blank
3. Click **Register app**
4. Download `GoogleService-Info.plist`
5. **IMPORTANT**: Save this file somewhere safe (Desktop is fine for now)
6. Click **Next**
7. Skip steps 3-4 (we'll do this later)
8. Click **Continue to console**

### Step 3: Enable Authentication

1. In Firebase Console sidebar, click **Build → Authentication**
2. Click **Get started**
3. Click **Email/Password** provider
4. Toggle **Enable** to ON
5. Click **Save**

### Step 4: Create Firestore Database

1. In Firebase Console sidebar, click **Build → Firestore Database**
2. Click **Create database**
3. Select **Start in production mode** (we'll add rules later)
4. Click **Next**
5. Choose a location (select closest to you):
   - US: `us-central1`
   - Europe: `europe-west1`
   - Asia: `asia-southeast1`
6. Click **Enable**
7. Wait for database creation (~30 seconds)

### Step 5: Set Up Firestore Rules

1. In Firestore Database page, click the **Rules** tab
2. Replace the entire content with the rules from `firestore.rules` file in the project
3. Click **Publish**
4. You should see "Rules updated successfully"

### Step 6: Enable Storage

1. In Firebase Console sidebar, click **Build → Storage**
2. Click **Get started**
3. Click **Next** (accept default security rules)
4. Choose the same location as Firestore
5. Click **Done**

### Step 7: Set Up Storage Rules

1. In Storage page, click the **Rules** tab
2. Replace the entire content with the rules from `storage.rules` file in the project
3. Click **Publish**

## Part 3: Xcode Project Setup

### Step 1: Clone or Create Project

If using Git:
```bash
cd ~/Desktop
git clone https://github.com/yourusername/MessageAI.git
cd MessageAI
```

If you have the files already, just navigate to the directory.

### Step 2: Create Xcode Project

1. Open Xcode
2. Go to **File → New → Project**
3. Select **iOS → App**
4. Click **Next**
5. Enter project details:
   - **Product Name**: MessageAI
   - **Team**: Select your team (or "None")
   - **Organization Identifier**: `com.yourname` (use same as Firebase bundle ID)
   - **Bundle Identifier**: Should show `com.yourname.MessageAI`
   - **Interface**: SwiftUI
   - **Language**: Swift
   - **Storage**: SwiftData
6. Click **Next**
7. Save in the `/Users/alexho/MessageAI` directory
8. Ensure "Create Git repository" is checked
9. Click **Create**

### Step 3: Add GoogleService-Info.plist

1. Find the `GoogleService-Info.plist` file you downloaded earlier
2. Drag it into Xcode's left sidebar (Project Navigator)
3. Drop it in the **MessageAI** folder (same level as `MessageAIApp.swift`)
4. In the dialog that appears:
   - Check **"Copy items if needed"**
   - Ensure **MessageAI target** is checked
5. Click **Finish**

### Step 4: Add Firebase SDK via Swift Package Manager

1. In Xcode, go to **File → Add Package Dependencies**
2. In the search field, enter: `https://github.com/firebase/firebase-ios-sdk`
3. Click **Add Package**
4. Wait for package to resolve (~30 seconds)
5. In the "Choose Package Products" dialog, select:
   - ☑️ **FirebaseAuth**
   - ☑️ **FirebaseFirestore**
   - ☑️ **FirebaseStorage**
   - ☑️ **FirebaseMessaging** (optional, for push notifications)
6. Click **Add Package**
7. Wait for packages to download (~1-2 minutes)

### Step 5: Copy Project Files

Now you need to copy all the Swift files from the MessageAI project into your Xcode project:

1. In Xcode's Project Navigator (left sidebar), right-click on **MessageAI** folder
2. Select **New Group** and name it **Models**
3. Repeat to create these groups:
   - Views
   - ViewModels
   - Services
   - Utils

4. Copy files into each group:
   - Drag `Models/*.swift` files into Models group
   - Drag `Views/*.swift` files into Views group
   - Drag `ViewModels/*.swift` files into ViewModels group
   - Drag `Services/*.swift` files into Services group
   - Drag `Utils/*.swift` files into Utils group

5. For each drag operation:
   - Check **"Copy items if needed"**
   - Ensure **MessageAI target** is checked
   - Click **Finish**

### Step 6: Update Info.plist

1. In Project Navigator, click on **MessageAI** (top blue icon)
2. Select the **MessageAI** target
3. Click the **Info** tab
4. Hover over any row and click the **"+"** button
5. Add these keys:
   - **Privacy - Photo Library Usage Description**
     - Value: "We need access to your photo library to send images in chats."
   - **Privacy - Camera Usage Description**
     - Value: "We need access to your camera to take photos for chats."

### Step 7: Enable Background Modes (Optional)

1. In the same target settings, click **Signing & Capabilities**
2. Click **"+ Capability"**
3. Search for and add **Background Modes**
4. Check:
   - ☑️ **Remote notifications**

## Part 4: Build and Run

### Step 1: Build the Project

1. In Xcode, select a simulator from the device selector (top-left, next to Play button)
   - Choose **iPhone 15 Pro**
2. Press **Cmd+B** to build
3. Wait for build to complete (~30-60 seconds)
4. Check for errors:
   - If there are errors, read them carefully
   - Common issues:
     - Missing Firebase configuration → Check `GoogleService-Info.plist` is added
     - Package errors → Go to **File → Packages → Reset Package Caches**
     - Signing errors → Go to **Signing & Capabilities** and select a team

### Step 2: Run on First Simulator

1. Ensure **iPhone 15 Pro** is selected
2. Press **Cmd+R** or click the **Play button (▶)**
3. Wait for simulator to launch (may take 2-3 minutes first time)
4. App should open showing the login screen

### Step 3: Register First User

1. Click **"Don't have an account? Register"**
2. Enter:
   - **Display Name**: Alice
   - **Email**: alice@test.com
   - **Password**: password123
   - **Confirm Password**: password123
3. Click **Register**
4. You should be logged in and see the "Messages" tab

### Step 4: Run on Second Simulator

1. In Xcode, click the device selector (where it says "iPhone 15 Pro")
2. Select **iPhone 15**
3. Press **Cmd+R** again
4. Second simulator should launch
5. Both simulators should now be running side by side

### Step 5: Register Second User

1. In the second simulator, register a new user:
   - **Display Name**: Bob
   - **Email**: bob@test.com
   - **Password**: password123
   - **Confirm Password**: password123
2. Click **Register**

### Step 6: Test Messaging

1. In **Alice's simulator** (iPhone 15 Pro):
   - Go to **Messages** tab
   - You should see Bob in the "All Users" list
   - Tap on Bob
   - Type a message: "Hi Bob!"
   - Tap send button

2. In **Bob's simulator** (iPhone 15):
   - You should see Alice's message appear instantly
   - Type a reply: "Hello Alice!"
   - Tap send button

3. In **Alice's simulator**:
   - You should see Bob's reply appear instantly

🎉 **Congratulations! Your MessageAI app is working!**

## Part 5: Testing All Features

### Test 1: Online Presence
1. Close Bob's app (swipe up from bottom of simulator)
2. Wait 5 seconds
3. In Alice's simulator, check Bob's status
4. Should show "Offline" with gray dot

### Test 2: Typing Indicators
1. In Alice's chat with Bob
2. Start typing (don't send)
3. In Bob's simulator, open chat with Alice
4. Should see "typing..." indicator

### Test 3: Offline Support
1. In simulator, go to **Settings → Wi-Fi → Turn OFF**
2. Try sending a message
3. Should show "No internet connection" banner
4. Message should show "sending" status
5. Turn Wi-Fi back ON
6. Message should send automatically

### Test 4: Group Chat
1. In Alice's simulator, go to **Groups** tab
2. Tap **"+"** button
3. Enter group name: "Team Chat"
4. Select Bob from user list
5. Tap **Create**
6. Send a message in the group
7. In Bob's simulator, go to Groups tab
8. Tap on "Team Chat"
9. Should see Alice's message

### Test 5: Image Sharing
1. In chat, tap the camera icon
2. Select a photo (simulator has default photos)
3. Wait for upload
4. Image should appear in chat
5. Other user should see the image

### Test 6: Profile Pictures
1. Go to **Settings** tab
2. Tap **"Change Photo"**
3. Select a photo
4. Wait for upload
5. Photo should appear in settings
6. Other user should see your profile picture in user list

## Troubleshooting

### Build Errors

**Error: "Cannot find 'Firebase' in scope"**
- Solution: Go to **File → Packages → Reset Package Caches**, then rebuild

**Error: "GoogleService-Info.plist not found"**
- Solution: Ensure the file is added to the project and "Copy items if needed" was checked

**Error: "Bundle identifier has already been registered"**
- Solution: Change the bundle identifier in Xcode project settings to something unique

### Runtime Errors

**App crashes on launch**
- Check Xcode console for error message
- Verify `GoogleService-Info.plist` bundle ID matches Xcode bundle ID
- Verify Firebase is configured correctly in Firebase Console

**Messages not sending**
- Check Firestore rules are published
- Verify internet connection in simulator
- Check Firebase Console → Firestore → Data to see if collections are being created

**Images not uploading**
- Check Storage rules are published
- Verify Storage is enabled in Firebase Console
- Check file size (should be < 5MB)

### Simulator Issues

**Simulator won't launch**
- Restart Xcode
- Go to **Xcode → Settings → Locations** and reset simulator
- Free up disk space (need at least 10GB)

**Can't run two simulators**
- Check available RAM (need at least 8GB)
- Try using different simulator models
- Close other applications

## Next Steps

- Test all features from the testing checklist in README.md
- Invite more test users
- Customize the UI
- Add more features
- Deploy to TestFlight for beta testing

## Support

If you encounter issues not covered here:
1. Check the README.md file
2. Check Firebase Console for errors
3. Check Xcode console for error messages
4. Search for the error message online
5. Open a GitHub issue with details

---

Happy coding! 🚀

