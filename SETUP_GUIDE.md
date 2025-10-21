# MessageAI Setup Guide - Phase 0

## What You Need to Do Right Now

### 1. Install Xcode (If Not Already Done)

**Steps:**
1. Open **App Store** on your Mac
2. Search for **"Xcode"**
3. Click **"Get"** or **"Install"**
4. Download size: ~7-12 GB (takes 15-20 minutes on fast internet)
5. After download completes, click **"Open"**
6. **Accept** the license agreement
7. Xcode will install additional components (2-3 minutes)
8. Xcode should open to a welcome screen

### 2. After Xcode Installation - Creating Your First iOS Project

Once Xcode is installed and opened:

**Steps:**
1. On the Xcode welcome screen, click **"Create New Project"**
   - Or go to: File → New → Project

2. **Choose Template:**
   - Select **"iOS"** at the top
   - Click **"App"** icon
   - Click **"Next"**

3. **Configure Project:**
   - **Product Name**: `MessageAI`
   - **Team**: Select your Apple ID (or "None" for simulator-only)
   - **Organization Identifier**: `com.yourname` (e.g., `com.alexho`)
   - **Bundle Identifier**: Will auto-fill (e.g., `com.alexho.MessageAI`)
   - **Interface**: Select **"SwiftUI"**
   - **Language**: Select **"Swift"**
   - **Storage**: Select **"SwiftData"**
   - **Include Tests**: ✅ UNCHECK THIS (we'll add tests later)
   - Click **"Next"**

4. **Save Location:**
   - Navigate to: `/Users/alexho/MessageAI`
   - Click **"Create"**

5. **First Build:**
   - You should see Xcode open with your project
   - At the top, there's a device dropdown (might say "Any iOS Device")
   - Click it and select **"iPhone 15 Pro"** (or any iPhone simulator)
   - Click the **Play button (▶️)** or press **Cmd+R**
   - First build takes 2-3 minutes
   - iOS Simulator will launch (looks like an iPhone)
   - You should see "Hello, World!" on the screen

### 3. Enable Developer Mode (If Prompted)

If you see a popup about Developer Mode:
1. Go to **System Preferences** (or System Settings)
2. Click **Privacy & Security**
3. Scroll down to **Developer Mode**
4. Toggle it **ON**
5. Restart your Mac
6. Try running the app again

## What Success Looks Like

✅ **Phase 0 Complete When:**
- Xcode is installed and opens successfully
- You created the MessageAI project
- iOS Simulator launches when you click Run
- You see "Hello, World!" displayed in the simulator
- No error messages in Xcode

## Common Issues

### Issue: "xcode-select: error"
**Solution:**
```bash
sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
sudo xcodebuild -license accept
```

### Issue: Simulator Won't Launch
**Solution:**
```bash
# Open Terminal and run:
xcrun simctl list devices
# This shows available simulators

# If none listed, reset:
xcrun simctl erase all
```

### Issue: "No iOS Simulator Devices"
**Solution:**
1. Xcode → Settings (or Preferences)
2. Click "Platforms" (or "Components")
3. Make sure iOS is installed
4. If not, click "Get" to download iOS simulators

### Issue: Build Failed
**Solution:**
1. Click on the red error icon in the top right
2. Read the error message
3. Common fixes:
   - Clean Build Folder: Product → Clean Build Folder (Cmd+Shift+K)
   - Restart Xcode
   - Restart your Mac

## Next Steps

Once you see "Hello, World!" in the simulator:
1. Take a screenshot or let me know
2. We'll move to **Phase 1: User Authentication**

## Contact Points

**Stop here and verify with me that:**
- [ ] Xcode is installed
- [ ] Project created successfully
- [ ] Simulator shows "Hello, World!"
- [ ] You can see the Xcode interface with your code

---

**Ready to proceed?** Let me know when you see "Hello, World!" in the simulator! 🚀



