# 🌐 **WebSocket API - Real-Time Messaging Backend**

## 🎯 **What This Does**

Creates a complete WebSocket API for real-time messaging:
- Users connect via WebSocket
- Messages sent in real-time
- Offline messages saved for later delivery
- Connection management with auto-cleanup

---

## 📁 **Files Created**

### **Lambda Functions**
- `connect.js` - Handles new WebSocket connections
- `disconnect.js` - Handles disconnections
- `sendMessage.js` - Sends messages to recipients

### **Scripts**
- `create-websocket-api.sh` - Creates API Gateway and DynamoDB table
- `deploy.sh` - Deploys Lambda functions and wires everything together
- `package.json` - Node.js dependencies

---

## 🚀 **Setup Instructions**

### **Step 1: Create WebSocket API**

```bash
cd /Users/alexho/MessageAI/backend/websocket
./create-websocket-api.sh
```

**This creates:**
- ✅ `Connections_AlexHo` DynamoDB table (stores active connections)
- ✅ WebSocket API Gateway
- ✅ TTL enabled (auto-cleanup after 24 hours)

**Time:** ~2 minutes

---

### **Step 2: Deploy Lambda Functions**

```bash
./deploy.sh
```

**This does:**
- ✅ Creates IAM role with permissions
- ✅ Installs Node.js dependencies
- ✅ Packages and deploys 3 Lambda functions
- ✅ Creates API routes (\$connect, \$disconnect, sendMessage)
- ✅ Links everything together
- ✅ Deploys to production stage

**Time:** ~5 minutes

---

### **Step 3: Get WebSocket URL**

After deployment, you'll see:

```
📡 WebSocket URL:
   wss://abc123.execute-api.us-east-1.amazonaws.com/production
```

**This URL will be saved to:** `../../websocket-url.txt`

**You'll use this in your iOS app!**

---

## 🏗️ **Architecture**

```
iOS App (User A)
    │
    │ Connect with userId
    ├─────────────────> WebSocket API Gateway
    │                        │
    │                        ├─> connect.js Lambda
    │                        │   └─> Save to Connections table
    │
    │ Send message
    ├─────────────────> sendMessage route
    │                        │
    │                        ├─> sendMessage.js Lambda
    │                        │   ├─> Save to Messages table
    │                        │   ├─> Find recipient connection
    │                        │   └─> Send to recipient
    │                        │
    │                        └──────────────────────────┐
    │                                                    │
    │                                                    ▼
    │                                         iOS App (User B)
    │                                              ▲
    │                                              │
    │                                         Receives message
    │                                         in real-time!
```

---

## 📊 **DynamoDB Tables**

### **Connections_AlexHo**

Stores active WebSocket connections:

| connectionId | userId | connectedAt | ttl |
|-------------|--------|-------------|-----|
| abc123 | user-id-1 | 1234567890 | 1234653890 |
| def456 | user-id-2 | 1234567900 | 1234653900 |

**Indexes:**
- `userId-index` (GSI) - Query connections by user ID

**TTL:** Auto-deletes after 24 hours

---

### **Messages_AlexHo** (Updated)

Stores all messages:

```json
{
  "messageId": "uuid",
  "conversationId": "uuid",
  "senderId": "cognito-user-id",
  "senderName": "John Doe",
  "recipientId": "cognito-user-id",
  "content": "Hello!",
  "timestamp": "2025-10-21T10:30:00Z",
  "status": "sent|delivered|read",
  "isDeleted": false,
  "replyToMessageId": "uuid|null",
  "replyToContent": "...",
  "replyToSenderName": "..."
}
```

---

## 🔌 **How to Connect (iOS)**

### **Connection URL**
```
wss://YOUR-API-ID.execute-api.us-east-1.amazonaws.com/production?userId=COGNITO-USER-ID
```

**Important:** Pass `userId` as query parameter!

### **Sending Messages**

Send JSON with action = "sendMessage":

