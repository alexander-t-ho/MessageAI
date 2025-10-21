# 📎 **Future Feature: Rich Media Attachments**

**Status:** 📅 Deferred until after Phase 10  
**Priority:** Enhancement (Post-MVP)  
**Estimated Effort:** 3-4 hours implementation

---

## 🎯 **Feature Overview**

Add support for sending and receiving rich media and documents in messages:
- 📷 Photos (camera + library)
- 🎥 Videos (camera + library)
- 📄 PDFs
- 📝 DOCX files
- 🎵 Audio files (optional)

All attachments will support the same interactions as text messages:
- Swipe right → Reply
- Long press → Emphasize, Forward, Delete
- Tap to view full screen

---

## 📋 **Implementation Plan**

### **Phase 1: Data Model** (30 min)

#### **Update MessageData.swift:**
```swift
@Model
final class MessageData {
    // ... existing fields ...
    
    // Attachment feature
    var attachmentType: String? // "photo", "video", "pdf", "docx", "audio"
    var attachmentURL: String? // Local file URL or server URL
    var attachmentThumbnail: Data? // Thumbnail image data
    var attachmentFileName: String?
    var attachmentFileSize: Int64
}
```

---

### **Phase 2: File Management** (45 min)

#### **Create `AttachmentManager.swift`:**
```swift
class AttachmentManager {
    // Save attachment to app documents directory
    func saveAttachment(data: Data, type: String) -> URL?
    
    // Generate thumbnail for images/videos
    func generateThumbnail(for url: URL, type: String) -> Data?
    
    // Delete attachment file
    func deleteAttachment(at url: URL)
    
    // Get file size
    func getFileSize(at url: URL) -> Int64
    
    // Validate file (size limits, type checks)
    func validateFile(url: URL, type: String) -> Bool
}
```

**File Size Limits:**
- Photos: 10MB
- Videos: 100MB
- Documents: 25MB

**Storage Location:**
```
Documents/
  Attachments/
    [conversationId]/
      [messageId]_[fileName]
```

---

### **Phase 3: Picker UI** (60 min)

#### **Create `AttachmentPickerView.swift`:**
```swift
struct AttachmentPickerView: View {
    // Action sheet with options:
    // - 📷 Take Photo
    // - 🎥 Record Video
    // - 🖼️ Choose Photo
    // - 📹 Choose Video
    // - 📄 Choose Document
}

// Wrappers for native pickers:
struct CameraPickerView: UIViewControllerRepresentable {
    // UIImagePickerController with sourceType: .camera
}

struct PhotoLibraryPickerView: UIViewControllerRepresentable {
    // PHPickerViewController
}

struct DocumentPickerView: UIViewControllerRepresentable {
    // UIDocumentPickerViewController
    // Types: public.pdf, org.openxmlformats.wordprocessingml.document
}
```

---

### **Phase 4: Display Components** (90 min)

#### **Photo/Video Display:**
```swift
struct MediaMessageBubble: View {
    // Shows thumbnail with play button overlay (videos)
    // Tap to open fullscreen viewer
    // Caption text below if provided
}

struct FullScreenMediaViewer: View {
    // Zoomable image view
    // Video player for videos
    // Share/Save buttons
}
```

#### **Document Display:**
```swift
struct DocumentMessageBubble: View {
    // File icon (PDF or DOCX)
    // File name
    // File size
    // Tap to open in DocumentViewer
}

struct DocumentViewer: View {
    // PDFKit for PDFs
    // WebView for DOCX (converted to HTML)
    // Share/Open In... options
}
```

---

### **Phase 5: Integration** (45 min)

#### **Update ChatView.swift:**

**Add attachment button:**
```swift
// Input bar with + button
HStack {
    Button(action: { showAttachmentPicker = true }) {
        Image(systemName: "plus.circle.fill")
            .font(.system(size: 28))
            .foregroundColor(.blue)
    }
    
    TextField("Message", text: $messageText)
    // ... send button
}
```

**Send attachment method:**
```swift
func sendAttachment(type: String, url: URL, thumbnail: Data?, fileName: String, fileSize: Int64) {
    let message = MessageData(
        conversationId: conversation.id,
        senderId: "current-user-id",
        senderName: "You",
        content: "", // Optional caption
        attachmentType: type,
        attachmentURL: url.absoluteString,
        attachmentThumbnail: thumbnail,
        attachmentFileName: fileName,
        attachmentFileSize: fileSize
    )
    
    try databaseService.saveMessage(message)
    // Upload to server (Phase 4+ integration)
}
```

