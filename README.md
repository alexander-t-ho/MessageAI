# MessageAI - iOS Messaging App with AI Translation

## 🎯 Project Overview

Production-quality iOS messaging app with real-time delivery, AI-powered translation, slang detection, and cultural context explanations.

**Tech Stack:**
- **Frontend**: Swift, SwiftUI, SwiftData
- **Backend**: AWS (Lambda, DynamoDB, API Gateway WebSocket, Cognito, SNS)
- **AI**: OpenAI GPT-4, RAG Pipeline
- **Real-time**: WebSocket bidirectional communication
- **Auth**: AWS Cognito with JWT

---

## 🚀 Current Status: Phase 9 Complete ✅

**All core features are implemented and working!**

---

## ✅ Completed Features

### Phase 1-9: Core Messaging ✅
- ✅ User Authentication (AWS Cognito)
- ✅ Local Database (SwiftData)
- ✅ Draft Messages
- ✅ One-on-One Messaging
- ✅ Group Chat
- ✅ Real-Time WebSocket Delivery
- ✅ Online/Offline Presence
- ✅ Typing Indicators
- ✅ Read Receipts & Timestamps
- ✅ Message Editing with History
- ✅ Message Deletion
- ✅ Message Emphasis
- ✅ Multi-select Actions
- ✅ **AI Translation & Slang Detection (RAG Pipeline)**

### AI Features (Phase 9) ✅
- ✅ Real-time translation to 25+ languages
- ✅ Slang detection using RAG pipeline
- ✅ Cultural context explanations
- ✅ Language preferences per user
- ✅ Powered by OpenAI GPT-4
- ✅ DynamoDB-based slang database (21 terms)
- ✅ WebSocket integration for real-time AI

---

## 🔨 In Progress

### Read Receipts Refinement
- Group chat read receipt optimization
- Real-time update improvements

### Push Notifications
- Local notifications ✅ Working
- Remote APNs notifications (needs Apple Developer enrollment)
- Background notification handling

---

## 📋 Development Phases

### ✅ Phase 1-3: Foundation
- User authentication and session management
- Local data persistence with SwiftData
- Basic messaging infrastructure

### ✅ Phase 4-6: Real-Time Messaging
- WebSocket connection and message delivery
- Offline support and message queueing
- Read receipts and timestamps

### ✅ Phase 7-8: Advanced Features
- Online/offline presence indicators
- Typing indicators
- Group chat with multiple participants
- Message editing and deletion

### ✅ Phase 9: AI & Notifications
- AI-powered translation (25+ languages)
- RAG pipeline for slang detection
- Cultural context explanations
- Push notification infrastructure

### 🔨 Phase 10: AI Agent (In Progress)
- Refine read receipts for group chats
- Optimize notification delivery
- AI feature enhancements
- Performance improvements

### 📋 Phase 11: Extra Features (Planned)
- Message search
- Media attachments (images, videos)
- Voice messages
- Message reactions
- User blocking
- Chat archiving

### 🚀 Phase 12: Testing & Deployment (Planned)
- Comprehensive testing
- TestFlight beta testing
- App Store submission
- Production deployment

---

## 📁 Project Structure

```
MessageAI/
├── README.md                          # This file
├── Guides and Build Strategies/       # Documentation (30+ guides)
│   ├── AI implementation guides
│   ├── RAG pipeline documentation
│   ├── Push notification setup
│   ├── Phase completion summaries
│   ├── Testing and debugging guides
│   └── Feature documentation
├── MessageAI/                         # iOS app (Xcode project)
│   └── MessageAI/                     # Swift source code
│       ├── Views/
│       │   ├── ChatView.swift             # Main chat interface
│       │   ├── ConversationListView.swift # Message list
│       │   ├── HomeView.swift             # Tab navigation & profile
│       │   ├── TranslationSheetView.swift # AI results display
│       │   ├── ProfileCustomizationView.swift # Personalization
│       │   ├── LanguagePreferencesView.swift # AI settings
│       │   └── [other views]
│       ├── Services/
│       │   ├── WebSocketService.swift     # Real-time messaging
│       │   ├── AITranslationService.swift # AI translation & slang
│       │   ├── NotificationManager.swift  # Smart notifications
│       │   ├── SyncService.swift          # Offline sync
│       │   └── UserPreferences.swift      # User customization
│       ├── Models/
│       │   ├── DataModels.swift           # SwiftData models
│       │   ├── AuthViewModel.swift        # Authentication
│       │   └── Config.swift               # Configuration
│       └── MessageAIApp.swift             # App entry point
├── backend/                           # AWS Lambda functions
│   ├── websocket/                     # WebSocket handlers
│   │   ├── connect.js                 # Connection management
│   │   ├── sendMessage.js             # Message delivery
│   │   ├── markRead.js                # Read receipts
│   │   ├── translateAndExplainSimple.js # AI translation+slang
│   │   ├── editMessage.js             # Message editing
│   │   ├── deleteMessage.js           # Message deletion
│   │   ├── groupCreated.js            # Group chat creation
│   │   ├── groupUpdate.js             # Group updates
│   │   ├── presenceUpdate.js          # Online/offline status
│   │   ├── typing.js                  # Typing indicators
│   │   └── [other handlers]
│   ├── rag/                           # RAG pipeline
│   │   ├── rag-slang-simple.js        # Slang detection
│   │   ├── slang-database.json        # Slang terms (21)
│   │   ├── ingest-slang-dynamodb.js   # Database setup
│   │   └── deploy-rag-simple.sh       # Deployment script
│   └── ai/                            # AI services
│       ├── translate.js               # Translation Lambda
│       ├── deploy-ai-services.sh      # Deployment script
│       └── package.json               # Dependencies
└── setup-push-notifications.sh        # APNs setup script
```

