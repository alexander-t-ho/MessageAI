/**
 * RAG Lambda with LangChain
 * Orchestrates: Pinecone (retrieval) → Claude (generation)
 */

const { ChatAnthropic } = require("@langchain/anthropic");
const { PineconeStore } = require("@langchain/community/vectorstores/pinecone");
const { OpenAIEmbeddings } = require("@langchain/openai");
const { RetrievalQAChain } = require("langchain/chains");
const { PromptTemplate } = require("@langchain/core/prompts");
const { PineconeClient } = require("@pinecone-database/pinecone");
const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, GetCommand, PutCommand } = require("@aws-sdk/lib-dynamodb");
const { SecretsManagerClient, GetSecretValueCommand } = require("@aws-sdk/client-secrets-manager");

// Initialize clients
const secretsClient = new SecretsManagerClient({ region: "us-east-1" });
const dynamoClient = new DynamoDBClient({ region: "us-east-1" });
const docClient = DynamoDBDocumentClient.from(dynamoClient);

const CACHE_TABLE = "TranslationsCache_AlexHo";
const CACHE_TTL_HOURS = 24 * 7;

// Global variables for cold start optimization
let pineconeStore = null;
let llm = null;
let ragChain = null;

// Get API keys from Secrets Manager
async function getSecrets() {
  const [pineconeSecret, claudeSecret, openaiSecret] = await Promise.all([
    secretsClient.send(new GetSecretValueCommand({ SecretId: "pinecone-credentials-alexho" })),
    secretsClient.send(new GetSecretValueCommand({ SecretId: "claude-api-key-alexho" })),
    secretsClient.send(new GetSecretValueCommand({ SecretId: "openai-api-key-alexho" }))
  ]);
  
  return {
    pinecone: JSON.parse(pineconeSecret.SecretString),
    claude: JSON.parse(claudeSecret.SecretString),
    openai: JSON.parse(openaiSecret.SecretString)
  };
}

// Initialize LangChain components (only once per Lambda container)
async function initializeLangChain() {
  if (ragChain) {
    console.log("[RAG] Using cached chain");
    return ragChain;
  }
  
  console.log("[RAG] Initializing LangChain components...");
  const secrets = await getSecrets();
  
  // Initialize Pinecone
  const pinecone = new PineconeClient();
  await pinecone.init({
    apiKey: secrets.pinecone.apiKey,
    environment: secrets.pinecone.environment
  });
  
  // Create vector store
  pineconeStore = await PineconeStore.fromExistingIndex(
    new OpenAIEmbeddings({
      openAIApiKey: secrets.openai.apiKey,
      modelName: "text-embedding-ada-002"
    }),
    {
      pineconeIndex: pinecone.Index("slang-rag"),
      namespace: "slang"
    }
  );
  
  // Initialize Claude
  llm = new ChatAnthropic({
    modelName: "claude-3-5-sonnet-20241022",
    anthropicApiKey: secrets.claude.apiKey,
    temperature: 0.3,
    maxTokens: 1000
  });
  
  // Create prompt template
  const promptTemplate = PromptTemplate.fromTemplate(`
You are an expert at explaining modern slang, Gen Z language, and internet culture.

Based on these slang terms from the knowledge base:
{context}

Analyze this message for slang or expressions that might confuse an older reader:
"{question}"

For EACH slang term found, explain it clearly.

Return ONLY a JSON object with this exact format:
{{
  "hasContext": true/false,
  "hints": [
    {{
      "phrase": "exact term from message",
      "explanation": "who uses this (e.g., 'Gen Z slang for...', 'Internet abbreviation meaning...')",
      "literalMeaning": "literal translation if applicable, otherwise empty string",
      "actualMeaning": "what it actually means in simple terms"
    }}
  ]
}}

If no slang is found, return {{"hasContext": false, "hints": []}}
`);
  
  // Create RAG chain
  ragChain = RetrievalQAChain.fromLLM(
    llm,
    pineconeStore.asRetriever({
      k: 5, // Retrieve top 5 matches
      searchType: "similarity"
    }),
    {
      prompt: promptTemplate,
      returnSourceDocuments: true
    }
  );
  
  console.log("[RAG] LangChain initialized successfully");
  return ragChain;
}

// Check cache
async function checkCache(message) {
  try {
    const cacheKey = Buffer.from(message.toLowerCase().substring(0, 200)).toString('base64');
    const result = await docClient.send(new GetCommand({
      TableName: CACHE_TABLE,
      Key: { cacheKey: `slang:${cacheKey}` }
    }));
    
    if (result.Item && result.Item.expiresAt > Date.now() / 1000) {
      console.log("[RAG] Cache hit");
      return result.Item.explanation;
    }
  } catch (error) {
    console.log("[RAG] Cache miss or error:", error.message);
  }
  return null;
}

// Store in cache
async function storeCache(message, explanation) {
  try {
    const cacheKey = Buffer.from(message.toLowerCase().substring(0, 200)).toString('base64');
    await docClient.send(new PutCommand({
      TableName: CACHE_TABLE,
      Item: {
        cacheKey: `slang:${cacheKey}`,
        explanation,
        expiresAt: Math.floor(Date.now() / 1000) + (CACHE_TTL_HOURS * 3600),
        createdAt: new Date().toISOString()
      }
    }));
    console.log("[RAG] Cached result");
  } catch (error) {
    console.log("[RAG] Cache store error:", error.message);
  }
}

// Main Lambda handler
exports.handler = async (event) => {
  console.log("[RAG] Request:", JSON.stringify(event));
  
  try {
    const body = JSON.parse(event.body);
    const { message } = body;
    
    if (!message) {
      return {
        statusCode: 400,
        body: JSON.stringify({ error: "Message required" })
      };
    }
    
    // Check cache first
    const cached = await checkCache(message);
    if (cached) {
      return {
        statusCode: 200,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          success: true,
          result: cached,
          fromCache: true
        })
      };
    }
    
    // Initialize LangChain (cached across invocations)
    const chain = await initializeLangChain();
    
    // Run RAG query
    console.log("[RAG] Running query:", message);
    const result = await chain.call({ query: message });
    
    // Parse result
    let explanation;
    try {
      explanation = JSON.parse(result.text);
    } catch (parseError) {
      console.log("[RAG] Parse error, using raw text");
      explanation = {
        hasContext: false,
        hints: [],
        raw: result.text
      };
    }
    
    // Log sources for debugging
    if (result.sourceDocuments) {
      console.log("[RAG] Sources:", result.sourceDocuments.map(doc => doc.metadata.term).join(", "));
    }
    
    // Cache the result
    await storeCache(message, explanation);
    
    return {
      statusCode: 200,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        success: true,
        result: explanation,
        fromCache: false,
        sources: result.sourceDocuments ? 
          result.sourceDocuments.map(doc => doc.metadata.term) : []
      })
    };
    
  } catch (error) {
    console.error("[RAG] Error:", error);
    
    return {
      statusCode: 500,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        success: false,
        error: error.message,
        stack: error.stack
      })
    };
  }
};
