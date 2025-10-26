# 🧪 Quick Test Guide - Banner Notification Fix

## ✅ What Was Fixed
Notification banners now intelligently show/hide based on:
- **App state** (foreground/background)
- **Current conversation** (which one you're viewing)

## 🚀 Quick Test (2 minutes)

### Test 1: Same Conversation (Should NOT show banner)
1. Open Cloudy on Device/Simulator 1
2. Open a conversation with User B
3. From Device 2 (or another simulator), send message as User B
4. **Expected:** ❌ NO banner appears (message just appears in chat)

### Test 2: Different Conversation (SHOULD show banner)
1. Stay on Device 1
2. Open conversation with User C
3. From Device 2, send another message as User B
4. **Expected:** ✅ Banner appears (for User B's message)

### Test 3: Background (SHOULD show banner)
1. Press **Cmd+Shift+H** (go to home screen)
2. From Device 2, send message
3. **Expected:** ✅ Banner appears on screen

## 📱 Xcode is Now Open

**To Test:**
1. Select **iPhone 17 Pro** (or 17, 16e)
2. Press **Cmd+R** to build and run
3. Follow the quick tests above

## 🎯 Expected Results

| Scenario | Banner | Sound | Message Shows |
|----------|--------|-------|---------------|
| **In same conversation** | ❌ No | ❌ No | ✅ Yes (inline) |
| **In different conversation** | ✅ Yes | ✅ Yes | ✅ Yes (inline) |
| **App in background** | ✅ Yes | ✅ Yes | ✅ Yes (on open) |

## 💡 Tip
Look for these console logs to see what's happening:
```
📱 App state: active/background/inactive
🔕 Suppressing banner & sound - user is viewing this conversation
🔔 Showing banner - user in different conversation
```

---

**Ready to test!** Press Cmd+R in Xcode! 🚀
