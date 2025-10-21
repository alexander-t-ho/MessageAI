# MessageAI - iOS Messaging App MVP

## Project Overview
Production-quality iOS messaging app using Swift (SwiftUI) and AWS backend with real-time delivery, offline support, and reliable message persistence.

**Tech Stack:**
- **Frontend**: Swift, SwiftUI, SwiftData
- **Backend**: AWS (DynamoDB, Lambda, API Gateway, SNS)
- **Real-time**: WebSocket
- **Auth**: AWS Cognito

## Current Status: Phase 0 - Environment Setup

## Prerequisites
- ✅ AWS CLI installed
- ⏳ Xcode 15+ (installing...)
- ⏳ iOS Simulator configuration
- ⏳ Create Xcode project

## Project Structure
```
MessageAI/
├── MessageAI.xcodeproj     # Xcode project (to be created)
├── MessageAI/              # iOS app source code
│   ├── Models/            # Data models
│   ├── Views/             # SwiftUI views
│   ├── Services/          # Network, Database, WebSocket services
│   └── Resources/         # Assets, Info.plist
├── backend/               # AWS Lambda functions
│   ├── auth/             # Authentication lambdas
│   ├── messages/         # Message handling lambdas
│   └── notifications/    # Push notification lambdas
└── README.md             # This file
```

## Phase Checklist
- [ ] Phase 0: Environment Setup
- [ ] Phase 1: User Authentication
- [ ] Phase 2: Local Data Persistence
- [ ] Phase 3: One-on-One Messaging
- [ ] Phase 4: Real-Time Message Delivery
- [ ] Phase 5: Offline Support & Message Sync
- [ ] Phase 6: Timestamps & Read Receipts
- [ ] Phase 7: Online/Offline Presence & Typing Indicators
- [ ] Phase 8: Group Chat
- [ ] Phase 9: Push Notifications
- [ ] Phase 10: Testing & Deployment

## Setup Instructions

### Step 1: Install Xcode
1. Open App Store → Search "Xcode" → Install
2. Launch Xcode → Agree to license terms
3. Wait for additional components to install

### Step 2: Create Xcode Project
(Instructions will be provided after Xcode installation)

### Step 3: Configure AWS
```bash
aws configure
# Enter your AWS Access Key ID
# Enter your AWS Secret Access Key
# Default region: us-east-1
# Default output format: json
```

## Testing
Instructions for testing each phase will be provided as we progress.

## GitHub Repository
https://github.com/alexander-t-ho/MessageAI

---

**Next Step**: Complete Xcode installation, then we'll create the iOS project!



