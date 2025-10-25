# 🚀 RAG Quick Start Guide

## ⚡ **45-Minute Setup**

Follow these steps to deploy the complete RAG pipeline with Pinecone + LangChain + LangSmith.

---

## ✅ **Step 1: Sign Up for Services** (10 min)

### **Pinecone** (Vector Database)
1. Go to https://www.pinecone.io/
2. Sign up for free account
3. Create a new index:
   - Name: `slang-rag`
   - Dimensions: `1536` (for OpenAI embeddings)
   - Metric: `cosine`
4. Get API key from dashboard

### **OpenAI** (Embeddings)
1. Go to https://platform.openai.com/
2. Create API key
3. You'll use `text-embedding-ada-002` model

### **LangSmith** (Optional - Monitoring)
1. Go to https://smith.langchain.com/
2. Sign up (free tier: 5K traces/month)
3. Get API key from settings

---

## ✅ **Step 2: Store Credentials in AWS** (5 min)

```bash
cd /Users/alexho/MessageAI/backend/rag

# Store Pinecone credentials
aws secretsmanager create-secret \
  --name pinecone-credentials-alexho \
  --secret-string '{"apiKey":"YOUR_PINECONE_KEY","environment":"us-east-1-aws"}' \
  --region us-east-1

# Store OpenAI key
aws secretsmanager create-secret \
  --name openai-api-key-alexho \
  --secret-string '{"apiKey":"YOUR_OPENAI_KEY"}' \
  --region us-east-1

# Claude key (if not already created)
aws secretsmanager create-secret \
  --name claude-api-key-alexho \
  --secret-string '{"apiKey":"YOUR_CLAUDE_KEY"}' \
  --region us-east-1
```

---

## ✅ **Step 3: Install Dependencies** (5 min)

```bash
cd /Users/alexho/MessageAI/backend/rag

# Install all packages
npm install

# Should install:
# - @langchain/anthropic, @langchain/openai, @langchain/community
# - langchain, langsmith
# - @pinecone-database/pinecone
# - @aws-sdk/* packages
```

---

## ✅ **Step 4: Set Environment Variables** (2 min)

Create `.env` file:
```bash
cat > .env << 'EOF'
PINECONE_API_KEY=your-pinecone-key-here
PINECONE_ENV=us-east-1-aws
OPENAI_API_KEY=your-openai-key-here
ANTHROPIC_API_KEY=your-claude-key-here
LANGCHAIN_TRACING_V2=true
LANGCHAIN_API_KEY=your-langsmith-key-here
EOF
```

Or export them:
```bash
export PINECONE_API_KEY="your-key"
export PINECONE_ENV="us-east-1-aws"
export OPENAI_API_KEY="your-key"
export ANTHROPIC_API_KEY="your-key"
export LANGCHAIN_TRACING_V2="true"
export LANGCHAIN_API_KEY="your-key"
```

---

## ✅ **Step 5: Ingest Slang Database** (3 min)

```bash
cd /Users/alexho/MessageAI/backend/rag

# Run ingestion with LangChain
npm run ingest

# Output should show:
# 🚀 Starting slang database ingestion with LangChain...
# 📚 Loaded 21 slang terms
# ✅ Pinecone initialized
# 📄 Created 21 documents
# 🔢 Generating embeddings and uploading to Pinecone...
# ✅ Successfully ingested slang database!
# 🧪 Testing retrieval...
# ✨ Ingestion complete!
```

**What this does:**
- Loads `slang-database.json` (21 terms)
- Generates embeddings for each term
- Uploads to Pinecone
- Tests retrieval

---

## ✅ **Step 6: Deploy Lambda** (5 min)

```bash
cd /Users/alexho/MessageAI/backend/rag

# Deploy to AWS
./deploy-rag.sh

# Output:
# 🚀 Deploying RAG Pipeline with LangChain...
# 📦 Creating deployment package...
# 🔄 Updating existing Lambda function...
# ✅ RAG Lambda deployed successfully!
```

---

## ✅ **Step 7: Test Locally** (5 min)

Create `test-rag-langchain.js`:
```javascript
require('dotenv').config();
const { handler } = require('./rag-slang-langchain');

async function test() {
  const event = {
    body: JSON.stringify({
      message: "Bro got major rizz no cap"
    })
  };
  
  const result = await handler(event);
  console.log('Result:', JSON.parse(result.body));
}

test();
```