```json
{
  "action": "sendMessage",
  "messageId": "uuid",
  "conversationId": "uuid",
  "senderId": "sender-cognito-id",
  "senderName": "John Doe",
  "recipientId": "recipient-cognito-id",
  "content": "Hello!",
  "timestamp": "2025-10-21T10:30:00Z"
}
```

### **Receiving Messages**

Your iOS app will receive:

```json
{
  "type": "message",
  "data": {
    "messageId": "uuid",
    "conversationId": "uuid",
    "senderId": "sender-id",
    "senderName": "Jane Doe",
    "content": "Hi back!",
    "timestamp": "2025-10-21T10:31:00Z",
    "status": "delivered"
  }
}
```

---

## 🧪 **Testing**

### **Option 1: Using wscat (Command Line)**

Install wscat:
```bash
npm install -g wscat
```

Connect:
```bash
wscat -c "wss://YOUR-API-ID.execute-api.us-east-1.amazonaws.com/production?userId=test-user-1"
```

Send message:
```json
{"action":"sendMessage","messageId":"test-123","conversationId":"conv-1","senderId":"test-user-1","senderName":"Test User","recipientId":"test-user-2","content":"Hello from wscat!","timestamp":"2025-10-21T10:30:00Z"}
```

### **Option 2: Postman**

1. Create new WebSocket request
2. URL: `wss://YOUR-API-ID.execute-api.us-east-1.amazonaws.com/production?userId=test-user-1`
3. Connect
4. Send JSON message

### **Option 3: iOS App** (Coming Next!)

Build WebSocketService in iOS to connect and send messages!

---

## 🔧 **Troubleshooting**

### **Error: "Internal Server Error"**

Check Lambda logs:
```bash
aws logs tail /aws/lambda/websocket-sendMessage_AlexHo --follow --region us-east-1
```

### **Error: "Forbidden" or "Unauthorized"**

Check API Gateway permissions:
```bash
aws lambda get-policy --function-name websocket-sendMessage_AlexHo --region us-east-1
```

### **Messages not delivering**

1. Check recipient is connected:
```bash
aws dynamodb scan --table-name Connections_AlexHo --region us-east-1
```

2. Check message was saved:
```bash
aws dynamodb scan --table-name Messages_AlexHo --region us-east-1 --limit 5
```

### **Stale connections**

TTL will auto-cleanup after 24 hours. Or manually:
```bash
aws dynamodb delete-item \
    --table-name Connections_AlexHo \
    --key '{"connectionId": {"S": "YOUR-CONNECTION-ID"}}' \
    --region us-east-1
```

---

## 💰 **AWS Costs**

### **Free Tier (12 months)**
- API Gateway: 1 million messages/month
- Lambda: 1 million requests/month
- DynamoDB: 25GB storage, 25 read/write units

### **After Free Tier**
- WebSocket API: $1.00 per million messages
- Lambda: $0.20 per million requests
- DynamoDB: $0.25 per GB/month

**Estimated cost for 10,000 messages/day: ~$0.50/month** 💸

---

## 📋 **Checklist**

After setup, verify:

- [ ] Connections table created (`Connections_AlexHo`)
- [ ] WebSocket API created (API ID saved)
- [ ] 3 Lambda functions deployed
- [ ] API Gateway routes created
- [ ] WebSocket URL obtained
- [ ] Can connect with wscat/Postman
- [ ] Ready to integrate iOS app

---

## ⏭️ **Next Steps**

1. ✅ Backend is ready!
2. 🔜 Create `WebSocketService.swift` (iOS)
3. 🔜 Connect iOS app to WebSocket
4. 🔜 Send/receive real messages
5. 🔜 Test with two devices

---

## 🎉 **What You've Built**

A production-ready real-time messaging backend with:
- ✅ WebSocket connections
- ✅ Real-time message delivery
- ✅ Offline message storage
- ✅ Auto-cleanup (TTL)
- ✅ Scalable architecture
- ✅ Low cost

**Your messaging app is about to become REAL!** 🚀

---

**Questions? Check the main PHASE_4_OVERVIEW.md for more details!**

