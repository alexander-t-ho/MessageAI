# MessageAI - AWS Setup Guide

Complete guide to set up AWS backend for MessageAI iOS app.

## Prerequisites

- AWS Account (create at https://aws.amazon.com)
- Node.js 14+ installed
- Xcode 15+
- iOS 17+ device or simulator

---

## Part 1: Install AWS Amplify CLI

### Step 1: Install Amplify CLI
```bash
# Install Amplify CLI globally
npm install -g @aws-amplify/cli

# Verify installation
amplify --version
```

### Step 2: Configure Amplify with AWS Credentials
```bash
amplify configure
```

This will:
1. Open AWS Console in browser
2. Prompt you to create an IAM user
3. Generate access keys
4. Store credentials locally

**Follow the prompts:**
- Region: `us-east-1` (or your preferred region)
- IAM user name: `amplify-messageai-user`
- Access type: Programmatic access
- Attach policy: `AdministratorAccess-Amplify`

---

## Part 2: Initialize Amplify in MessageAI Project

### Step 3: Initialize Amplify
```bash
cd /Users/alexho/MessageAI
amplify init
```

**Configuration:**
```
? Enter a name for the project: messageai
? Initialize the project with the above configuration? No
? Enter a name for the environment: dev
? Choose your default editor: Visual Studio Code (or your preference)
? Choose the type of app: ios
? Do you want to use an AWS profile? Yes
? Please choose the profile: default
```

This creates:
- `amplify/` directory with configuration
- `amplifyconfiguration.json` for iOS
- `awsconfiguration.json` for iOS

---

## Part 3: Add Authentication (Cognito)

### Step 4: Add Cognito Authentication
```bash
amplify add auth
```

**Configuration:**
```
? Do you want to use the default authentication and security configuration? Default configuration
? How do you want users to be able to sign in? Email
? Do you want to configure advanced settings? No, I am done.
```

This creates:
- Cognito User Pool
- App Client for iOS
- Authentication flows

---

## Part 4: Add API (AppSync + DynamoDB)

### Step 5: Add GraphQL API
```bash
amplify add api
```

**Configuration:**
```
? Select from one of the below mentioned services: GraphQL
? Here is the GraphQL API that we will create. Select a setting to edit: (use default)
? Provide API name: messageai
? Choose the default authorization type for the API: Amazon Cognito User Pool
? Do you want to configure advanced settings? No
? Do you want to edit the schema now? Yes
```

This opens the schema file. Replace it with:

```graphql
# amplify/backend/api/messageai/schema.graphql

type User @model @auth(rules: [
  { allow: owner, ownerField: "id", operations: [read, update] }
  { allow: private, operations: [read] }
]) {
  id: ID!
  email: AWSEmail!
  displayName: String!
  profilePictureUrl: String
  isOnline: Boolean!
  lastSeen: AWSTimestamp!
  createdAt: AWSTimestamp!
  deviceToken: String
  chats: [Chat] @manyToMany(relationName: "ChatParticipants")
  groups: [Group] @manyToMany(relationName: "GroupMembers")
}

type Chat @model @auth(rules: [
  { allow: owner, ownerField: "participants", operations: [read, update] }
]) {
  id: ID!
  participants: [ID!]!
  participantNames: AWSJSON
  lastMessage: String
  lastMessageTime: AWSTimestamp
  lastMessageSenderId: ID
  unreadCount: AWSJSON
  typing: AWSJSON
  messages: [Message] @hasMany(indexName: "byChatId", fields: ["id"])
  users: [User] @manyToMany(relationName: "ChatParticipants")
}

type Message @model @auth(rules: [
  { allow: owner, ownerField: "senderId", operations: [create, read] }
  { allow: private, operations: [read, update] }
]) {
  id: ID!
  chatId: ID! @index(name: "byChatId", sortKeyFields: ["timestamp"])
  groupId: ID @index(name: "byGroupId", sortKeyFields: ["timestamp"])
  senderId: ID!
  senderName: String!
  text: String!
  type: MessageType!
  imageUrl: String
  timestamp: AWSTimestamp!
  status: MessageStatus!
  chat: Chat @belongsTo(fields: ["chatId"])
  group: Group @belongsTo(fields: ["groupId"])
}

enum MessageType {
  TEXT
  IMAGE
  SYSTEM
}

enum MessageStatus {
  SENDING
  SENT
  DELIVERED
  READ
  FAILED
}

type Group @model @auth(rules: [
  { allow: owner, ownerField: "participants", operations: [read, update] }
]) {
  id: ID!
  name: String!
  participants: [ID!]!
  participantNames: AWSJSON
  createdBy: ID!
  createdAt: AWSTimestamp!
  lastMessage: String
  lastMessageTime: AWSTimestamp
  groupImageUrl: String
  messages: [Message] @hasMany(indexName: "byGroupId", fields: ["id"])
  users: [User] @manyToMany(relationName: "GroupMembers")
}

# Custom mutations for real-time features
type Mutation {
  updateUserPresence(userId: ID!, isOnline: Boolean!, lastSeen: AWSTimestamp!): User
  updateTypingStatus(chatId: ID!, userId: ID!, isTyping: Boolean!): Chat
  markMessagesAsRead(chatId: ID!, messageIds: [ID!]!): [Message]
}

# Subscriptions for real-time updates
type Subscription {
  onUserPresenceChanged(userId: ID!): User
    @aws_subscribe(mutations: ["updateUserPresence"])
  onMessageReceived(chatId: ID!): Message
    @aws_subscribe(mutations: ["createMessage"])
  onTypingStatusChanged(chatId: ID!): Chat
    @aws_subscribe(mutations: ["updateTypingStatus"])
}
```

---

## Part 5: Add Storage (S3)

### Step 6: Add S3 Storage
```bash
amplify add storage
```

**Configuration:**
```
? Select from one of the below mentioned services: Content (Images, audio, video, etc.)
? Provide a friendly name for your resource: messageais3
? Provide bucket name: messageai-user-content-dev
? Who should have access: Auth users only
? What kind of access do you want for Authenticated users? create/update, read, delete
? Do you want to add a Lambda Trigger for your S3 Bucket? No
```

This creates:
- S3 bucket for user-uploaded content
- IAM policies for authenticated access
- Automatic thumbnail generation (optional)

---

## Part 6: Deploy to AWS

### Step 7: Push to AWS Cloud
```bash
amplify push
```

This will:
1. Show you all resources to be created
2. Ask for confirmation
3. Deploy everything to AWS
4. Generate iOS configuration files

**Output:**
```
✔ Successfully pulled backend environment dev from the cloud.

Current Environment: dev

| Category | Resource name    | Operation | Provider plugin   |
| -------- | ---------------- | --------- | ----------------- |
| Auth     | messageaiauth    | Create    | awscloudformation |
| Api      | messageai        | Create    | awscloudformation |
| Storage  | messageais3      | Create    | awscloudformation |
```

Press `Y` to continue.

**Deployment takes 5-10 minutes.**

---

## Part 7: Get iOS Configuration Files

### Step 8: Download Configuration
After `amplify push` completes, you'll have:

```
amplifyconfiguration.json
awsconfiguration.json
```

These files contain all AWS resource endpoints and configuration.

---

## Part 8: Add Amplify to iOS Project

### Step 9: Add Amplify Swift Package
In Xcode:

1. File → Add Package Dependencies
2. Enter: `https://github.com/aws-amplify/amplify-swift`
3. Version: Up to Next Major (2.0.0 < 3.0.0)
4. Add Packages:
   - **Amplify**
   - **AWSCognitoAuthPlugin**
   - **AWSAPIPlugin**
   - **AWSS3StoragePlugin**

### Step 10: Add Configuration Files to Xcode
1. Drag `amplifyconfiguration.json` into Xcode project
2. Drag `awsconfiguration.json` into Xcode project
3. Check "Copy items if needed"
4. Ensure target is selected

---

## Part 9: Test AWS Backend

### Step 11: Verify Deployment
```bash
# View deployed resources
amplify status

# Open AWS Console
amplify console
```

**Check in AWS Console:**
- **Cognito:** User Pool created
- **AppSync:** GraphQL API deployed
- **DynamoDB:** Tables created automatically
- **S3:** Bucket created

---

## Part 10: Update iOS Code

Now replace Firebase services with AWS services (see AWS_IMPLEMENTATION.md)

---

## 🔗 AWS Console Quick Links

After deployment, access your resources:

```bash
# Open Cognito
amplify console auth

# Open AppSync
amplify console api

# Open S3
amplify console storage
```

---

## 🧪 Testing

### Test Authentication
```bash
# Create a test user
aws cognito-idp admin-create-user \
  --user-pool-id <your-user-pool-id> \
  --username testuser@example.com \
  --user-attributes Name=email,Value=testuser@example.com Name=name,Value="Test User" \
  --temporary-password TempPass123!
```

### Test GraphQL API
Use AppSync console to test queries:
```graphql
query ListUsers {
  listUsers {
    items {
      id
      displayName
      email
    }
  }
}
```

---

## 💰 Cost Monitoring

### View Current Costs
```bash
# Install AWS CLI
brew install awscli

# View costs
aws ce get-cost-and-usage \
  --time-period Start=2025-10-01,End=2025-10-31 \
  --granularity MONTHLY \
  --metrics "UnblendedCost"
```

**Set Budget Alerts:**
1. Go to AWS Billing Console
2. Set budget: $10/month
3. Add email alert at 80% threshold

---

## 🔐 Security Best Practices

### Enable MFA for AWS Account
1. Go to IAM → Users → Your User
2. Security credentials → Enable MFA
3. Use authenticator app

### Rotate Access Keys
```bash
# List access keys
aws iam list-access-keys

# Create new key
aws iam create-access-key

# Delete old key
aws iam delete-access-key --access-key-id <old-key-id>
```

---

## 🆘 Troubleshooting

**Problem: `amplify push` fails**
```bash
# Check status
amplify status

# View detailed logs
amplify push --verbose
```

**Problem: Authentication doesn't work**
- Check Cognito User Pool is deployed
- Verify `amplifyconfiguration.json` is in Xcode project
- Check iOS app has internet permission

**Problem: GraphQL queries fail**
- Check AppSync API is deployed
- Verify user is authenticated
- Check authorization rules in schema

**Problem: Image upload fails**
- Check S3 bucket exists
- Verify CORS configuration
- Check IAM permissions

---

## 📚 Additional Resources

- **Amplify Docs:** https://docs.amplify.aws
- **AppSync Docs:** https://docs.aws.amazon.com/appsync
- **Cognito Docs:** https://docs.aws.amazon.com/cognito
- **iOS SDK Docs:** https://docs.amplify.aws/lib/q/platform/ios

---

## ✅ Verification Checklist

After completing setup:

- [ ] Amplify CLI installed and configured
- [ ] Amplify project initialized
- [ ] Cognito User Pool deployed
- [ ] AppSync API deployed
- [ ] DynamoDB tables created automatically
- [ ] S3 bucket created
- [ ] Configuration files in Xcode project
- [ ] Amplify Swift packages added
- [ ] Test user can register and login

---

**Total Setup Time:** 30-45 minutes

**You're now ready to use AWS as your MessageAI backend!** 🚀

