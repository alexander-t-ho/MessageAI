# MessageAI - Quick Start Guide

Get MessageAI running in **15 minutes** or less!

## ⚡ Prerequisites

- ✅ Mac with macOS Ventura+ 
- ✅ Xcode 15+ installed
- ✅ Google/Firebase account (free)

## 🚀 5-Step Setup

### Step 1: Get the Code (1 min)
```bash
cd ~/Desktop
git clone https://github.com/yourusername/MessageAI.git
cd MessageAI
```

### Step 2: Create Firebase Project (3 min)
1. Go to [console.firebase.google.com](https://console.firebase.google.com)
2. Click "Add project" → Name it "MessageAI" → Create
3. Click iOS icon → Bundle ID: `com.yourname.MessageAI`
4. Download `GoogleService-Info.plist` (save to Desktop)

### Step 3: Enable Firebase Services (3 min)
1. **Authentication**: Build → Authentication → Enable Email/Password
2. **Firestore**: Build → Firestore → Create database (production mode)
3. **Storage**: Build → Storage → Get started
4. **Copy Rules**:
   - Firestore Rules: Copy from `firestore.rules` → Publish
   - Storage Rules: Copy from `storage.rules` → Publish

### Step 4: Setup Xcode Project (5 min)
1. Open Xcode
2. File → New → Project → iOS App
   - Name: MessageAI
   - Bundle ID: `com.yourname.MessageAI` (match Firebase)
   - Interface: SwiftUI
   - Storage: SwiftData
3. Drag `GoogleService-Info.plist` into Xcode (check "Copy if needed")
4. File → Add Package Dependencies
   - URL: `https://github.com/firebase/firebase-ios-sdk`
   - Add: FirebaseAuth, FirebaseFirestore, FirebaseStorage
5. Copy all `.swift` files from `MessageAI/` folder into Xcode project

### Step 5: Run! (3 min)
1. Select iPhone 15 Pro simulator
2. Press Cmd+R
3. Register a user (Alice / alice@test.com / password123)
4. Select iPhone 15 simulator → Cmd+R again
5. Register second user (Bob / bob@test.com / password123)
6. Start messaging! 🎉

## 🧪 Quick Test

On **Alice's simulator**:
- Go to Messages tab
- Tap Bob's name
- Send: "Hi Bob!"

On **Bob's simulator**:
- Message appears instantly! ✅
- Reply: "Hello Alice!"

**If you see messages delivering in real-time, everything works!**

## 🆘 Troubleshooting

**Build errors?**
- Reset package cache: File → Packages → Reset Package Caches
- Clean build: Shift+Cmd+K, then Cmd+B

**Firebase not connecting?**
- Check `GoogleService-Info.plist` is in project
- Verify bundle ID matches Firebase console
- Make sure you enabled Auth + Firestore + Storage

**Messages not sending?**
- Check Firestore rules are published
- Check internet connection in simulator
- Look for errors in Xcode console

## 📚 Full Documentation

- **SETUP_GUIDE.md** - Detailed step-by-step (all features)
- **TESTING_GUIDE.md** - 58 test cases
- **FEATURES.md** - Technical implementation
- **README.md** - Project overview

## 🎯 Next Steps

1. ✅ Test all features (use TESTING_GUIDE.md)
2. ✅ Test offline mode (enable Airplane Mode)
3. ✅ Create a group chat with 3 users
4. ✅ Upload profile pictures
5. ✅ Share images in chat
6. ✅ Record a demo video

## 📞 Need Help?

- Check SETUP_GUIDE.md for detailed instructions
- Check TESTING_GUIDE.md for testing procedures
- Look at Xcode console for error messages
- Verify Firebase Console for data

---

**That's it! You now have a working iOS messaging app!** 🚀

Total setup time: ~15 minutes

