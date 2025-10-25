# RAG Pipeline Testing Guide

## ✅ System is Ready!

All components are deployed and configured. Follow this guide to test.

---

## 🏗️ Backend Architecture

```
iOS App
   ↓
WebSocket Connection (wss://bnbr75tld0.execute-api.us-east-1.amazonaws.com/production)
   ↓
Action: "translateAndExplain"
   ↓
API Gateway Routes to: websocket-translateAndExplain_AlexHo
   ↓
Lambda Does (in parallel):
   1. Fetch OpenAI API Key from Secrets Manager
   2. Fetch Slang Database from DynamoDB (21 terms)
   3. Send ONE prompt to GPT-4:
      - Translate message to target language
      - Detect any slang/informal terms
   4. Parse GPT-4 JSON response
   ↓
Send back via WebSocket:
   {
     type: "translate_and_explain",
     messageId: "xxx",
     translation: { translatedText: "...", ... },
     slang: { hints: [...], hasContext: true/false }
   }
   ↓
iOS App Updates UI:
   - Translation section (always shown)
   - Slang section (shown if detected)
```

---

## 🧪 Step-by-Step Testing

### Step 1: Clean Build
```bash
# In Xcode:
1. Product → Clean Build Folder (Cmd+Shift+K)
2. Wait for "Clean Finished"
3. Product → Build (Cmd+B)
4. Wait for "Build Succeeded"
5. Click Run (or Cmd+R)
```

### Step 2: Open Console
```bash
# In Xcode:
View → Debug Area → Show Debug Area (Cmd+Shift+Y)
```

### Step 3: Send Test Message
Send a message from another device/simulator with slang:
```
"I got rizz no cap"
```

### Step 4: Trigger Translation
1. Long press the received message
2. You should see **ONLY ONE option**: "Translate & Explain" ✨
3. Tap it
4. Watch the console for logs

### Step 5: Verify Console Output

**✅ Success looks like:**
```
🚨🚨🚨 TRANSLATE & EXPLAIN REQUEST 🚨🚨🚨
   Message: I got rizz no cap
   MessageID: XXXX-XXXX-XXXX
   Language: es
   WebSocket state: connected
📤 Sending WebSocket payload: {...}
✅✅✅ Translate & Explain request SENT successfully via WebSocket

[2-4 seconds later]

🚨🚨🚨 TRANSLATE & EXPLAIN RESPONSE RECEIVED 🚨🚨🚨
   MessageID: XXXX-XXXX-XXXX
✅ Translation received: Tengo carisma, sin mentir
✅ Parsed slang hint: rizz
✅ Parsed slang hint: no cap
💾 Stored 2 cultural hints
```

**❌ Failure looks like:**
```
🚨🚨🚨 TRANSLATE & EXPLAIN REQUEST 🚨🚨🚨
✅✅✅ Translate & Explain request SENT successfully
📥 Received WebSocket message: ["message": Internal server error, ...]
⚠️ Unknown message format
⏱️ Translate & Explain timeout
```

### Step 6: Verify UI

**Translation Section:**
```
🌐 Translation                         🇪🇸 Español

Tengo carisma, sin mentir
```

**Slang Section:**
```
💡 Slang & Cultural Context          2 terms

1. "rizz"
   Means: Carisma o encanto
   Context: Usado por generaciones jóvenes...

2. "no cap"
   Means: Sin mentir, siendo serio
   Context: Expresión común en redes sociales...
```

---

## 🐛 Troubleshooting

### Issue: "Internal server error"

**Check Lambda Logs:**
```bash
aws logs tail /aws/lambda/websocket-translateAndExplain_AlexHo \
  --since 5m \
  --region us-east-1 \
  --follow
```

**Common Causes:**
1. **Missing OpenAI API key**
   - Verify: `aws secretsmanager get-secret-value --secret-id openai-api-key-alexho --region us-east-1`
   
2. **Missing DynamoDB permissions**
   - Verify: `aws iam get-role-policy --role-name MessageAI-WebSocket-Role_AlexHo --policy-name DynamoDBSlangAccess --region us-east-1`
   
3. **Lambda timeout**
   - Check if timeout is set to 30 seconds
   - Increase if needed

4. **OpenAI API down/rate limited**
   - Check logs for "OpenAI API error"
   - Verify API key is valid

### Issue: "Translation error" 500

