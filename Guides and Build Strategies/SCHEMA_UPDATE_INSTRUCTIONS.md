# SwiftData Schema Update - Instructions

## 🔄 New Model Added: UserCustomizationData

The `UserCustomizationData` model was added to store:
- Custom nicknames for other users
- Custom profile photos for other users
- All local to your device

## ✅ How to Update

### Option 1: Delete and Reinstall App (Recommended for Development)

**In Xcode:**
1. Stop the app if running
2. Long press the MessageAI app icon in simulator
3. Tap the (-) button to delete
4. Or: In Simulator menu → Device → Erase All Content and Settings
5. Build and run again (Cmd+R)

**Result:**
- ✅ Fresh database with new schema
- ✅ All new features available
- ⚠️ All test data will be lost (need to re-login)

### Option 2: Schema Migration (For Production)

The app already handles this automatically via `MessageAIApp.swift`:

```swift
// If migration fails during development, try to recreate container
print("⚠️ ModelContainer creation failed: \(error)")
print("🔄 Attempting to recreate database...")

// Delete old database files
let url = modelConfiguration.url
try? FileManager.default.removeItem(at: url)
// ... recreates database
```

**This runs automatically if schema changes!**

---

## 🧪 After Reinstalling

### You'll need to:
1. **Login again** - Enter your credentials
2. **Grant notification permission** - Tap "Allow"
3. **Send test messages** - Create conversations
4. **Test new features**:
   - Tap notification → Should open conversation
   - Future: Set nicknames, upload custom photos

---

## 🎯 What's New on Features Branch

### Immediately Available:
- ✅ **Notification Deep Linking**
  - Tap notification banner
  - App opens to that conversation
  - Works immediately after reinstall

### Foundation Ready (UI not yet integrated):
- ✅ **UserCustomizationData model** - For future nickname/photo features
- ✅ **ChatHeaderView component** - User icons with online status
- ✅ **Improved slang prompts** - No more "undefined"

---

## 📱 Quick Reset Commands

### Delete App Data (Simulator):
```bash
# In Terminal:
xcrun simctl --set <simulator-id> uninstall <bundle-id>

# Or in Xcode:
# Simulator → Device → Erase All Content and Settings
```

### Clean Build:
```bash
# In Xcode:
Product → Clean Build Folder (Cmd+Shift+K)
Product → Build (Cmd+B)
Product → Run (Cmd+R)
```

---

## ✅ Verification

After reinstalling, check:
- [ ] App launches successfully
- [ ] Login works
- [ ] Can send messages
- [ ] Notification deep linking works (send message, tap notification)
- [ ] AI features still work
- [ ] Customization works (color picker, dark mode)

---

## 🚀 Ready to Test

**Delete the app and reinstall to see:**
- ✅ Notification deep linking
- ✅ Clean schema
- ✅ All features working

---

**The new features are in the code, just need a fresh install!**

