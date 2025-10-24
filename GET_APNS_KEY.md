# Get Apple Push Notification Service (APNs) Key

## 🍎 **Step-by-Step Guide**

### **Step 1: Log into Apple Developer**
1. Go to [https://developer.apple.com/account](https://developer.apple.com/account)
2. Sign in with your Apple Developer credentials
3. Navigate to **Certificates, Identifiers & Profiles**

### **Step 2: Create APNs Authentication Key**
1. Click on **Keys** in the left sidebar
2. Click the **+** button (Create a Key)
3. Enter a name: `MessageAI APNs Key`
4. Check the box for **Apple Push Notifications service (APNs)**
5. Click **Continue**
6. Click **Register**
7. **IMPORTANT:** Download the `.p8` file immediately
   - ⚠️ You can only download this once!
   - Save it in a secure location (like `~/Downloads/AuthKey_XXXXXXXXXX.p8`)
8. Note down:
   - **Key ID** (10 characters, e.g., `ABC123XYZ9`)
   - **Team ID** (found in top right corner of the page, e.g., `12345ABCDE`)

### **Step 3: Create App ID (if not exists)**
1. Click on **Identifiers** in the left sidebar
2. Click the **+** button
3. Select **App IDs** and click **Continue**
4. Select **App** and click **Continue**
5. Fill in:
   - **Description:** `MessageAI`
   - **Bundle ID:** `com.messageai.app` (or your custom bundle ID)
6. Scroll down and check **Push Notifications**
7. Click **Continue** then **Register**

### **Step 4: Run Setup Script**
Now that you have the APNs key, run the setup script:

```bash
cd /Users/alexho/MessageAI
./setup-push-notifications.sh
```

When prompted:
- Answer **y** (yes, you have the .p8 file)
- Enter path: `~/Downloads/AuthKey_XXXXXXXXXX.p8` (your actual file path)
- Enter Key ID: `ABC123XYZ9` (from Step 2)
- Enter Team ID: `12345ABCDE` (from Step 2)

The script will:
- ✅ Create AWS SNS Platform Application
- ✅ Update Lambda function with SNS ARN
- ✅ Grant necessary IAM permissions
- ✅ Configure everything automatically

---

## 🔑 **What You Need:**
- `.p8` file path
- Key ID (10 characters)
- Team ID (10 characters)

## 📝 **Example:**
```
File: ~/Downloads/AuthKey_ABC123XYZ9.p8
Key ID: ABC123XYZ9
Team ID: 12345ABCDE
```

---

## ⚠️ **Important Notes:**

### **Sandbox vs Production**
For development/testing:
- Use **APNS_SANDBOX** (automatically configured)
- Test on real iOS devices
- Works with Xcode builds

For App Store release:
- Switch to **APNS** (production)
- Update SNS Platform Application

### **Xcode Configuration**
After running the script, in Xcode:
1. Select MessageAI target
2. Go to **Signing & Capabilities**
3. Add **Push Notifications** capability
4. Add **Background Modes** capability
5. Check **Remote notifications**

### **Bundle ID Must Match**
Ensure your Xcode Bundle ID matches the one in Apple Developer:
1. In Xcode: MessageAI target → General → Bundle Identifier
2. Should match: `com.messageai.app` (or your custom ID)

---

## 🧪 **Testing Push Notifications:**

1. **Build on Real Device** (simulator doesn't support push)
2. **Accept Notification Permission** when prompted
3. **Close the app completely**
4. **Send message from another device**
5. **See notification banner appear!** 🎉

---

## 🆘 **Troubleshooting:**

### Device Token Not Appearing?
- Check console for "📱 Device Token: ..."
- Ensure you accepted notification permission
- Restart app if needed

### Notifications Not Arriving?
- Verify Lambda environment has `SNS_PLATFORM_APP_ARN`
- Check CloudWatch logs for errors
- Ensure app is completely closed (not just in background)

### Invalid Credentials Error?
- Verify Key ID and Team ID are correct
- Ensure .p8 file is from correct Apple Developer account
- Check Bundle ID matches in Xcode and Apple Developer

---

## 📚 **Additional Resources:**
- [Apple: Establishing a Token-Based Connection](https://developer.apple.com/documentation/usernotifications/setting_up_a_remote_notification_server/establishing_a_token-based_connection_to_apns)
- [AWS: SNS Mobile Push](https://docs.aws.amazon.com/sns/latest/dg/sns-mobile-application-as-subscriber.html)

Ready to set up? Run: `./setup-push-notifications.sh` 🚀
