# 📲 Phase 9: Push Notifications

## 🎯 Goal
Implement APNs (Apple Push Notifications) so users receive notifications when:
- New messages arrive while app is in background
- Someone mentions them in a group
- They receive a new group invitation
- Important status changes occur

## ✅ Current Status
**Starting Phase 9 on:** October 23, 2025

## 📋 Phase 9 Roadmap

### Part 1: APNs Setup (AWS SNS)
- [ ] Create AWS SNS Platform Application
- [ ] Configure APNs certificates/keys
- [ ] Store device tokens in DynamoDB
- [ ] Test basic push notification delivery

### Part 2: Device Token Management
- [ ] Register device token on app launch
- [ ] Store token in `Connections_AlexHo` table
- [ ] Handle token refresh/updates
- [ ] Remove tokens on logout/app delete

### Part 3: Backend Push Logic
- [ ] Create `sendPushNotification` Lambda
- [ ] Integrate with `sendMessage` Lambda
- [ ] Integrate with `groupCreated` Lambda
- [ ] Handle background/foreground states

### Part 4: Notification Payloads
- [ ] Direct message notifications
- [ ] Group message notifications
- [ ] Typing indicator notifications (optional)
- [ ] Read receipt notifications (optional)

### Part 5: iOS App Integration
- [ ] Request notification permissions
- [ ] Handle notification tap (deep linking)
- [ ] Display notification banners
- [ ] Update badge count

### Part 6: Advanced Features
- [ ] Notification grouping by conversation
- [ ] Custom notification sounds
- [ ] Silent notifications for sync
- [ ] Rich notifications with images

## 🛠️ Technical Requirements

### AWS Services:
- **SNS (Simple Notification Service)** - Push delivery
- **Lambda** - Notification triggers
- **DynamoDB** - Device token storage

### iOS:
- **UserNotifications framework**
- **APNs device token registration**
- **Push certificate from Apple Developer**

### Security:
- **APNs Authentication Key** (preferred) or Certificate
- **Encrypted token storage**
- **Token rotation handling**

## 🔑 Key Considerations

### 1. APNs Setup
- Need Apple Developer account
- Create APNs Key or Certificate
- Configure in AWS SNS

### 2. Notification Types
```swift
{
  "aps": {
    "alert": {
      "title": "John Doe",
      "body": "Hey, how are you?"
    },
    "badge": 1,
    "sound": "default"
  },
  "conversationId": "abc123",
  "senderId": "user456"
}
```

### 3. Background Behavior
- App closed: Show notification
- App background: Show notification
- App foreground: Update UI directly (no notification)

### 4. Deep Linking
- Tap notification → Open specific conversation
- Handle while app is closed/background/foreground

## 📱 Implementation Order

### Step 1: Basic Setup
1. Get APNs key from Apple Developer
2. Create SNS Platform Application
3. Test with a single device

### Step 2: Backend Integration
1. Add device token storage to `connect.js`
2. Create `sendPushNotification.js` Lambda
3. Call from `sendMessage.js` when recipient offline

### Step 3: iOS Integration
1. Request notification permissions
2. Register device token
3. Handle notification tap

### Step 4: Polish
1. Group notifications by conversation
2. Custom sounds
3. Badge count management

## 🧪 Testing Checklist

- [ ] Receive notification when app is closed
- [ ] Receive notification when app is background
- [ ] No notification when app is foreground
- [ ] Tap notification opens correct conversation
- [ ] Badge count updates correctly
- [ ] Group notifications work
- [ ] Notifications clear when messages read

## 📚 Resources Needed

### From Apple:
- [ ] APNs Authentication Key (.p8 file)
- [ ] Team ID
- [ ] Key ID
- [ ] Bundle ID

### AWS Setup:
- [ ] SNS Platform Application ARN
- [ ] Lambda for push sending
- [ ] IAM permissions for SNS

---

**Let's get started with Phase 9!** 🚀

Push notifications are crucial for user engagement - users need to know when they get messages!

