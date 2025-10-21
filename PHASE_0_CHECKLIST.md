# Phase 0: Environment Setup - Verification Checklist

## Overview
This checklist will help you verify that Phase 0 is complete before we move to Phase 1.

## Status: 🟡 IN PROGRESS

---

## Part 1: Xcode Installation ⏳

### Tasks:
- [ ] **Install Xcode from App Store**
  - Open App Store → Search "Xcode" → Install
  - Size: ~7-12 GB
  - Time: 15-20 minutes download

- [ ] **Launch Xcode**
  - Open Xcode application
  - Accept license agreement
  - Wait for additional components to install

- [ ] **Create MessageAI Project**
  - Click "Create New Project"
  - iOS → App
  - Product Name: `MessageAI`
  - Interface: SwiftUI
  - Language: Swift
  - Storage: SwiftData
  - Uncheck "Include Tests"
  - Save to: `/Users/alexho/MessageAI`

- [ ] **Select iPhone Simulator**
  - Top toolbar: Click device dropdown
  - Select "iPhone 15 Pro" (or any iPhone simulator)

- [ ] **Run First Build**
  - Click Play button (▶️) or press Cmd+R
  - Wait for build (2-3 minutes first time)
  - iOS Simulator should launch
  - You should see "Hello, World!" on screen

### ✅ Success Criteria:
- Xcode opens without errors
- Project builds successfully (no red errors)
- iOS Simulator launches
- "Hello, World!" appears in the simulator
- You can see Xcode with code editor on left, device preview on right

### 📸 Please Share:
- Screenshot of Xcode with your project open
- Screenshot of simulator showing "Hello, World!"

---

## Part 2: AWS CLI Configuration ⏳

### Tasks:
- [ ] **Verify AWS CLI is installed** ✅ (Already done - v2.4.13)

- [ ] **Configure AWS Credentials**
  - Run: `aws configure`
  - Enter Access Key ID
  - Enter Secret Access Key
  - Default region: `us-east-1`
  - Default output format: `json`

- [ ] **Verify Configuration**
  - Run: `aws sts get-caller-identity`
  - Should show your AWS account info

### ✅ Success Criteria:
- `aws sts get-caller-identity` returns your account details
- No "Unable to locate credentials" error

### 📝 Note:
If you don't have AWS credentials yet, see `AWS_SETUP.md` for detailed instructions.

---

## Part 3: Project Structure ✅ (Complete)

Created:
- ✅ `/Users/alexho/MessageAI/` directory
- ✅ `README.md` with project overview
- ✅ `SETUP_GUIDE.md` with step-by-step instructions
- ✅ `AWS_SETUP.md` with AWS configuration help
- ✅ `.gitignore` for Xcode and Node.js
- ✅ `backend/` directory structure for Lambda functions

---

## How to Verify Phase 0 is Complete

### Test 1: Xcode & Simulator
```bash
# From Terminal, check Xcode is properly installed:
xcodebuild -version
```
**Expected**: Should show Xcode version (e.g., "Xcode 15.0")

### Test 2: Run Your App
1. Open Xcode
2. Open MessageAI.xcodeproj
3. Select iPhone 15 Pro simulator
4. Press Cmd+R
5. Wait for simulator to launch
6. See "Hello, World!"

### Test 3: AWS Configuration
```bash
# From Terminal:
cd /Users/alexho/MessageAI
aws sts get-caller-identity
```
**Expected**: JSON output with UserId, Account, and Arn

---

## Phase 0 Complete When:

✅ **All of these are true:**
1. Xcode is installed and launches
2. MessageAI project created in `/Users/alexho/MessageAI/`
3. iOS Simulator shows "Hello, World!" when you run the app
4. AWS CLI is configured (credentials work)
5. No errors in Xcode when building
6. You understand how to:
   - Run the app (Cmd+R)
   - Select different simulators
   - See the code editor and device preview

---

## Common Issues & Quick Fixes

### Xcode Issues:
- **"xcode-select: error"**: Run `sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer`
- **Simulator won't launch**: Run `xcrun simctl erase all` in Terminal
- **Build fails**: Product → Clean Build Folder (Cmd+Shift+K), then build again

### AWS Issues:
- **No credentials**: Run `aws configure` and enter your keys
- **Access denied**: Check IAM user has sufficient permissions
- **Wrong region**: Rerun `aws configure` and set to `us-east-1`

---

## Next Phase Preview

**Phase 1: User Authentication** will involve:
- Creating AWS Cognito User Pool (web console)
- Setting up API Gateway
- Creating Lambda functions for signup/login
- Building Swift authentication views
- Testing login/signup flow

---

## 🛑 STOP HERE 🛑

**Please complete the checklist above and let me know when:**
1. You can see "Hello, World!" in the iOS Simulator
2. AWS CLI is configured (or if you need help with this)

**Share with me:**
- ✅ "Xcode is working, I see Hello World"
- ✅ "AWS is configured" or "I need help with AWS"
- Any errors or issues you encountered

Once you confirm Phase 0 is complete, we'll move to **Phase 1: User Authentication**! 🚀



