# MessageAI - AWS Backend Architecture

## 🏗️ AWS Services Architecture

### Overview
Replacing Firebase with AWS services for MessageAI iOS app.

```
┌─────────────────────────────────────────────────────────────┐
│                     iOS App (SwiftUI)                       │
└──────────────────────┬──────────────────────────────────────┘
                       │
                       │ AWS Amplify SDK
                       │
┌──────────────────────┴──────────────────────────────────────┐
│                    AWS Amplify                              │
│  (Client SDK - handles auth, API calls, storage)           │
└──────────────────────┬──────────────────────────────────────┘
                       │
        ┌──────────────┼──────────────┐
        │              │              │
        ▼              ▼              ▼
   ┌─────────┐   ┌─────────┐   ┌─────────┐
   │ Cognito │   │ AppSync │   │   S3    │
   │  Auth   │   │ GraphQL │   │ Storage │
   └─────────┘   └────┬────┘   └─────────┘
                      │
                      ▼
                 ┌─────────┐
                 │DynamoDB │
                 │ Tables  │
                 └─────────┘
```

---

## 📊 Service Mapping

| Feature | Firebase | AWS Replacement |
|---------|----------|----------------|
| **Authentication** | Firebase Auth | AWS Cognito User Pools |
| **Database** | Cloud Firestore | AWS AppSync + DynamoDB |
| **Storage** | Cloud Storage | Amazon S3 |
| **Real-time** | Firestore Listeners | AppSync Subscriptions (GraphQL) |
| **Offline Sync** | Firestore Cache | SwiftData + AppSync Sync |
| **Push Notifications** | FCM | Amazon SNS |

---

## 🗄️ DynamoDB Table Schema

### Table 1: Users
```
Table Name: MessageAI-Users
Primary Key: userId (String)
Attributes:
  - userId: String (PK)
  - email: String
  - displayName: String
  - profilePictureUrl: String
  - isOnline: Boolean
  - lastSeen: Number (Unix timestamp)
  - createdAt: Number (Unix timestamp)
  - deviceToken: String

GSI: email-index (for login queries)
```

### Table 2: Chats
```
Table Name: MessageAI-Chats
Primary Key: chatId (String)
Attributes:
  - chatId: String (PK - format: "userId1_userId2")
  - participants: List<String>
  - participantNames: Map<String, String>
  - lastMessage: String
  - lastMessageTime: Number
  - lastMessageSenderId: String
  - unreadCount: Map<String, Number>
  - typing: Map<String, Number>

GSI: participant-index (Query chats by participant)
  - participantId (PK) + lastMessageTime (SK)
```

### Table 3: Messages
```
Table Name: MessageAI-Messages
Primary Key: chatId (String) + messageId (String)
Sort Key: timestamp (Number)
Attributes:
  - chatId: String (PK)
  - messageId: String (SK)
  - senderId: String
  - senderName: String
  - text: String
  - type: String (text/image/system)
  - imageUrl: String
  - timestamp: Number
  - status: String (sending/sent/delivered/read)

Query Pattern: Get messages by chatId, sorted by timestamp
```

### Table 4: Groups
```
Table Name: MessageAI-Groups
Primary Key: groupId (String)
Attributes:
  - groupId: String (PK)
  - name: String
  - participants: List<String>
  - participantNames: Map<String, String>
  - createdBy: String
  - createdAt: Number
  - lastMessage: String
  - lastMessageTime: Number
  - groupImageUrl: String

GSI: participant-index (Query groups by participant)
```

### Table 5: GroupMessages
```
Table Name: MessageAI-GroupMessages
Primary Key: groupId (String) + messageId (String)
Sort Key: timestamp (Number)
Attributes:
  - groupId: String (PK)
  - messageId: String (SK)
  - senderId: String
  - senderName: String
  - text: String
  - type: String
  - imageUrl: String
  - timestamp: Number
```

---

## 🔄 AppSync GraphQL Schema

### Queries
```graphql
type Query {
  getUser(userId: ID!): User
  listUsers: [User]
  getChat(chatId: ID!): Chat
  listChats(participantId: ID!): [Chat]
  listMessages(chatId: ID!, limit: Int, nextToken: String): MessageConnection
  getGroup(groupId: ID!): Group
  listGroups(participantId: ID!): [Group]
  listGroupMessages(groupId: ID!, limit: Int, nextToken: String): MessageConnection
}
```

### Mutations
```graphql
type Mutation {
  createUser(input: CreateUserInput!): User
  updateUser(input: UpdateUserInput!): User
  updateUserPresence(userId: ID!, isOnline: Boolean!, lastSeen: AWSTimestamp!): User
  
  createChat(input: CreateChatInput!): Chat
  updateTypingStatus(chatId: ID!, userId: ID!, isTyping: Boolean!): Chat
  
  sendMessage(input: SendMessageInput!): Message
  updateMessageStatus(chatId: ID!, messageId: ID!, status: MessageStatus!): Message
  markMessagesAsRead(chatId: ID!, messageIds: [ID!]!): [Message]
  
  createGroup(input: CreateGroupInput!): Group
  sendGroupMessage(input: SendGroupMessageInput!): Message
}
```

