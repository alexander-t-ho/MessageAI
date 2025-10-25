# 🔨 Rebuild Instructions - Get Latest AI Features

## ❗ **Important: You Must Rebuild**

Your Xcode is running OLD code. The debug logging and fixes aren't in your running app yet.

---

## 🔧 **Step-by-Step Rebuild**

### **Step 1: Clean Build Folder**
In Xcode:
```
Product → Clean Build Folder
(or press: Shift + Command + K)
```

### **Step 2: Quit the Simulator**
```
Simulator → Quit Simulator
(or press: Command + Q in Simulator)
```

### **Step 3: Rebuild**
```
Product → Build
(or press: Command + B)
```

### **Step 4: Run**
```
Product → Run
(or press: Command + R)
```

---

## ✅ **What You Should See After Rebuild**

### **When You Tap "Explain Slang":**

**In Xcode Console (bottom panel), you should see:**
```
🚨🚨🚨 SLANG EXPLANATION REQUEST 🚨🚨🚨
   Message: No cap I'm the best
   MessageID: [some-uuid]
   Language: en
   WebSocket state: connected
   WebSocket task exists: true
📤 Sending WebSocket payload: {"action":"explainSlang","message":"No cap I'm the best","messageId":"...","targetLang":"en"}
✅✅✅ Slang request SENT successfully via WebSocket
```

**Then 2-3 seconds later:**
```
🚨🚨🚨 SLANG EXPLANATION RESPONSE RECEIVED 🚨🚨🚨
   MessageID: [same-uuid]
   Data: [slang data]
   Has context: YES, hints count: 1
   ✅ Parsed hint: no cap
✅✅✅ Stored 1 slang hints for message: [uuid]
```

**In the UI:**
The sheet should update and show the orange slang card!

---

## 🐛 **If You Still Don't See Debug Output**

### **Problem 1: Wrong Branch**
**Check:** Are you on the AI branch?
```bash
cd /Users/alexho/MessageAI
git branch --show-current
# Should show: AI
```

**Fix:**
```bash
git checkout AI
```

Then rebuild in Xcode.

### **Problem 2: Xcode Using Cached Code**
**Fix:** Delete derived data
```
Xcode → Preferences → Locations → Derived Data → Click arrow
Delete the MessageAI folder
Clean and rebuild
```

### **Problem 3: Simulator Has Old App**
**Fix:** Delete app from simulator
```
Long press MessageAI app icon
Tap "Delete App"
Rebuild and run
```

---

## 📊 **Current Code Status**

Your code HAS the fixes:
- ✅ `dbace0d` - RAG improvements + debug logging
- ✅ `4f73d55` - Equatable conformance
- ✅ `ca9c621` - Simplified TranslationSheetView

But your **running app** doesn't have them until you rebuild!

---

## 🎯 **Quick Test After Rebuild**

1. Send: "No cap I'm the best"
2. Long press message
3. Tap "Explain Slang" 💡
4. **Watch Xcode console** for debug output
5. Should see slang card for "no cap"

If you see the debug output, we'll know WebSocket is working and can troubleshoot from there!

---

## ✨ **Expected Result**

After rebuild, "No cap" should show:
```
💡 SLANG & CULTURAL CONTEXT       1 terms

1. "no cap"
MEANS: No lie, I'm being truthful
CONTEXT: Internet slang from AAVE meaning "telling the truth"
LITERALLY: sin mentira (if Spanish)
```

**Clean build → Rebuild → Run → Test!** 🚀
