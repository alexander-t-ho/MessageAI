# Phase 7: Online/Offline Presence & Typing Indicators

## Implementation Plan

### 1. Presence System (Online/Offline Status)

#### Backend Components:
- **presenceUpdate Lambda** - Broadcasts online/offline status to all connections
- **Heartbeat mechanism** - Client sends periodic pings to maintain online status
- **Disconnect cleanup** - Mark user offline on WebSocket disconnect

#### Client Components:
- **Presence broadcasting** - Send online status on connect, offline on disconnect
- **Heartbeat timer** - Send heartbeat every 30 seconds while connected
- **UI indicators** - Green dot for online, gray for offline

### 2. Typing Indicators

#### Implementation:
1. **Send typing status** - When text field changes
2. **Receive typing status** - Show "User is typing..." below chat header
3. **Auto-timeout** - Clear typing indicator after 3 seconds of inactivity

#### WebSocket Messages:
```json
// Send typing indicator
{
  "action": "typing",
  "conversationId": "xxx",
  "senderId": "xxx",
  "isTyping": true
}

// Receive typing indicator
{
  "type": "typing",
  "data": {
    "conversationId": "xxx",
    "senderId": "xxx",
    "senderName": "User Name",
    "isTyping": true
  }
}
```

### 3. Implementation Steps

1. ✅ Fix presenceUpdate Lambda permissions
2. ⬜ Create typing Lambda handler
3. ⬜ Add heartbeat timer to WebSocketService
4. ⬜ Implement typing indicator send/receive
5. ⬜ Add typing UI to ChatView
6. ⬜ Test presence across multiple devices
7. ⬜ Handle app background/foreground transitions

### 4. Testing Scenarios

- User goes online → Other users see green dot
- User goes offline → Green dot disappears
- User starts typing → "User is typing..." appears
- User stops typing → Indicator disappears after 3 seconds
- App goes to background → User marked offline
- App comes to foreground → User marked online
