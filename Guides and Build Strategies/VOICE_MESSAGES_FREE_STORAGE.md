# Voice Messages with Free Storage - Implementation Guide

## 💰 Cost-Free Solution: Base64 in DynamoDB

Instead of S3, we'll store audio as **base64 strings** directly in DynamoDB.

### Pros:
- ✅ **100% Free** (within DynamoDB free tier)
- ✅ **No extra setup** (no S3 bucket needed)
- ✅ **Simpler architecture** (one less service)
- ✅ **Works for short voice messages** (< 1 minute)

### Limits:
- DynamoDB item size limit: 400 KB
- Good for ~30-60 second voice messages
- Longer messages can be compressed

---

## 🏗️ Architecture (Simplified)

### Frontend → Backend Flow:
```
1. User records voice (AVAudioRecorder)
2. iOS encodes audio to base64
3. Send via WebSocket with base64 string
4. Backend transcribes using OpenAI Whisper
5. Backend stores:
   - audioBase64 in Messages table
   - transcript text
6. Recipient receives:
   - base64 audio (decode and play)
   - transcript text
```

### No S3 Needed!
- Audio stored directly in message record
- Decode base64 → Play audio
- Free and simple!

---

## 📊 Data Structure

### MessageData (SwiftData):
```swift
var messageType: String? // "voice"
var audioUrl: String? // Actually stores base64 string
var audioDuration: Double? // Seconds
var transcript: String? // From Whisper
var isTranscribing: Bool
```

### DynamoDB Messages:
```javascript
{
  messageId: "xxx",
  messageType: "voice",
  audioBase64: "data:audio/m4a;base64,AAAA...", // Actual audio data
  audioDuration: 5.3,
  transcript: "Hello, how are you?",
  content: "[Voice Message]" // Fallback text
}
```

---

## 🎤 Frontend Implementation

### AudioRecordingService.swift
```swift
import AVFoundation

class AudioRecordingService: ObservableObject {
    @Published var isRecording = false
    @Published var recordingDuration: TimeInterval = 0
    
    private var audioRecorder: AVAudioRecorder?
    
    func startRecording() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("recording.m4a")
        
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue,
            AVEncoderBitRateKey: 32000 // Lower bitrate for smaller files
        ]
        
        audioRecorder = try AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.record()
        isRecording = true
    }
    
    func stopRecording() -> Data? {
        audioRecorder?.stop()
        isRecording = false
        
        if let url = audioRecorder?.url {
            return try? Data(contentsOf: url)
        }
        return nil
    }
    
    func getBase64Audio() -> String? {
        guard let audioData = stopRecording() else { return nil }
        return audioData.base64EncodedString()
    }
}
```

### Send Voice Message:
```swift
// In ChatView
func sendVoiceMessage(audioBase64: String, duration: Double) {
    webSocketService.sendVoiceMessage(
        conversationId: conversation.id,
        senderId: currentUserId,
        senderName: currentUserName,
        audioBase64: audioBase64,
        audioDuration: duration
    )
}
```

---

## 🔧 Backend Implementation

### Lambda: transcribeVoice.js
```javascript
const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, PutCommand } = require("@aws-sdk/lib-dynamodb");
const { SecretsManagerClient, GetSecretValueCommand } = require("@aws-sdk/client-secrets-manager");
const FormData = require('form-data');
const fetch = require('node-fetch');

const docClient = DynamoDBDocumentClient.from(new DynamoDBClient({}));
const secretsClient = new SecretsManagerClient({});

async function transcribeAudio(audioBase64, apiKey) {
  // Decode base64
  const audioBuffer = Buffer.from(audioBase64, 'base64');
  
  // Create form data for Whisper API
  const formData = new FormData();
  formData.append('file', audioBuffer, {
    filename: 'audio.m4a',
    contentType: 'audio/m4a'
  });
  formData.append('model', 'whisper-1');
  
  const response = await fetch('https://api.openai.com/v1/audio/transcriptions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${apiKey}`,
      ...formData.getHeaders()
    },
    body: formData
  });
  
  const data = await response.json();
  return data.text; // Transcribed text
}

