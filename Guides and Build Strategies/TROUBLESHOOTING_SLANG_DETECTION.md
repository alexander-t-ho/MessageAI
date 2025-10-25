# 🔍 Troubleshooting: Slang Detection Returns Empty

## ❌ **Problem**
"I got rizz" returns "No slang detected" when it should detect "rizz"

## ✅ **What We Know Works**
- ✅ DynamoDB has "rizz" data (verified with AWS CLI)
- ✅ RAG Lambda works locally (tested with node test-rag-simple.js)
- ✅ UI sheet appears correctly
- ✅ WebSocket route exists in API Gateway

## 🐛 **Likely Causes**

### **1. iOS Not Sending WebSocket Message**
**Check:** Look at Xcode console for:
```
💡 Requesting slang explanation for message: [messageId], language: en
✅ Slang explanation requested via WebSocket
```

**If missing:** WebSocket isn't sending the request

### **2. Wrong Action Name**
**Check:** iOS sends `explainSlang` but Lambda might expect different name

### **3. WebSocket Not Connected**
**Check:** Xcode console should show:
```
🔌 WebSocket connected
```

**If shows disconnected:** Messages won't send

### **4. Lambda Not Invoked**
**Check:** No logs = Lambda never ran
**Fix:** Check API Gateway route configuration

### **5. GPT-4 Not Detecting Slang**
**Check:** Lambda logs should show what GPT-4 returned
**Fix:** Improve prompt or lower detection threshold

---

## 🔧 **Immediate Fixes**

### **Fix 1: Add Debug Logging to iOS**

Add to `WebSocketService.swift` in `requestSlangExplanation`:
```swift
func requestSlangExplanation(message: String, messageId: String, targetLang: String = "en") {
    print("💡💡💡 SLANG REQUEST STARTING 💡💡💡")
    print("   Message: \(message)")
    print("   MessageId: \(messageId)")
    print("   Language: \(targetLang)")
    print("   WebSocket Connected: \(case .connected = connectionState)")
    
    // ... rest of function
}
```

### **Fix 2: Make Slang Detection More Aggressive**

Update `rag-slang-simple.js` to always pass slang terms to GPT-4:

```javascript
// Instead of:
const relevantSlang = result.Items.filter(slang => {
  return messageLower.includes(term) || synonyms.some(syn => messageLower.includes(syn));
});

// Use:
const relevantSlang = result.Items; // Pass ALL slang to GPT-4, let it decide
```

### **Fix 3: Fallback to Direct GPT-4**

If no slang found in DB, still ask GPT-4:
```javascript
// In generateExplanation, even if relevantSlang is empty:
const prompt = relevantSlang.length > 0 
  ? `Based on these terms:\n${context}\n\nAnalyze: "${message}"`
  : `You are a Gen Z slang expert. Analyze for slang: "${message}"`;
```

---

## 🚀 **Quick Debug Steps**

### **Step 1: Check iOS Console**
Run app in Xcode → Send "I got rizz" → Tap "Explain Slang" → Look for:
```
💡 Requesting slang explanation...
✅ Slang explanation requested via WebSocket
```

### **Step 2: Check CloudWatch Logs**
```bash
# Check WebSocket Lambda
aws logs tail /aws/lambda/websocket-explainSlang_AlexHo \
  --since 2m --region us-east-1 --follow

# Check RAG Lambda
aws logs tail /aws/lambda/rag-slang_AlexHo \
  --since 2m --region us-east-1 --follow
```

### **Step 3: Test Backend Directly**
```bash
cd backend/rag
node test-rag-simple.js
# Should show "bussin", "rizz", etc. detected
```

### **Step 4: Improve Keyword Matching**

Make the matching case-insensitive and partial:
```javascript
// Current (strict):
messageLower.includes(term)

// Better (flexible):
messageLower.split(/\s+/).some(word => 
  word.includes(term) || term.includes(word)
)
```

---

## 💡 **Recommended Solution: Hybrid Approach**

Instead of ONLY using DynamoDB keyword matching, use **both** database + GPT-4:

```javascript
async function generateExplanation(message, relevantSlang, openaiApiKey, targetLang) {
  // Build context from DB (if any found)
  let context = '';
  if (relevantSlang.length > 0) {
    context = 'Reference slang terms from database:\n\n';
    relevantSlang.forEach(slang => {
      context += `- "${slang.term}": ${slang.definition}\n`;
    });
    context += '\n';
  }
  
  const prompt = `${context}
You are an expert on Gen Z slang, internet culture, and youth language.

Analyze this message for ANY slang, abbreviations, or youth expressions:
"${message}"

Even if a term isn't in the reference list, detect it if it's modern slang.

Common slang to watch for:
- rizz, no cap, bussin, slay, mid, fire, lit
- fr, ngl, iykyk, periodt, lowkey, highkey
- cap, bet, flex, simp, stan, vibe check

Return JSON with explanations in ${targetLangName}.`;

  // This makes GPT-4 the primary detector, DB is just a hint
}
```

---

## ⚡ **Let Me Fix It Now**

I'll implement:
1. ✅ More aggressive slang detection (pass ALL terms to GPT-4)
2. ✅ Fallback to pure GPT-4 detection (no DB required)
3. ✅ Better error handling and logging
4. ✅ Debug mode to see what's happening

This will make it MUCH more robust!
