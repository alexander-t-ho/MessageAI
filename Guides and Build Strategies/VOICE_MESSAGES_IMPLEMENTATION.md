# 🎙️ Voice Messages Implementation Plan

## 🎯 Overview
Implementing voice messages with S3 storage (free tier) on the AI branch.

## ✅ Branch Status
- **Current Branch:** AI
- **Merged from:** main (Phase 10 features)
- **Merge Conflict:** Resolved ✅
- **Ready:** To implement voice messages

---

## 📋 Implementation Phases

### Phase A: Audio Recording (iOS)
**Goal:** Record audio with hold-to-record button

**Components:**
1. `VoiceMessageRecorder.swift`
   - AVAudioRecorder setup
   - Microphone permissions
   - Recording session management
   - Audio quality settings

2. Recording UI in ChatView
   - Hold-to-record button (microphone icon)
   - Replace send button when holding
   - Visual feedback while recording
   - Cancel by sliding left
   - Send by releasing

**Features:**
- ✅ Hold to record
- ✅ Release to send
- ✅ Slide to cancel
- ✅ Maximum duration (2 minutes)
- ✅ Minimum duration (1 second)

---

### Phase B: S3 Storage Integration
**Goal:** Upload recorded audio to AWS S3

**Components:**
1. `S3VoiceStorage.swift`
   - S3 client configuration
   - Upload voice file
   - Generate pre-signed URLs
   - Download voice file
   - Local caching

2. S3 Bucket Setup
   - Create bucket: `cloudy-voice-messages`
   - Configure permissions
   - Set lifecycle rules (delete after 30 days)
   - Enable CORS

**File Format:**
- Extension: `.m4a` (AAC)
- Naming: `{userId}/{timestamp}_{messageId}.m4a`
- Size limit: 5MB per message

---

### Phase C: Playback System
**Goal:** Play voice messages with controls

**Components:**
1. `VoiceMessagePlayer.swift`
   - AVAudioPlayer setup
   - Playback controls
   - Progress tracking
   - Speed control (1x, 1.5x, 2x)

2. Voice Message Bubble
   - Play/pause button
   - Progress bar
   - Duration display
   - Waveform visualization (optional)
   - Playback speed toggle

---

### Phase D: Data Models & WebSocket
**Goal:** Send/receive voice messages via WebSocket

**Updates Needed:**
1. MessageData Model
   - Add `voiceMessageUrl: String?`
   - Add `voiceMessageDuration: TimeInterval?`
   - Add `isVoiceMessage: Bool`

2. WebSocket Payload
   - Include voice message URL
   - Include duration
   - Trigger download on receive

3. Backend Lambda
   - Store voice message URL in DynamoDB
   - Include in message payload
   - Broadcast to recipients

---

## 🛠️ Technical Stack

### iOS Components:
- **AVFoundation**: Recording and playback
- **AVAudioRecorder**: Audio recording
- **AVAudioPlayer**: Audio playback
- **AVAudioSession**: Audio session management

### AWS Components:
- **S3**: Voice file storage (free tier: 5GB, 20K requests/month)
- **DynamoDB**: Metadata (URLs, durations)
- **Lambda**: Upload pre-signed URL generation
- **CloudFront** (optional): CDN for faster downloads

### Audio Format:
- **Format:** AAC (M4A)
- **Quality:** 64 kbps (good for voice)
- **Sample Rate:** 44.1 kHz
- **Channels:** Mono

---

## 📁 Files to Create

### iOS:
1. `VoiceMessageRecorder.swift` - Recording service
2. `VoiceMessagePlayer.swift` - Playback service  
3. `S3VoiceStorage.swift` - S3 upload/download
4. `VoiceMessageBubble.swift` - UI component
5. `WaveformView.swift` - Waveform visualization (optional)

### Backend:
1. `uploadVoiceMessage.js` - Generate upload URL
2. `getVoiceMessage.js` - Generate download URL
3. Update `sendMessage.js` - Handle voice message type
4. S3 bucket creation script

---

## 🎨 UI Design

### Recording State:
```
┌────────────────────────────┐
│ 🎤 Recording... 0:05       │
│ ← Slide to cancel          │
└────────────────────────────┘
```

### Voice Message Bubble:
```
┌────────────────────────────┐
│ ▶️ ▓▓▓▓▓▓░░░░ 0:15 / 0:45 │
│ 1x speed                   │
└────────────────────────────┘
```

---

## 🚀 Implementation Order

### Step 1: Basic Recording (Today)
- [ ] Create VoiceMessageRecorder
- [ ] Add microphone permission
- [ ] Hold-to-record button in ChatView
- [ ] Local save & playback test

### Step 2: S3 Integration
- [ ] Set up S3 bucket
- [ ] Create upload Lambda
- [ ] Implement S3VoiceStorage service
- [ ] Upload recorded audio

### Step 3: Playback UI
- [ ] Voice message bubble component
- [ ] Play/pause controls
- [ ] Progress slider
- [ ] Duration display

### Step 4: WebSocket Integration
- [ ] Update MessageData model
- [ ] Update sendMessage payload
- [ ] Backend: Store voice URL
- [ ] Receive & download voice messages

### Step 5: Polish
- [ ] Waveform visualization
- [ ] Playback speed control
- [ ] Auto-delete old messages
- [ ] Offline caching

---

## 💡 Free Storage Strategy

### S3 Free Tier:
- **Storage:** 5 GB/month (first 12 months)
- **GET Requests:** 20,000/month
- **PUT Requests:** 2,000/month

### Optimization:
- Compress audio (64 kbps AAC)
- Delete files after 30 days (lifecycle rule)
- Cache downloaded files locally
- Limit max duration (2 minutes)

### Cost After Free Tier:
- **Storage:** $0.023/GB/month (~$0.10/month for 100 messages)
- **Requests:** Minimal cost
- **Very affordable!**

---

## 🧪 Testing Plan

### Test 1: Recording
- Hold microphone button
- Speak for 5 seconds
- Release to send
- Verify audio saved

### Test 2: Upload
- Record message
- Check S3 bucket
- Verify file uploaded
- Check URL generated

### Test 3: Playback
- Receive voice message
- Tap play button
- Verify audio plays
- Check progress bar

### Test 4: Integration
- Send from Device A
- Receive on Device B
- Download and play
- Verify all features work

---

## 🎯 Success Criteria

### MVP (Minimum Viable Product):
- ✅ Record audio (hold button)
- ✅ Upload to S3
- ✅ Send via WebSocket
- ✅ Receive and download
- ✅ Play audio
- ✅ Show duration

### Nice to Have:
- Waveform visualization
- Playback speed control
- Transcript (future: whisper AI)
- Auto-play next message

---

## 📝 Ready to Start!

**Current Status:**
- ✅ On AI branch
- ✅ Merged Phase 10 features
- ✅ Conflict resolved
- ✅ Ready to code

**Next:**
Let's start with Phase A - Audio Recording!

I'll create the VoiceMessageRecorder service first. Ready? 🚀
