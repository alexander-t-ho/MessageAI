# 🔍 Voice Message Debugging Guide

## 🚨 **Current Issue:**
- **Sender:** Cannot play voice messages (shows "0:00" duration)
- **Receiver:** Only sees text placeholders ("🎤 Voice message (0:02)")
- **Missing:** Waveforms and actual audio playback

## 🔍 **Root Cause Analysis:**

### **Likely Issues:**
1. **S3 Upload Failing** → Falls back to placeholder text messages
2. **WebSocket Not Sending Voice Data** → Receivers get text instead of voice messages
3. **Voice Message Creation Issues** → Messages created without proper audio URLs

---

## 🧪 **Debugging Steps:**

### **Step 1: Check S3 Upload Logs**
**When recording a voice message, look for these console logs:**

**✅ Success Pattern:**
```
☁️ Starting S3 upload for voice message
   File URL: file:///path/to/audio.m4a
   User ID: userId123
   Message ID: messageId456
📁 Audio data size: 12345 bytes
🔑 S3 Key: userId123/messageId456.m4a
🔗 Requesting pre-signed URL from Lambda...
🔗 Lambda request details:
   URL: https://45egclkl7gi7f2u5btb7m6ezmm0lvfxh.lambda-url.us-east-1.on.aws/
   User ID: userId123
   Message ID: messageId456
   Content Type: audio/m4a
📤 Calling Lambda function...
📥 Lambda response status: 200
📥 Lambda response parsed:
   Success: true
   Upload URL: https://cloudy-voice-messages-alexho.s3.us-east-1.amazonaws.com/...
   S3 URL: https://cloudy-voice-messages-alexho.s3.us-east-1.amazonaws.com/...
🔗 Got pre-signed URL: https://cloudy-voice-messages-alexho.s3.us-east-1.amazonaws.com/...
📤 Uploading to S3...
📤 S3 upload response: 200
✅ Voice message uploaded to S3 successfully
🔗 S3 URL: https://cloudy-voice-messages-alexho.s3.us-east-1.amazonaws.com/userId123/messageId456.m4a
```

**❌ Failure Pattern:**
```
☁️ Starting S3 upload for voice message
⚠️ S3 upload failed: [error details]
📝 Error details: [specific error]
```

### **Step 2: Check WebSocket Message Logs**
**When sending a voice message, look for:**

**✅ Success Pattern:**
```
📤 Sending GROUP/DIRECT message to recipients
📥 Handling received WebSocket message: messageId
   From: senderId, Current user: receiverId
   Content: 🎤 Voice message (0:03)
   Message Type: voice
   Audio URL: https://cloudy-voice-messages-alexho.s3.us-east-1.amazonaws.com/...
   Duration: 3.0s
```

**❌ Failure Pattern:**
```
📥 Handling received WebSocket message: messageId
   From: senderId, Current user: receiverId
   Content: 🎤 Voice message (0:03)
   Message Type: text
   Audio URL: (missing)
   Duration: (missing)
```

### **Step 3: Check Playback Logs**
**When tapping play button, look for:**

**✅ Success Pattern:**
```
🎵 Playing voice message from: https://cloudy-voice-messages-alexho.s3.us-east-1.amazonaws.com/...
📥 Downloading audio from S3: https://...
🔊 Loaded audio: 3.0s
▶️ Playing audio
✅ Voice message playback started successfully
```

**❌ Failure Pattern:**
```
❌ Voice message has no audio URL
```
or
```
🎵 Playing voice message from: https://...
❌ Voice message playback failed
```

---

## 🔧 **Common Issues & Solutions:**

### **Issue 1: S3 Upload Failing**
**Symptoms:** Console shows "⚠️ S3 upload failed"
**Causes:**
- Network connectivity issues
- Lambda function URL not accessible
- S3 bucket permissions
- Invalid audio file

**Solutions:**
- Check network connection
- Verify Lambda function URL is accessible
- Check S3 bucket exists and has correct permissions

### **Issue 2: WebSocket Sending Text Instead of Voice**
**Symptoms:** Receivers see text placeholders
**Causes:**
- S3 upload failed, falling back to placeholder
- WebSocket not sending voice message fields
- Message processing not handling voice type

**Solutions:**
- Fix S3 upload issue first
- Verify WebSocket sends `messageType: "voice"`
- Check message processing handles voice fields

### **Issue 3: Voice Messages Show "0:00" Duration**
**Symptoms:** Voice bubbles appear but show zero duration
**Causes:**
- Voice message created without proper audio duration
- Audio file not properly recorded
- Duration not passed correctly

**Solutions:**
- Check voice recording is working
- Verify duration is calculated correctly
- Check audio file has valid duration

---

## 🎯 **Expected Behavior:**

### **When Working Correctly:**
1. **Record:** Long press send → Record voice → Send
2. **Console:** Shows successful S3 upload logs
3. **Sender:** Sees voice message bubble with play button
4. **Receiver:** Sees voice message bubble (not text)
5. **Playback:** Tap play → Downloads from S3 → Plays audio

### **Voice Message Bubbles Should Show:**
- **Play/Pause Button:** Circular icon
- **Waveform:** Animated bars (when playing)
- **Duration:** Actual duration (e.g., "0:03")
- **Loading:** Animated bars while downloading

---

## 📱 **Testing Instructions:**

### **Test 1: Record Voice Message**
1. Long press send button
2. Record voice message (2-3 seconds)
3. Send message
4. **Check console** for S3 upload logs

### **Test 2: Check Sender's Message**
1. Look at your own voice message
2. Should show as voice bubble (not text)
3. Tap play button
4. **Check console** for playback logs

### **Test 3: Check Receiver's Message**
1. Switch to another user
2. Should see voice message bubble (not text)
3. Tap play button
4. **Check console** for download/playback logs

---

## 🚨 **Immediate Action Required:**

**Record a voice message and check the console logs. Look for:**

1. **S3 Upload Success:** `✅ Voice message uploaded to S3 successfully`
2. **WebSocket Voice Type:** `Message Type: voice`
3. **Audio URL Present:** `Audio URL: https://...`
4. **Playback Success:** `✅ Voice message playback started successfully`

**Report what you see in the console logs!** 🔍

---

## 📞 **Next Steps:**

1. **Build and run** the app
2. **Record a voice message**
3. **Check console logs** for S3 upload
4. **Test playback** on sender's device
5. **Test with another user** to verify reception
6. **Report any errors** you see in console

**The detailed logging will help identify exactly where the issue is occurring!** 🎯