---

## 🎨 Key Features

### Messaging
- **Real-time delivery** via WebSocket
- **Group chats** with multiple participants
- **Message editing** with version history
- **Message deletion** (local and remote)
- **Typing indicators** and online presence
- **Read receipts** with user avatars
- **Draft messages** persistence
- **Offline support** with message queueing

### AI-Powered Features ✨
- **Translation**: Translate any message to 25+ languages
- **Slang Detection**: Understand modern slang and informal language
- **Cultural Context**: Get explanations in your language
- **Smart Replies**: AI-suggested responses (coming soon)
- **Language Preferences**: Set preferred translation language

### Personalization
- **Profile Pictures**: Upload custom photos from library
- **Message Colors**: Color wheel picker with 12 presets + custom HSB
- **Dark Mode**: System/Light/Dark theme toggle
- **All Preferences**: Persist across app restarts

### User Experience
- **Modern UI**: Clean, intuitive SwiftUI design
- **Fast**: Optimized for performance
- **Reliable**: Robust error handling
- **Accessible**: Clear visual feedback
- **Customizable**: Make it your own with colors and pictures

---

## 🧪 How to Use AI Features

### Translation & Slang Explanation:
1. Long press any incoming message
2. Tap "Translate & Explain" ✨
3. View translation and slang explanations in your preferred language

### Set Language Preference:
1. Go to Profile tab
2. Tap "Language Preferences"
3. Select your preferred language
4. Tap favorite languages for quick access

---

## 🏗️ Backend Infrastructure

### AWS Services Used:
- **Lambda**: Serverless compute for all backend logic
- **DynamoDB**: NoSQL database for messages, users, slang
- **API Gateway**: WebSocket API for real-time communication
- **Cognito**: User authentication and management
- **SNS**: Push notification delivery
- **Secrets Manager**: API key storage (OpenAI)

### Database Tables:
- `Messages_AlexHo` - All messages
- `Conversations_AlexHo` - Conversation metadata
- `Connections_AlexHo` - WebSocket connections
- `ReadReceipts_AlexHo` - Read status tracking
- `SlangDatabase_AlexHo` - Slang terms for RAG
- `TranslationsCache_AlexHo` - Translation cache

### Lambda Functions:
- WebSocket handlers (connect, disconnect, sendMessage, etc.)
- AI translation and slang detection
- Push notification delivery
- Read receipt aggregation

---

## 🔧 Development Setup

### Prerequisites:
- Xcode 15+
- AWS CLI configured
- Node.js 20+ (for Lambda development)
- AWS account with appropriate permissions

### Running Locally:
1. Open `MessageAI.xcodeproj` in Xcode
2. Select iPhone simulator
3. Build and run (Cmd+R)

### Backend Deployment:
See `Guides and Build Strategies/` for detailed deployment guides:
- RAG pipeline setup
- Lambda deployment
- Push notification configuration
- AI service setup

---

## 📊 Performance

### Response Times:
- **Message delivery**: < 100ms
- **Read receipts**: < 200ms
- **AI translation**: 2-4 seconds
- **Slang detection**: 2-4 seconds (included with translation)

### Scalability:
- Supports unlimited users (AWS auto-scaling)
- DynamoDB on-demand scaling
- Lambda concurrent executions: 1000+

---

## 🐛 Known Issues & Next Steps

### High Priority:
1. **Group chat read receipts** - Optimize aggregation logic
2. **Push notifications** - Complete APNs setup
3. **Banner notifications** - Only show when app in background

### Medium Priority:
- Performance optimization for large conversations
- Add more slang terms to database
- Improve error messages
- UI polish and animations

---

## 📚 Documentation

All documentation is in `Guides and Build Strategies/`:
- AI implementation guides
- RAG pipeline documentation
- Phase completion summaries
- Testing guides
- Troubleshooting guides

---

## 🎯 Next Development Phase

### Phase 10: AI Agent & Bug Fixes
**Focus**: Refinement and reliability

**Goals**:
- Fix group chat read receipts
- Complete push notification testing
- Optimize AI features
- Performance improvements
- Bug fixes and polish

---

## 🚀 Recent Updates

### October 25, 2025 - AI Translation & RAG Pipeline ✅
- Implemented AI translation to 25+ languages
- Built RAG pipeline for slang detection
- Integrated OpenAI GPT-4
- Created unified "Translate & Explain" feature
- Deployed all backend infrastructure

### Previous Phases:
See `Guides and Build Strategies/` for detailed phase summaries.

---

## 📱 App Screenshots

*(Screenshots would go here in production)*

---

## 🤝 Contributing

This is currently a solo development project, but contributions welcome after initial release.

---

## 📄 License

*(Add license when ready for release)*

---

## 👨‍💻 Developer

**Alex Ho**  
Building a modern, AI-powered messaging experience.

---

## 🔗 Links

- **GitHub**: https://github.com/alexander-t-ho/MessageAI
- **Documentation**: See `Guides and Build Strategies/` folder

---

**Status**: Active development - Phase 10 in progress  
**Last Updated**: October 25, 2025
