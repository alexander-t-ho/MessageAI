# 🌐 **Phase 4, Step 1: WebSocket API Setup**

## 🎯 **Goal**

Create AWS WebSocket API for real-time messaging

**Time:** 30 minutes

---

## 📋 **What We'll Create**

1. WebSocket API Gateway (`MessageAI-WebSocket_AlexHo`)
2. DynamoDB Connections table (`Connections_AlexHo`)
3. Lambda: `websocket-connect_AlexHo`
4. Lambda: `websocket-disconnect_AlexHo`
5. Lambda: `websocket-sendMessage_AlexHo`

---

## 🚀 **Let's Start!**

I'll create automated scripts to set everything up.

### **Files We'll Create:**

1. `backend/websocket/create-websocket-api.sh` - API setup script
2. `backend/websocket/connect.js` - Connection handler
3. `backend/websocket/disconnect.js` - Disconnection handler  
4. `backend/websocket/sendMessage.js` - Message handler
5. `backend/websocket/package.json` - Dependencies
6. `backend/websocket/deploy.sh` - Deployment script

---

## 📦 **What Each Lambda Does**

### **1. onConnect (`connect.js`)**
**Triggered:** When user connects to WebSocket

**Action:**
- Save connection ID + user ID to DynamoDB
- Return success response

**Flow:**
```
User connects → API Gateway → Lambda → Save to Connections table
```

### **2. onDisconnect (`disconnect.js`)**
**Triggered:** When user disconnects from WebSocket

**Action:**
- Remove connection ID from DynamoDB
- Clean up user session

**Flow:**
```
User disconnects → API Gateway → Lambda → Remove from Connections table
```

### **3. sendMessage (`sendMessage.js`)**
**Triggered:** When user sends a message

**Action:**
1. Save message to Messages table (DynamoDB)
2. Find recipient's connection ID
3. Send message to recipient via WebSocket
4. Return delivery status

**Flow:**
```
User sends message → API Gateway → Lambda →
  1. Save to Messages table
  2. Find recipient connection
  3. Send to recipient via WebSocket
  4. Return status
```

---

## 🗄️ **Database Schema**

### **Connections Table**
```json
{
  "connectionId": "abc123",          // Primary key
  "userId": "cognito-user-id",       // User's Cognito ID
  "connectedAt": 1234567890,         // Timestamp
  "ttl": 1234567890                  // Auto-expire after 24h
}
```

**Indexes:**
- **GSI:** `userId-index` (query by user ID)

---

## 🔧 **IAM Permissions Needed**

Lambda functions need:
- `dynamodb:PutItem` (save connection/message)
- `dynamodb:DeleteItem` (remove connection)
- `dynamodb:GetItem` (query connection)
- `dynamodb:Query` (find user connections)
- `execute-api:ManageConnections` (send via WebSocket)

---

## 📝 **Let's Build It!**

I'll create all the scripts now. You'll just need to run them!

Ready? Let me know and I'll generate all the files! 🚀

---

## ⏭️ **Next Steps After This**

Once WebSocket API is set up:
1. Test with Postman (or wscat)
2. Build iOS WebSocket client
3. Connect iOS app to API
4. Send/receive real messages!

---

**Status:** Ready to Create Scripts  
**Time Required:** Script creation: 5 min, Running scripts: 25 min  
**Let me know when you're ready!** 💪