**If you see this:**
- You're using an OLD build of the app
- The app is trying to call HTTP endpoint (which doesn't exist)
- **FIX**: Clean build and run again

### Issue: Translation is empty

**Check:**
1. Console shows "✅ Translation received"?
   - Yes: UI bug, check `TranslationSheetView`
   - No: Lambda isn't returning translation

2. WebSocket response received?
   - Yes: Response format might be wrong
   - No: Lambda might be timing out

3. Lambda logs show translation?
   ```bash
   aws logs tail /aws/lambda/websocket-translateAndExplain_AlexHo --since 5m
   ```

### Issue: No slang detected (when should be)

**Normal behavior:**
- GPT-4 is conservative about what counts as "slang"
- It might consider some terms as informal but not slang
- Try more obvious slang: "rizz", "bussin", "no cap", "fr"

**If it NEVER detects slang:**
1. Check slang database has entries:
   ```bash
   aws dynamodb scan --table-name SlangDatabase_AlexHo --region us-east-1 --limit 5
   ```

2. Check Lambda logs show slang list:
   ```bash
   aws logs tail /aws/lambda/websocket-translateAndExplain_AlexHo --since 5m
   # Should show: "Got API key and 21 slang terms"
   ```

3. Check GPT-4 response in logs:
   ```bash
   # Should show JSON with slang array
   ```

### Issue: Timeout after 10 seconds

**Causes:**
1. **Lambda is slow**
   - Check logs for how long it takes
   - OpenAI API might be slow
   - Consider increasing iOS timeout

2. **Lambda crashed before responding**
   - Check Lambda logs for errors
   - Look for stack traces

3. **WebSocket disconnected**
   - Check iOS console for disconnect messages
   - Verify connection is stable

---

## 🔍 Verification Checklist

Before testing, verify all these are true:

### AWS Resources:
- [ ] Lambda `websocket-translateAndExplain_AlexHo` exists and is Active
- [ ] API Gateway route `translateAndExplain` exists
- [ ] Route is deployed to `production` stage
- [ ] Lambda has permission to invoke from API Gateway
- [ ] IAM role has Secrets Manager access
- [ ] IAM role has DynamoDB access
- [ ] Secret `openai-api-key-alexho` exists
- [ ] Table `SlangDatabase_AlexHo` has items

### iOS App:
- [ ] `ChatView.swift` has only "Translate & Explain" button
- [ ] `WebSocketService.swift` sends action `translateAndExplain`
- [ ] `WebSocketService.swift` handles `translate_and_explain` type
- [ ] `TranslationSheetView.swift` doesn't call HTTP API
- [ ] App was Clean Built after changes

---

## 🚨 If Still Not Working

### Run This Complete Diagnostic:

```bash
#!/bin/bash

echo "=== 1. Lambda Status ==="
aws lambda get-function \
  --function-name websocket-translateAndExplain_AlexHo \
  --region us-east-1 \
  --query 'Configuration.[State,LastUpdateStatus,Handler]'

echo ""
echo "=== 2. API Gateway Route ==="
aws apigatewayv2 get-routes \
  --api-id bnbr75tld0 \
  --region us-east-1 \
  --query 'Items[?RouteKey==`translateAndExplain`].[RouteKey,Target]'

echo ""
echo "=== 3. Lambda Permissions ==="
aws lambda get-policy \
  --function-name websocket-translateAndExplain_AlexHo \
  --region us-east-1 \
  --query 'Policy' | jq

echo ""
echo "=== 4. IAM Role Policies ==="
aws iam list-attached-role-policies \
  --role-name MessageAI-WebSocket-Role_AlexHo \
  --region us-east-1

echo ""
echo "=== 5. OpenAI API Key ==="
aws secretsmanager describe-secret \
  --secret-id openai-api-key-alexho \
  --region us-east-1 \
  --query 'Name'

echo ""
echo "=== 6. Slang Database ==="
aws dynamodb describe-table \
  --table-name SlangDatabase_AlexHo \
  --region us-east-1 \
  --query 'Table.[TableName,ItemCount,TableStatus]'

echo ""
echo "=== 7. Recent Lambda Logs ==="
aws logs tail /aws/lambda/websocket-translateAndExplain_AlexHo \
  --since 5m \
  --region us-east-1 \
  --format short

echo ""
echo "=== 8. Recent API Gateway Errors ==="
aws logs tail /aws/apigateway/MessageAI-WebSocket \
  --since 5m \
  --region us-east-1 \
  --filter-pattern "Internal server error" \
  --format short
```

Save this as `diagnostic.sh` and run it to get a complete system report.

---

## 📝 Quick Reference

### Lambda ARN:
```
arn:aws:lambda:us-east-1:971422717446:function:websocket-translateAndExplain_AlexHo
```

### API Gateway:
```
ID: bnbr75tld0
URL: wss://bnbr75tld0.execute-api.us-east-1.amazonaws.com/production
Route: translateAndExplain
```

### DynamoDB Table:
```
SlangDatabase_AlexHo
```

### Secrets Manager:
```
openai-api-key-alexho
```

---

**Ready to test! Build the app and try it now!** 🚀

