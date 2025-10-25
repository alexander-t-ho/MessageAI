# 🔍 RAG Pipeline Implementation Plan for Slang Detection

## 🎯 **Overview**

Implement a RAG (Retrieval-Augmented Generation) pipeline that:
- Maintains an always-updated slang database
- Never needs retraining
- Retrieves relevant context before generating explanations
- Scales efficiently with WebSocket + Lambda

---

## 🏗️ **Architecture**

```
User Message → WebSocket → Lambda (RAG) → Vector DB → Retrieve Slang
                    ↓
            Claude + Context → Explanation → Cache → User
```

### **Components:**
1. **Vector Database** - Store slang embeddings (Pinecone/OpenSearch)
2. **Slang Ingestion Pipeline** - Auto-update from sources
3. **RAG Lambda** - Query vector DB + Claude
4. **WebSocket Handler** - Real-time communication
5. **LangChain** - Orchestrate RAG workflow

---

## 📋 **Step-by-Step Implementation**

### **Phase 1: Choose & Setup Vector Database**

#### **Option A: Pinecone (Recommended - Easiest)**
```bash
# 1. Sign up at pinecone.io (Free tier: 1 index, 100K vectors)
# 2. Create index
curl -X POST https://api.pinecone.io/indexes \
  -H "Api-Key: YOUR_PINECONE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "slang-rag",
    "dimension": 1536,
    "metric": "cosine"
  }'
```

**Pros:**
- ✅ Fully managed
- ✅ Free tier available
- ✅ Easy setup
- ✅ Great docs

#### **Option B: AWS OpenSearch Serverless**
```bash
# Create OpenSearch domain
aws opensearchserverless create-collection \
  --name slang-rag \
  --type VECTORSEARCH \
  --region us-east-1
```

**Pros:**
- ✅ AWS native (no external service)
- ✅ Pay-per-use
- ✅ Integrated with IAM

#### **Option C: Weaviate Cloud**
**Pros:**
- ✅ Open source
- ✅ Built-in hybrid search
- ✅ Free tier

**Recommendation: Start with Pinecone** (easiest, free tier sufficient)

---

### **Phase 2: Create Slang Database & Ingestion Pipeline**

#### **File: `backend/rag/slang-database.json`**
```json
{
  "slang_terms": [
    {
      "term": "rizz",
      "definition": "Charisma or charm, especially in romantic contexts",
      "usage": "He's got rizz with the ladies",
      "origin": "Shortened from 'charisma', popularized by Kai Cenat",
      "category": "gen_z",
      "year": "2022",
      "examples": ["Bro has major rizz", "Rizz them up"],
      "synonyms": ["game", "charm", "charisma"]
    },
    {
      "term": "no cap",
      "definition": "No lie, for real, being truthful",
      "usage": "That was fire, no cap",
      "origin": "AAVE (African American Vernacular English)",
      "category": "internet",
      "year": "2017",
      "examples": ["No cap, that's the best pizza", "She's talented, no cap"],
      "synonyms": ["fr", "for real", "honestly"]
    },
    {
      "term": "bussin",
      "definition": "Really good, amazing, excellent",
      "usage": "This food is bussin",
      "origin": "AAVE, popularized on TikTok",
      "category": "gen_z",
      "year": "2020",
      "examples": ["These wings bussin bussin", "The party was bussin"],
      "synonyms": ["fire", "slaps", "hits"]
    }
  ]
}
```