**Update MessageBubble:**
```swift
struct MessageBubble: View {
    var body: some View {
        if message.attachmentType != nil {
            // Show MediaMessageBubble or DocumentMessageBubble
        } else {
            // Show text bubble
        }
        // All gestures work the same
    }
}
```

---

## 🎨 **UI Design Specifications**

### **Photo Message:**
```
┌──────────────────────────┐
│                          │
│      [Photo Image]       │
│    (150x150 thumbnail)   │
│                          │
│ Optional caption text... │
└──────────────────────────┘
  3:45 PM ✓
```

### **Video Message:**
```
┌──────────────────────────┐
│      ▶️                  │
│   [Video Thumbnail]      │
│    (150x150 with play)   │
│                          │
│ 0:45 duration            │
└──────────────────────────┘
  3:45 PM ✓
```

### **PDF Message:**
```
┌──────────────────────────┐
│ 📄  project_proposal.pdf │
│     2.3 MB               │
│     → Tap to view        │
└──────────────────────────┘
  3:45 PM ✓
```

### **DOCX Message:**
```
┌──────────────────────────┐
│ 📝  meeting_notes.docx   │
│     456 KB               │
│     → Tap to view        │
└──────────────────────────┘
  3:45 PM ✓
```

---

## 🔧 **Technical Considerations**

### **iOS Permissions Required:**

**Info.plist additions:**
```xml
<key>NSCameraUsageDescription</key>
<string>Take photos and videos to share in messages</string>

<key>NSPhotoLibraryUsageDescription</key>
<string>Choose photos and videos to share in messages</string>

<key>NSMicrophoneUsageDescription</key>
<string>Record audio and video to share in messages</string>
```

### **Image Compression:**
```swift
// Compress images before saving
func compressImage(_ image: UIImage, quality: CGFloat = 0.7) -> Data? {
    return image.jpegData(compressionQuality: quality)
}
```

### **Thumbnail Generation:**
```swift
import AVFoundation

func generateVideoThumbnail(url: URL) -> UIImage? {
    let asset = AVAsset(url: url)
    let imageGenerator = AVAssetImageGenerator(asset: asset)
    imageGenerator.appliesPreferredTrackTransform = true
    
    let time = CMTime(seconds: 1, preferredTimescale: 60)
    if let cgImage = try? imageGenerator.copyCGImage(at: time, actualTime: nil) {
        return UIImage(cgImage: cgImage)
    }
    return nil
}
```

---

## 📊 **Server Integration** (Phase 4+)

### **Upload Flow:**
1. User selects file → Save locally with temp ID
2. Create message with local file URL
3. Upload file to S3 in background
4. Update message with server URL
5. Send message notification to recipient
6. Recipient downloads file when viewing

### **S3 Bucket Structure:**
```
messageai-attachments/
  [userId]/
    [conversationId]/
      [messageId]_[fileName]
```

### **DynamoDB Schema Update:**
```json
{
  "messageId": "msg-123",
  "attachmentType": "photo",
  "attachmentS3Key": "user123/conv456/msg123_photo.jpg",
  "attachmentThumbnailS3Key": "user123/conv456/msg123_thumb.jpg",
  "attachmentFileName": "photo.jpg",
  "attachmentFileSize": 1234567
}
```

---

## ⚡ **Features to Include**

### **Must Have:**
- ✅ Take photo with camera
- ✅ Record video with camera
- ✅ Choose photo from library
- ✅ Choose video from library
- ✅ Choose PDF from files
- ✅ Choose DOCX from files
- ✅ Display thumbnails in chat
- ✅ Tap to view full screen
- ✅ Swipe right to reply (works on attachments)
- ✅ Long press context menu (works on attachments)
- ✅ File size validation
- ✅ Loading indicators during upload
- ✅ Error handling

### **Nice to Have:**
- 🎯 Photo editing before sending (crop, filter)
- 🎯 Video trimming before sending
- 🎯 Multiple file selection
- 🎯 Photo collage (2-4 images in grid)
- 🎯 Voice messages
- 🎯 Location sharing
- 🎯 Contact sharing

---

## 🧪 **Testing Checklist**