### Subscriptions (Real-time)
```graphql
type Subscription {
  onUserPresenceChanged(userId: ID!): User
    @aws_subscribe(mutations: ["updateUserPresence"])
  
  onMessageReceived(chatId: ID!): Message
    @aws_subscribe(mutations: ["sendMessage"])
  
  onMessageStatusUpdated(chatId: ID!): Message
    @aws_subscribe(mutations: ["updateMessageStatus"])
  
  onTypingStatusChanged(chatId: ID!): Chat
    @aws_subscribe(mutations: ["updateTypingStatus"])
  
  onGroupMessageReceived(groupId: ID!): Message
    @aws_subscribe(mutations: ["sendGroupMessage"])
}
```

---

## 🪣 S3 Bucket Structure

### Bucket: messageai-user-content
```
/profile-pictures/
  {userId}.jpg
  {userId}_thumb.jpg

/chat-images/
  {chatId}/
    {imageId}.jpg
    {imageId}_thumb.jpg

/group-images/
  {groupId}.jpg
  {groupId}_thumb.jpg
```

### S3 Configuration
- **Versioning:** Enabled
- **Encryption:** AES-256
- **CORS:** Enabled for iOS app
- **CloudFront:** Optional (for faster delivery)
- **Lambda Triggers:** Auto-generate thumbnails on upload

---

## 🔐 AWS Cognito Setup

### User Pool Configuration
```
User Pool Name: MessageAI-Users
Sign-in Options:
  - Email
  - Username (optional)

Password Policy:
  - Minimum 8 characters
  - Require lowercase, uppercase, numbers

Required Attributes:
  - email
  - name (display name)

Optional Attributes:
  - picture (profile picture URL)

MFA: Optional (can enable later)
```

### App Client
```
App Client Name: MessageAI-iOS
Auth Flows:
  - USER_PASSWORD_AUTH
  - REFRESH_TOKEN_AUTH

Token Expiration:
  - ID Token: 1 hour
  - Access Token: 1 hour
  - Refresh Token: 30 days
```

---

## 🚀 AWS Amplify Configuration

### amplify/backend/api/messageai/schema.graphql
Complete GraphQL schema for AppSync

### amplify/backend/auth/messageai/parameters.json
Cognito configuration

### amplify/backend/storage/messageais3/parameters.json
S3 bucket configuration

---

## 💰 Cost Estimation (MVP - 1000 users)

| Service | Usage | Cost/Month |
|---------|-------|-----------|
| **Cognito** | 1000 MAU | Free (< 50k MAU) |
| **AppSync** | 1M queries | ~$4 |
| **DynamoDB** | 1GB storage, 1M reads/writes | ~$1.25 |
| **S3** | 10GB storage, 10k requests | ~$0.50 |
| **Data Transfer** | 10GB out | ~$0.90 |
| **TOTAL** | | **~$7/month** |

Firebase equivalent: ~$25-50/month for same usage

---

## 📦 iOS Dependencies

### AWS SDK Installation (Swift Package Manager)
```
https://github.com/aws-amplify/amplify-swift
```

### Required Packages:
- AWSPluginsCore
- Amplify
- AWSCognitoAuthPlugin
- AWSAPIPlugin
- AWSS3StoragePlugin
- AWSDataStorePlugin (optional, for offline sync)

---

## 🔄 Migration Plan

### Phase 1: AWS Setup (30 min)
1. Create AWS account
2. Install AWS CLI and Amplify CLI
3. Initialize Amplify project
4. Configure Cognito User Pool
5. Set up AppSync API with DynamoDB
6. Create S3 bucket

### Phase 2: Code Migration (2-3 hours)
1. Replace Firebase SDK with Amplify SDK
2. Update AuthService → CognitoAuthService
3. Update FirestoreService → AppSyncService
4. Update StorageService → S3StorageService
5. Update real-time listeners → GraphQL subscriptions
6. Update SwiftData models for offline sync

### Phase 3: Testing (1 hour)
1. Test authentication flow
2. Test real-time messaging
3. Test offline sync
4. Test image uploads
5. Test group chat

### Phase 4: Deployment
1. Deploy AppSync API
2. Configure S3 CORS
3. Test on physical device
4. Deploy to TestFlight

---

## 🎯 Benefits of AWS over Firebase

### Pros:
✅ **Cost:** ~70% cheaper at scale
✅ **Control:** More granular control over infrastructure
✅ **Scalability:** Better for large-scale apps
✅ **Integration:** Easier to add Lambda functions, Step Functions, etc.
✅ **Data Ownership:** Full control of data in DynamoDB
✅ **GraphQL:** Modern API with strong typing
✅ **Enterprise:** Better for enterprise customers

### Cons:
⚠️ **Complexity:** More setup and configuration
⚠️ **Learning Curve:** Steeper than Firebase
⚠️ **Initial Setup:** Takes longer to get started

---

## 🛠️ Next Steps

1. **Install Amplify CLI:**
   ```bash
   npm install -g @aws-amplify/cli
   amplify configure
   ```

2. **Initialize Amplify in MessageAI:**
   ```bash
   cd /Users/alexho/MessageAI
   amplify init
   ```

3. **Add AWS Services:**
   ```bash
   amplify add auth      # Cognito
   amplify add api       # AppSync + DynamoDB
   amplify add storage   # S3
   amplify push          # Deploy to AWS
   ```

4. **Update iOS Code:**
   - Replace Firebase imports with Amplify
   - Update all service files
   - Test thoroughly

---

Ready to start the migration? 🚀