#### **File: `backend/rag/ingest-slang.js`**
```javascript
/**
 * Slang Ingestion Pipeline
 * Periodically updates vector database with new slang
 */

const { PineconeClient } = require('@pinecone-database/pinecone');
const { Configuration, OpenAIApi } = require('openai');
const fs = require('fs');

// Initialize clients
const pinecone = new PineconeClient();
const openai = new OpenAIApi(new Configuration({
  apiKey: process.env.OPENAI_API_KEY
}));

async function generateEmbedding(text) {
  const response = await openai.createEmbedding({
    model: 'text-embedding-ada-002',
    input: text
  });
  return response.data.data[0].embedding;
}

async function ingestSlangDatabase() {
  // Initialize Pinecone
  await pinecone.init({
    apiKey: process.env.PINECONE_API_KEY,
    environment: process.env.PINECONE_ENV
  });
  
  const index = pinecone.Index('slang-rag');
  
  // Load slang database
  const slangData = JSON.parse(fs.readFileSync('./slang-database.json'));
  
  // Process each term
  const vectors = [];
  
  for (const slang of slangData.slang_terms) {
    // Create rich text for embedding
    const embeddingText = `
      Term: ${slang.term}
      Definition: ${slang.definition}
      Usage: ${slang.usage}
      Examples: ${slang.examples.join(', ')}
      Category: ${slang.category}
      Synonyms: ${slang.synonyms.join(', ')}
    `.trim();
    
    // Generate embedding
    const embedding = await generateEmbedding(embeddingText);
    
    vectors.push({
      id: slang.term.toLowerCase().replace(/\s+/g, '-'),
      values: embedding,
      metadata: {
        term: slang.term,
        definition: slang.definition,
        usage: slang.usage,
        origin: slang.origin,
        category: slang.category,
        year: slang.year,
        examples: JSON.stringify(slang.examples),
        synonyms: JSON.stringify(slang.synonyms)
      }
    });
  }
  
  // Upsert to Pinecone
  await index.upsert({
    upsertRequest: {
      vectors,
      namespace: 'slang'
    }
  });
  
  console.log(`✅ Ingested ${vectors.length} slang terms`);
}

// Run ingestion
ingestSlangDatabase().catch(console.error);
```

---

### **Phase 3: Create RAG Lambda Function**

#### **File: `backend/rag/rag-slang.js`**
```javascript
/**
 * RAG Lambda for Slang Detection
 * Retrieves relevant slang from vector DB + generates explanation with Claude
 */

const { PineconeClient } = require('@pinecone-database/pinecone');
const { Configuration, OpenAIApi } = require('openai');

const pinecone = new PineconeClient();
const openai = new OpenAIApi(new Configuration({
  apiKey: process.env.OPENAI_API_KEY
}));

// Initialize Pinecone (do this once at cold start)
let pineconeInitialized = false;
let index;

async function initPinecone() {
  if (!pineconeInitialized) {
    await pinecone.init({
      apiKey: process.env.PINECONE_API_KEY,
      environment: process.env.PINECONE_ENV
    });
    index = pinecone.Index('slang-rag');
    pineconeInitialized = true;
  }
}

// Generate embedding for query
async function generateQueryEmbedding(text) {
  const response = await openai.createEmbedding({
    model: 'text-embedding-ada-002',
    input: text
  });
  return response.data.data[0].embedding;
}

// Query vector database for relevant slang
async function retrieveRelevantSlang(message, topK = 5) {
  const embedding = await generateQueryEmbedding(message);
  
  const queryResponse = await index.query({
    queryRequest: {
      namespace: 'slang',
      topK,
      vector: embedding,
      includeMetadata: true,
      includeValues: false
    }
  });
  
  return queryResponse.matches.filter(match => match.score > 0.7); // Only relevant matches
}

// Call Claude with retrieved context
async function generateExplanation(message, retrievedSlang) {
  const { SecretsManagerClient, GetSecretValueCommand } = require('@aws-sdk/client-secrets-manager');
  const secretsClient = new SecretsManagerClient({ region: 'us-east-1' });
  
  // Get Claude API key
  const secret = await secretsClient.send(
    new GetSecretValueCommand({ SecretId: 'claude-api-key-alexho' })
  );
  const claudeApiKey = JSON.parse(secret.SecretString).apiKey;
  
  // Build context from retrieved slang
  let context = '';
  if (retrievedSlang.length > 0) {
    context = 'Known slang terms found in the message:\n\n';
    retrievedSlang.forEach(match => {
      const meta = match.metadata;
      context += `Term: "${meta.term}"\n`;
      context += `Definition: ${meta.definition}\n`;
      context += `Usage: ${meta.usage}\n`;
      context += `Examples: ${meta.examples}\n\n`;
    });
  }
  
  // Generate explanation with Claude
  const prompt = `${context}

User message: "${message}"

Analyze this message for slang, idioms, or Gen Z expressions. For each term found, provide:
1. The exact phrase from the message
2. What it means in simple terms
3. Brief context about who uses it