### **Camera:**
- [ ] Take photo → Sends successfully
- [ ] Take video → Sends successfully
- [ ] Video thumbnail generates correctly
- [ ] Camera permission handling
- [ ] Cancel camera → No crash

### **Library:**
- [ ] Choose single photo
- [ ] Choose single video
- [ ] Choose multiple photos (if implemented)
- [ ] Large images compressed correctly
- [ ] Permission handling

### **Documents:**
- [ ] Choose PDF → Displays correctly
- [ ] Choose DOCX → Displays correctly
- [ ] Large files rejected (over limit)
- [ ] Invalid file types rejected
- [ ] File icon displays correctly

### **Display:**
- [ ] Photo displays in bubble
- [ ] Video displays with play button
- [ ] PDF displays with file info
- [ ] DOCX displays with file info
- [ ] Tap photo → Full screen viewer
- [ ] Tap video → Video plays
- [ ] Tap document → Document viewer opens

### **Interactions:**
- [ ] Swipe right on photo → Reply works
- [ ] Long press on photo → Context menu
- [ ] Emphasize photo message → Heart shows
- [ ] Forward photo message → Works
- [ ] Delete photo message → File deleted too

### **Edge Cases:**
- [ ] Send message while photo uploading
- [ ] Network error during upload
- [ ] File too large error
- [ ] Storage almost full
- [ ] Corrupted file handling
- [ ] Missing file handling

---

## 📈 **Metrics to Track**

- Total attachments sent per user
- Attachment type breakdown (photo/video/pdf/docx)
- Average attachment file size
- Upload success rate
- Upload duration average
- Storage usage per user
- Attachment view rate

---

## 🚀 **Deployment Strategy**

### **Phase 1: Testing**
- Internal testing with small file sizes
- Verify all gestures work
- Test on multiple devices/iOS versions

### **Phase 2: Beta**
- Release to small user group
- Monitor upload success rates
- Gather feedback on UX

### **Phase 3: Full Release**
- Announce feature
- Update app store screenshots
- Add to feature list

---

## 💰 **Cost Considerations**

### **S3 Storage Costs:**
- $0.023 per GB/month (Standard)
- Estimate: 10MB average per user = ~$0.0002/user/month

### **S3 Transfer Costs:**
- $0.09 per GB transfer out
- Estimate: 50MB downloads per user/month = ~$0.0045/user/month

### **Total:** ~$0.005/user/month for attachment storage & transfer

---

## 📝 **Implementation Notes**

### **When to Implement:**
✅ After Phase 10 (Testing & Deployment) is complete  
✅ When core messaging is stable and deployed  
✅ When team has 3-4 hours for focused work  
✅ When AWS S3 bucket is configured for production

### **Before Starting:**
1. Review this document
2. Set up S3 bucket with proper CORS
3. Configure IAM roles for file upload
4. Create CloudFront distribution (optional, for faster downloads)
5. Update Lambda functions to handle attachment metadata

### **After Implementation:**
1. Update user documentation
2. Add to app store changelog
3. Monitor S3 costs
4. Track feature usage
5. Gather user feedback

---

## 🎯 **Success Criteria**

- [ ] Users can send all supported file types
- [ ] Attachments display correctly in chat
- [ ] All gestures work on attachments
- [ ] File uploads succeed >95% of time
- [ ] No crashes related to attachments
- [ ] Storage costs within budget
- [ ] Positive user feedback
- [ ] Feature used by >50% of active users

---

## 📚 **Resources**

**Apple Documentation:**
- [PHPickerViewController](https://developer.apple.com/documentation/photokit/phpickerviewcontroller)
- [UIImagePickerController](https://developer.apple.com/documentation/uikit/uiimagepickercontroller)
- [UIDocumentPickerViewController](https://developer.apple.com/documentation/uikit/uidocumentpickerviewcontroller)
- [PDFKit](https://developer.apple.com/documentation/pdfkit)
- [AVFoundation](https://developer.apple.com/av-foundation/)

**AWS Documentation:**
- [S3 Upload Guide](https://docs.aws.amazon.com/AmazonS3/latest/userguide/upload-objects.html)
- [CloudFront CDN](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/)
- [Presigned URLs](https://docs.aws.amazon.com/AmazonS3/latest/userguide/PresignedUrlUploadObject.html)

---

**Last Updated:** Phase 3 Complete  
**Status:** Documented for future implementation  
**Next Review:** After Phase 10 completion