Run it:
```bash
node test-rag-langchain.js
```

Expected output:
```json
{
  "success": true,
  "result": {
    "hasContext": true,
    "hints": [
      {
        "phrase": "rizz",
        "explanation": "Gen Z slang derived from 'charisma'",
        "literalMeaning": "",
        "actualMeaning": "Charisma or charm, especially with romantic interests"
      },
      {
        "phrase": "no cap",
        "explanation": "Internet slang from AAVE",
        "literalMeaning": "",
        "actualMeaning": "No lie, I'm being truthful"
      }
    ]
  },
  "fromCache": false,
  "sources": ["rizz", "no cap"]
}
```

---

## ✅ **Step 8: Add WebSocket Integration** (10 min)

Update `WebSocketService.swift`:
```swift
func requestSlangExplanation(message: String, messageId: String) {
    let payload: [String: Any] = [
        "action": "explain_slang",
        "message": message,
        "messageId": messageId
    ]
    sendJSON(payload)
}

// In handleWebSocketMessage:
case "slang_explanation":
    if let messageId = payload["messageId"] as? String,
       let data = payload["data"] as? [String: Any] {
        await handleSlangExplanation(messageId: messageId, data: data)
    }
```

Add WebSocket route handler:
```javascript
// backend/websocket/routes.js
case 'explain_slang':
  return await invokeRAGLambda(event);
```

---

## 🎉 **You're Done!**

### **Verify It Works:**
1. Open iOS app
2. Long press a message with slang
3. Tap "Explain Slang"
4. See orange explanation box appear!

---

## 🐛 **Troubleshooting**

### **Pinecone Error: "Index not found"**
```bash
# Create index via CLI
curl -X POST https://api.pinecone.io/indexes \
  -H "Api-Key: YOUR_API_KEY" \
  -d '{"name":"slang-rag","dimension":1536,"metric":"cosine"}'
```

### **Lambda Timeout**
- Increase memory to 1024MB (faster cold starts)
- Increase timeout to 30s
- Check CloudWatch logs

### **No Results Returned**
- Check ingestion completed: `npm run ingest`
- Verify embeddings in Pinecone dashboard
- Check similarity threshold (> 0.7)

### **LangSmith Not Showing**
- Set `LANGCHAIN_TRACING_V2=true`
- Set `LANGCHAIN_API_KEY`
- Visit https://smith.langchain.com/

---

## 📊 **Monitoring with LangSmith**

After setup, view your traces:
1. Go to https://smith.langchain.com/
2. Click on your project
3. See every RAG query:
   - What was retrieved from Pinecone
   - What context was sent to Claude
   - How long each step took
   - Total cost per query

---

## 💰 **Cost Summary**

### **Setup (One-time):**
- Ingestion: ~$0.02 (21 terms × embeddings)

### **Ongoing (Monthly):**
- Pinecone: $0 (free tier)
- LangChain: $0 (open source library)
- LangSmith: $0 (free tier)
- Claude: ~$0.09/user
- OpenAI: ~$0.01 (monthly updates)

**Total: ~$0.10 per user/month**

---

## 🎯 **What You Get**

✅ **21 pre-loaded slang terms** (rizz, no cap, bussin, etc.)  
✅ **Instant semantic search** (< 100ms)  
✅ **Claude-powered explanations** (< 2s)  
✅ **Automatic caching** (instant on repeat)  
✅ **LangSmith monitoring** (debug everything)  
✅ **Production-ready** (error handling, retries)  
✅ **Easy updates** (edit JSON, run ingest)  

---

## 🚀 **Next Level**

### **Auto-Update from Urban Dictionary:**
```javascript
// Future: Scrape and auto-ingest new slang
const urbanDictionary = await scrapeUrbanDict();
await ingestNewTerms(urbanDictionary);
```

### **TikTok Trends Integration:**
```javascript
// Pull trending slang from TikTok
const tiktokSlang = await getTikTokTrends();
await ingestNewTerms(tiktokSlang);
```

### **User-Submitted Slang:**
```javascript
// Let users suggest new slang
app.post('/submit-slang', async (req, res) => {
  await ingestNewTerms([req.body]);
});
```

---

## ✨ **Ready to Rock!**

Your RAG pipeline is now:
- ✅ Fully functional
- ✅ Production-ready  
- ✅ Easy to update
- ✅ Cost-effective
- ✅ Monitored

Start explaining that "rizz"! 🎉