Return ONLY a JSON object:
{
  "hasContext": true/false,
  "hints": [
    {
      "phrase": "exact term",
      "explanation": "context (e.g., Gen Z slang for...)",
      "literalMeaning": "if applicable",
      "actualMeaning": "simple explanation"
    }
  ]
}`;

  const response = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': claudeApiKey,
      'anthropic-version': '2023-06-01'
    },
    body: JSON.stringify({
      model: 'claude-3-5-sonnet-20241022',
      max_tokens: 1000,
      messages: [{ role: 'user', content: prompt }],
      temperature: 0.3
    })
  });
  
  const result = await response.json();
  return JSON.parse(result.content[0].text);
}

// Main handler
exports.handler = async (event) => {
  console.log('[RAG] Event:', JSON.stringify(event));
  
  try {
    await initPinecone();
    
    const body = JSON.parse(event.body);
    const { message } = body;
    
    if (!message) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'Message required' })
      };
    }
    
    // Step 1: Retrieve relevant slang from vector DB
    console.log('[RAG] Retrieving slang for:', message);
    const retrievedSlang = await retrieveRelevantSlang(message);
    console.log(`[RAG] Found ${retrievedSlang.length} relevant slang terms`);
    
    // Step 2: Generate explanation with Claude + context
    const explanation = await generateExplanation(message, retrievedSlang);
    
    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({
        success: true,
        result: explanation,
        retrieved_terms: retrievedSlang.map(m => m.metadata.term)
      })
    };
    
  } catch (error) {
    console.error('[RAG] Error:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: error.message })
    };
  }
};
```

---

### **Phase 4: WebSocket Integration**

#### **File: `backend/websocket/rag-handler.js`**
```javascript
/**
 * WebSocket handler for RAG queries
 * Routes slang explanation requests to RAG Lambda
 */

const { LambdaClient, InvokeCommand } = require('@aws-sdk/client-lambda');
const lambda = new LambdaClient({ region: 'us-east-1' });

exports.handler = async (event) => {
  const body = JSON.parse(event.body);
  const { action, message, messageId } = body;
  
  if (action !== 'explain_slang') {
    return { statusCode: 400, body: JSON.stringify({ error: 'Invalid action' }) };
  }
  
  try {
    // Invoke RAG Lambda
    const response = await lambda.send(new InvokeCommand({
      FunctionName: 'rag-slang_AlexHo',
      Payload: JSON.stringify({
        body: JSON.stringify({ message })
      })
    }));
    
    const result = JSON.parse(Buffer.from(response.Payload).toString());
    const explanation = JSON.parse(result.body);
    
    // Send back via WebSocket
    const connectionId = event.requestContext.connectionId;
    const domain = event.requestContext.domainName;
    const stage = event.requestContext.stage;
    
    const { ApiGatewayManagementApiClient, PostToConnectionCommand } = require('@aws-sdk/client-apigatewaymanagementapi');
    const apiGw = new ApiGatewayManagementApiClient({
      endpoint: `https://${domain}/${stage}`
    });
    
    await apiGw.send(new PostToConnectionCommand({
      ConnectionId: connectionId,
      Data: JSON.stringify({
        type: 'slang_explanation',
        messageId,
        data: explanation.result
      })
    }));
    
    return { statusCode: 200, body: JSON.stringify({ success: true }) };
    
  } catch (error) {
    console.error('[RAG WS] Error:', error);
    return { statusCode: 500, body: JSON.stringify({ error: error.message }) };
  }
};
```

---

### **Phase 5: Update iOS Client**

#### **Add to `WebSocketService.swift`:**
```swift
func requestSlangExplanation(message: String, messageId: String) {
    let payload: [String: Any] = [
        "action": "explain_slang",
        "message": message,
        "messageId": messageId
    ]
    
    sendJSON(payload)
    print("🔍 Requested slang explanation for message: \(messageId)")
}

// Handle slang explanation response
case "slang_explanation":
    if let messageId = payload["messageId"] as? String,
       let data = payload["data"] as? [String: Any] {
        await handleSlangExplanation(messageId: messageId, data: data)
    }
