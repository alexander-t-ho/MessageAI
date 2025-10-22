# Black Screen Troubleshooting Guide

## Current Issue
Simulator shows black screen with no errors when running MessageAI app.

## What We've Tried
1. ✅ Simplified ContentView.swift to basic "Hello World"
2. ✅ Removed SwiftData complexity from MessageAIApp.swift  
3. ✅ Clean Build Folder (Cmd+Shift+K)
4. ✅ Erase simulator content
5. ✅ Added bright RED background to make app visible

## Next Steps to Try

### Step 1: Verify Preview Works
1. Open `ContentView.swift` in Xcode
2. Press **Option+Cmd+Return** to show preview
3. **Question**: Does the preview show red screen on the RIGHT side of Xcode?
   - ✅ YES → Preview works, issue is with simulator
   - ❌ NO → Issue is with Swift code or Xcode setup

### Step 2: Check What's Running
1. Look at top-left of Xcode window
2. Verify it says: **"MessageAI"** > **"iPhone 17 Pro"**
3. If it says something else, click and select:
   - Product: MessageAI
   - Destination: Any iPhone Simulator

### Step 3: Completely Fresh Simulator
```bash
# In Terminal:
xcrun simctl shutdown all
xcrun simctl erase all
```
Then in Xcode:
- Select iPhone 17 Pro again
- Press Cmd+R

### Step 4: Check Scheme Settings
1. In Xcode: **Product → Scheme → Edit Scheme**
2. Click **Run** on left
3. Check **Build Configuration**: Should be "Debug"
4. Check **Executable**: Should be "MessageAI.app"
5. If "Executable" says "Ask on Launch" or "None":
   - Change it to "MessageAI"
   - Click "Close"
   - Try running again (Cmd+R)

### Step 5: Create Minimal Test Project
If nothing works, we'll create a brand new single-file test:

1. In Xcode: File → New → Project
2. iOS → App
3. Name: **"HelloTest"**
4. Interface: SwiftUI
5. Save somewhere else (Desktop)
6. Run it
7. Does it show anything?

## What to Report Back

Please tell me:
1. **Does the Preview work?** (right side of Xcode when viewing ContentView.swift)
2. **What does the Scheme say?** (top-left of Xcode, next to Play button)
3. **What's in the Console?** (bottom panel when you run - any text at all?)
4. **Screenshot**: Can you share a screenshot of Xcode showing:
   - The code editor
   - The console at bottom
   - The simulator window

## Possible Root Causes

### Cause A: Scheme Not Configured
- Xcode might not know which app to launch
- Fix: Edit Scheme and set Executable to MessageAI

### Cause B: Simulator Graphics Issue
- Some Macs have issues with simulator rendering
- Fix: Try different simulator (iPhone SE, iPad)

### Cause C: SwiftUI Preview vs Runtime
- Preview might work but runtime doesn't
- This points to launch/window scene issue

### Cause D: Xcode Installation Issue
- Beta/incomplete Xcode installation
- Fix: Reinstall Xcode or update to latest

## Emergency Workaround: Skip to Backend

If we absolutely cannot get the simulator working:
1. We can start with Phase 1 (AWS Backend setup)
2. Build all the Lambda functions and APIs
3. Come back to iOS app later
4. OR try on a physical iPhone if you have one

But let's exhaust these troubleshooting steps first!