exports.handler = async (event) => {
  const body = JSON.parse(event.body);
  const { messageId, audioBase64, audioDuration } = body;
  
  // Get OpenAI API key
  const secretResponse = await secretsClient.send(
    new GetSecretValueCommand({ SecretId: "openai-api-key-alexho" })
  );
  const apiKey = JSON.parse(secretResponse.SecretString).apiKey;
  
  // Transcribe
  const transcript = await transcribeAudio(audioBase64, apiKey);
  
  // Store in DynamoDB
  await docClient.send(new PutCommand({
    TableName: "Messages_AlexHo",
    Item: {
      messageId,
      messageType: "voice",
      audioBase64, // Store the base64 string
      audioDuration,
      transcript,
      timestamp: new Date().toISOString()
    }
  }));
  
  return {
    statusCode: 200,
    body: JSON.stringify({
      success: true,
      transcript
    })
  };
};
```

---

## 🎨 UI Component: VoiceMessageBubble

```swift
import SwiftUI
import AVFoundation

struct VoiceMessageBubble: View {
    let message: MessageData
    @State private var isPlaying = false
    @State private var showTranscript = false
    @State private var player: AVAudioPlayer?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Play/Pause button
                Button(action: { togglePlayback() }) {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                }
                
                // Waveform placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.blue.opacity(0.3))
                    .frame(height: 32)
                
                // Duration
                Text(formatDuration(message.audioDuration ?? 0))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Transcript
            if let transcript = message.transcript {
                Divider()
                
                Button(action: { showTranscript.toggle() }) {
                    HStack {
                        Image(systemName: "text.bubble")
                        Text(showTranscript ? "Hide" : "Show Transcript")
                        Spacer()
                        Image(systemName: showTranscript ? "chevron.up" : "chevron.down")
                    }
                    .font(.caption)
                }
                
                if showTranscript {
                    Text(transcript)
                        .font(.callout)
                        .padding(.top, 4)
                }
            } else if message.isTranscribing {
                HStack {
                    ProgressView().scaleEffect(0.8)
                    Text("Transcribing...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
    }
    
    private func togglePlayback() {
        if isPlaying {
            player?.stop()
            isPlaying = false
        } else {
            playAudio()
        }
    }
    
    private func playAudio() {
        guard let audioBase64 = message.audioUrl,
              let audioData = Data(base64Encoded: audioBase64) else { return }
        
        do {
            player = try AVAudioPlayer(data: audioData)
            player?.play()
            isPlaying = true
            
            // Auto-stop when done
            DispatchQueue.main.asyncAfter(deadline: .now() + (message.audioDuration ?? 0)) {
                isPlaying = false
            }
        } catch {
            print("Error playing audio: \(error)")
        }
    }
    
    private func formatDuration(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}
```

---

## 💰 Cost Comparison

### Option 1: Base64 in DynamoDB (FREE)
- **Storage**: Free tier (25 GB/month)
- **Writes**: Free tier (25 WCUs)
- **Reads**: Free tier (25 RCUs)
- **Cost**: $0 for typical usage

### Option 2: S3
- **Storage**: $0.023/GB/month
- **Requests**: $0.005/1000 PUT
- **Data transfer**: $0.09/GB
- **Cost**: ~$5-10/month for active use

**Recommendation**: Use base64 for now, migrate to S3 later if needed!

---

## 🚀 Implementation Steps (All Free!)

1. ✅ Update MessageData (done!)
2. ✅ Add mic permission (done!)
3. Create AudioRecordingService
4. Create VoiceMessageBubble
5. Add mic button to ChatView
6. Backend Lambda with Whisper (no S3!)
7. Test end-to-end

**Total Cost**: $0 (OpenAI Whisper API only ~$0.006/minute)

---

**Ready to implement with 100% free storage!** 🎤💰