```

---

## 📊 **Complete Setup Steps**

### **Step 1: Set Up Pinecone**
```bash
# 1. Sign up at pinecone.io
# 2. Get API key and environment
# 3. Create index via dashboard or API
```

### **Step 2: Store Credentials**
```bash
# Store Pinecone credentials
aws secretsmanager create-secret \
  --name pinecone-credentials-alexho \
  --secret-string '{"apiKey":"YOUR_KEY","environment":"YOUR_ENV"}' \
  --region us-east-1

# Store OpenAI key (for embeddings)
aws secretsmanager create-secret \
  --name openai-api-key-alexho \
  --secret-string '{"apiKey":"YOUR_OPENAI_KEY"}' \
  --region us-east-1
```

### **Step 3: Deploy Infrastructure**
```bash
cd backend/rag

# Install dependencies
npm install @pinecone-database/pinecone openai @aws-sdk/client-secrets-manager

# Run ingestion (one-time setup)
node ingest-slang.js

# Deploy RAG Lambda
zip -r rag-slang.zip rag-slang.js node_modules/
aws lambda create-function \
  --function-name rag-slang_AlexHo \
  --runtime nodejs20.x \
  --handler rag-slang.handler \
  --zip-file fileb://rag-slang.zip \
  --role arn:aws:iam::ACCOUNT:role/MessageAI-Lambda-Role \
  --timeout 30 \
  --memory-size 512 \
  --environment Variables="{
    PINECONE_API_KEY=from_secrets,
    PINECONE_ENV=from_secrets,
    OPENAI_API_KEY=from_secrets
  }"
```

### **Step 4: Update Slang Database Regularly**
```bash
# Set up EventBridge rule to run monthly
aws events put-rule \
  --name update-slang-database \
  --schedule-expression "rate(30 days)"

# Or manually trigger when needed
node ingest-slang.js
```

---

## 💰 **Cost Breakdown**

### **Pinecone (Free Tier)**
- 1 index
- 100K vectors (enough for 10K+ slang terms)
- Cost: **$0/month**

### **OpenAI Embeddings**
- text-embedding-ada-002: $0.0001 per 1K tokens
- 1000 slang terms × 100 tokens = 100K tokens
- Cost: **$0.01 one-time** + **$0.01/month for updates**

### **Claude API**
- Same as before: ~$0.09/user/month

### **Total: ~$0.10/user/month** (same as before, but with RAG!)

---

## 🎯 **Benefits of RAG Approach**

### **vs. Direct Claude Queries:**
- ✅ **Always up-to-date** - Add new slang without redeploying
- ✅ **Faster** - Vector search is instant
- ✅ **More accurate** - Curated slang database
- ✅ **Cheaper** - Smaller context = fewer tokens
- ✅ **Scalable** - Vector DB handles millions of terms

### **vs. Training Custom Model:**
- ✅ **No training needed** - Just add to database
- ✅ **Update instantly** - New slang available immediately
- ✅ **No infrastructure** - Pinecone handles everything
- ✅ **Better explanations** - Claude provides context

---

## 📈 **Maintenance & Updates**

### **Adding New Slang:**
```bash
# 1. Edit slang-database.json
# 2. Run ingestion
node ingest-slang.js
# 3. Done! Live immediately
```

### **Auto-Update from Sources:**
```javascript
// Future: Scrape Urban Dictionary, Twitter trends, TikTok
async function autoUpdateSlang() {
  const trendingSlang = await scrapeTikTokTrends();
  const urbanDictSlang = await fetchUrbanDictionary();
  
  // Merge with existing database
  await ingestNewTerms([...trendingSlang, ...urbanDictSlang]);
}
```

---

## 🚀 **Next Steps**

1. **Sign up for Pinecone** (5 min)
2. **Run ingestion script** (10 min)
3. **Deploy RAG Lambda** (15 min)
4. **Test with iOS app** (5 min)
5. **Add more slang terms** (ongoing)

Total setup time: **~45 minutes**

---

## ✨ **Result**

Users will get:
- ✅ Instant slang explanations
- ✅ Always current with latest slang
- ✅ Curated, accurate definitions
- ✅ Context-aware explanations
- ✅ No wait for model updates

Perfect for keeping up with Gen Z! 🎉
