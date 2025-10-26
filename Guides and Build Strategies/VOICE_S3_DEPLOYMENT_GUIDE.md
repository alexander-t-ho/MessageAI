# 🚀 Voice Messages S3 & Lambda Deployment Guide

## ✅ What's Ready

### iOS App:
- ✅ Voice recording with waveform
- ✅ Preview with playback
- ✅ Send functionality
- ✅ S3VoiceStorage service ready
- ✅ Long press send button to record

### Backend Scripts Created:
- ✅ `setup-s3-bucket.sh` - Creates and configures S3 bucket
- ✅ `generateUploadUrl.js` - Lambda for pre-signed URLs
- ✅ `deploy-voice-lambdas.sh` - Deploys Lambda
- ✅ `package.json` - Dependencies

---

## 📋 Deployment Steps

### Step 1: Create S3 Bucket

```bash
cd /Users/alexho/MessageAI/backend/voice
chmod +x setup-s3-bucket.sh
./setup-s3-bucket.sh
```

**What This Does:**
- Creates `cloudy-voice-messages-alexho` bucket
- Enables versioning
- Sets 30-day lifecycle (auto-delete old files)
- Configures CORS for uploads
- Blocks public access (uses pre-signed URLs)

**Expected Output:**
```
🪣 Creating S3 bucket for voice messages...
✅ Bucket created: cloudy-voice-messages-alexho
✅ Versioning enabled
✅ Lifecycle policy set (30 day deletion)
✅ CORS configured
✅ Public access blocked (using pre-signed URLs)
🎉 S3 bucket setup complete!
```

---

### Step 2: Deploy Lambda Function

```bash
cd /Users/alexho/MessageAI/backend/voice
chmod +x deploy-voice-lambdas.sh
./deploy-voice-lambdas.sh
```

**What This Does:**
- Installs npm dependencies (@aws-sdk/client-s3, s3-request-presigner)
- Creates IAM role with S3 permissions
- Deploys Lambda function
- Creates function URL (public endpoint)
- Returns the URL to use in iOS app

**Expected Output:**
```
📦 Installing dependencies...
📦 Creating deployment package...
🚀 Deploying Lambda function...
✅ Lambda function deployed: voice-generateUploadUrl_AlexHo
🔗 Creating function URL...

🎉 Deployment complete!

Function Name: voice-generateUploadUrl_AlexHo
Function URL: https://abc123xyz.lambda-url.us-east-1.on.aws/
S3 Bucket: cloudy-voice-messages-alexho

📝 Update S3VoiceStorage.swift with this URL:
   uploadURLEndpoint = "https://abc123xyz.lambda-url.us-east-1.on.aws/"
```

---

### Step 3: Update iOS App with Lambda URL

**File:** `MessageAI/MessageAI/S3VoiceStorage.swift`

**Find line 22:**
```swift
return "https://REPLACE_WITH_YOUR_LAMBDA_URL.lambda-url.us-east-1.on.aws/"
```

**Replace with your actual URL from Step 2:**
```swift
return "https://abc123xyz.lambda-url.us-east-1.on.aws/"
```

---

### Step 4: Test Upload

**In Xcode:**
1. Build and run (Cmd+R)
2. Open any chat
3. Long press send button
4. Record voice message
5. Tap stop
6. Tap send

**Check Console:**
```
📤 Sending voice message:
☁️ Starting S3 upload for voice message
📁 Audio data size: 52340 bytes
🔑 S3 Key: userId/messageId.m4a
🔗 Got pre-signed URL
✅ Voice message uploaded to S3
✅ Voice message with S3 URL sent
```

**If You See:**
```
⚠️ S3 upload not yet configured
📝 Sending as placeholder text for now
```
→ Lambda URL not updated or Lambda not deployed

---

## 🧪 Testing Checklist

### ✅ S3 Bucket
```bash
# Verify bucket exists
aws s3 ls | grep cloudy-voice

# Check bucket configuration
aws s3api get-bucket-lifecycle-configuration \
  --bucket cloudy-voice-messages-alexho

# Should show 30-day expiration rule
```

### ✅ Lambda Function
```bash
# Test Lambda directly
curl -X POST https://YOUR_LAMBDA_URL \
  -H 'Content-Type: application/json' \
  -d '{"userId":"test123","messageId":"msg456","contentType":"audio/m4a"}'

# Expected response:
{
  "success": true,
  "uploadURL": "https://cloudy-voice-messages-alexho.s3.amazonaws.com/...",
  "s3URL": "https://cloudy-voice-messages-alexho.s3.amazonaws.com/test123/msg456.m4a",
  "expiresIn": 300
}
```

### ✅ iOS App
1. Record voice message
2. Check console for S3 upload logs
3. Verify message sent
4. Check S3 bucket for uploaded file

```bash
# List files in S3
aws s3 ls s3://cloudy-voice-messages-alexho/ --recursive
```

---

## 💰 Cost Estimate

### S3 Free Tier (First 12 Months):
- **Storage:** 5 GB/month - FREE
- **PUT Requests:** 2,000/month - FREE
- **GET Requests:** 20,000/month - FREE

### After Free Tier:
- **Storage:** $0.023/GB/month
- **Requests:** ~$0.005/1000 requests
- **Example:** 1,000 voice messages/month = ~$0.50/month

### With 30-Day Auto-Delete:
- Old files automatically deleted
- Keeps storage minimal
- Very low ongoing cost

---

## 🔧 Troubleshooting

### Issue: "Upload URL generation Lambda not yet deployed"
**Solution:** Run Step 2 (deploy-voice-lambdas.sh)

### Issue: "Failed to upload to S3"
**Solution:**
- Check Lambda URL is correct in S3VoiceStorage.swift
- Verify Lambda has S3 permissions
- Check CloudWatch logs

### Issue: "Permission denied"
**Solution:**
- Verify IAM role has S3 permissions
- Check bucket policy
- Ensure CORS is configured

---

## 📝 Files Created

### Backend:
1. `backend/voice/setup-s3-bucket.sh` - S3 bucket creation
2. `backend/voice/generateUploadUrl.js` - Lambda function
3. `backend/voice/package.json` - Dependencies
4. `backend/voice/deploy-voice-lambdas.sh` - Deployment script

### iOS:
1. `S3VoiceStorage.swift` - Upload/download service
2. `VoiceMessageRecorder.swift` - Recording
3. `VoiceMessagePlayer.swift` - Playback
4. `VoiceWaveformView.swift` - Visualization
5. Updated `ChatView.swift` - Full integration
6. Updated `DataModels.swift` - Voice message fields

---

## 🎯 Current Status

**iOS App:** ✅ Complete and working  
**S3 Bucket:** ⏳ Ready to deploy (run setup script)  
**Lambda:** ⏳ Ready to deploy (run deploy script)  
**Integration:** ✅ Code ready, just needs Lambda URL

---

## 🚀 Quick Start

### Deploy Everything:
```bash
# 1. Create S3 bucket
cd /Users/alexho/MessageAI/backend/voice
./setup-s3-bucket.sh

# 2. Deploy Lambda
./deploy-voice-lambdas.sh

# 3. Copy the Function URL from output

# 4. Update S3VoiceStorage.swift line 22 with the URL

# 5. Build and run in Xcode!
```

---

## 🎉 What You'll Get

### Working Voice Messages:
- Record with animated waveform
- Preview with playback
- Upload to S3 automatically
- Send via WebSocket
- Other users can receive and play
- Auto-delete after 30 days
- Free tier eligible!

Ready to deploy! Run the setup scripts and update the Lambda URL! 🚀🎙️
