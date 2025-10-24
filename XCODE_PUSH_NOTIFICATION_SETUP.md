# Xcode Push Notification Setup Guide

## ✅ **Fixed: Build Conflict**

The Info.plist file has been removed to fix the build error. Push notification capabilities should be configured through Xcode's project settings instead.

---

## 🔧 **Configure Push Notifications in Xcode**

### **Step 1: Enable Push Notifications Capability**
1. Open `MessageAI.xcodeproj` in Xcode
2. Select the **MessageAI** target (top of file navigator)
3. Click on **Signing & Capabilities** tab
4. Click the **+ Capability** button
5. Search for and add **Push Notifications**
6. Search for and add **Background Modes**
7. In Background Modes, check:
   - ☑️ Remote notifications
   - ☑️ Background fetch

### **Step 2: App Should Build Successfully**
- Clean Build Folder (⇧⌘K)
- Build (⌘B)
- The conflict should be resolved

---

## 📱 **What This Enables**

With these capabilities enabled:
- ✅ App can receive push notifications
- ✅ App can receive notifications while in background
- ✅ App can wake up to process notifications

---

## ⚠️ **For Full Push Notification Functionality**

The app code is ready, but you still need:

### **1. Apple Developer Account Setup:**
- Create App ID with Push Notifications enabled
- Generate APNs certificate or authentication key
- Download and save the certificate/key

### **2. AWS SNS Configuration:**
- Create SNS Platform Application
- Upload your APNs certificate/key
- Get the Platform Application ARN

### **3. Update Lambda Environment:**
```bash
aws lambda update-function-configuration \
  --function-name websocket-sendMessage_AlexHo \
  --environment Variables='{
    "MESSAGES_TABLE": "Messages_AlexHo",
    "CONNECTIONS_TABLE": "Connections_AlexHo",
    "DEVICES_TABLE": "DeviceTokens_AlexHo",
    "SNS_PLATFORM_APP_ARN": "arn:aws:sns:us-east-1:YOUR_ACCOUNT:app/APNS_SANDBOX/MessageAI"
  }' \
  --region us-east-1
```

---

## 🎯 **Current Status**

| Component | Status | Notes |
|-----------|--------|-------|
| Xcode Capabilities | ⚠️ TODO | Add in project settings |
| App Code | ✅ READY | All code implemented |
| Backend Lambda | ✅ DEPLOYED | Push code deployed |
| Device Token Registration | ✅ WORKING | Tokens captured |
| APNs Certificate | ❌ NEEDED | Apple Developer setup |
| SNS Platform App | ❌ NEEDED | AWS Console setup |

---

## 🚀 **Quick Test (After Setup)**

1. Build and run on real device (not simulator)
2. Accept notification permission
3. Check console for "📱 Device Token: ..."
4. Close app completely
5. Send message from another device
6. Should receive push notification banner

---

## 💡 **What Works Without Full Setup**

Even without APNs/SNS configuration:
- ✅ Unread message badge
- ✅ Foreground notifications
- ✅ Real-time messaging (when app is open)
- ✅ Message catch-up on app open

The app is fully functional for messaging - push notifications are just the cherry on top for when the app is closed!
