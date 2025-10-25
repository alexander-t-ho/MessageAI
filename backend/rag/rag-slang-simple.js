/**
 * Simplified RAG with DynamoDB (No Pinecone needed!)
 * Stores slang in DynamoDB, uses Claude for intelligent matching
 */

const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, GetCommand, PutCommand, ScanCommand } = require("@aws-sdk/lib-dynamodb");
const { SecretsManagerClient, GetSecretValueCommand } = require("@aws-sdk/client-secrets-manager");

const client = new DynamoDBClient({ region: "us-east-1" });
const docClient = DynamoDBDocumentClient.from(client);
const secretsClient = new SecretsManagerClient({ region: "us-east-1" });

const SLANG_TABLE = "SlangDatabase_AlexHo";
const CACHE_TABLE = "TranslationsCache_AlexHo";
const CACHE_TTL_HOURS = 24 * 7;

// Get OpenAI API key
async function getOpenAIKey() {
  const response = await secretsClient.send(
    new GetSecretValueCommand({ SecretId: "openai-api-key-alexho" })
  );
  return JSON.parse(response.SecretString).apiKey;
}

// Retrieve potentially relevant slang from DynamoDB
async function retrieveRelevantSlang(message) {
  console.log('[RAG-Simple] Retrieving slang from DynamoDB...');
  
  // Get all slang terms (small dataset, so scan is fine)
  const result = await docClient.send(new ScanCommand({
    TableName: SLANG_TABLE
  }));
  
  if (!result.Items || result.Items.length === 0) {
    console.log('[RAG-Simple] No slang in database, using empty context');
    return [];
  }
  
  console.log(`[RAG-Simple] Found ${result.Items.length} total slang terms`);
  
  // Use simple keyword matching to filter relevant terms
  const messageLower = message.toLowerCase();
  const relevantSlang = result.Items.filter(slang => {
    const term = slang.term.toLowerCase();
    const synonyms = JSON.parse(slang.synonyms || '[]').map(s => s.toLowerCase());
    
    // Check if term or any synonym appears in message
    return messageLower.includes(term) || synonyms.some(syn => messageLower.includes(syn));
  });
  
  console.log(`[RAG-Simple] Found ${relevantSlang.length} relevant terms:`, 
    relevantSlang.map(s => s.term).join(', '));
  
  return relevantSlang;
}

// Generate explanation with OpenAI
async function generateExplanation(message, relevantSlang, openaiApiKey) {
  console.log('[RAG-Simple] Generating explanation with OpenAI GPT-4...');
  
  // Build context from retrieved slang
  let context = '';
  if (relevantSlang.length > 0) {
    context = 'Known slang terms found in the message:\n\n';
    relevantSlang.forEach(slang => {
      context += `Term: "${slang.term}"\n`;
      context += `Definition: ${slang.definition}\n`;
      context += `Usage: ${slang.usage}\n`;
      context += `Examples: ${slang.examples}\n\n`;
    });
  }
  
  const prompt = `${context}

Analyze this message for slang, idioms, or Gen Z expressions that an older reader might not understand:

"${message}"

For EACH slang term or youth expression found, provide a clear explanation.

Return ONLY a JSON object with this exact format:
{
  "hasContext": true/false,
  "hints": [
    {
      "phrase": "exact term from message",
      "explanation": "who uses this (e.g., 'Gen Z slang for...', 'Internet abbreviation meaning...')",
      "literalMeaning": "literal translation if applicable, otherwise empty string",
      "actualMeaning": "what it actually means in simple terms"
    }
  ]
}

If no slang is found, return {"hasContext": false, "hints": []}`;

  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${openaiApiKey}`
    },
    body: JSON.stringify({
      model: 'gpt-4-turbo-preview',
      messages: [{ role: 'user', content: prompt }],
      temperature: 0.3,
      max_tokens: 1500,
      response_format: { type: 'json_object' }
    })
  });
  
  if (!response.ok) {
    const error = await response.text();
    throw new Error(`OpenAI API error: ${response.status} - ${error}`);
  }
  
  const result = await response.json();
  return JSON.parse(result.choices[0].message.content);
}

// Check cache
async function checkCache(message) {
  try {
    const cacheKey = `slang:${Buffer.from(message.toLowerCase().substring(0, 200)).toString('base64')}`;
    const result = await docClient.send(new GetCommand({
      TableName: CACHE_TABLE,
      Key: { cacheKey }
    }));
    
    if (result.Item && result.Item.expiresAt > Date.now() / 1000) {
      console.log('[RAG-Simple] Cache hit');
      return result.Item.explanation;
    }
  } catch (error) {
    console.log('[RAG-Simple] Cache miss:', error.message);
  }
  return null;
}

// Store in cache
async function storeCache(message, explanation) {
  try {
    const cacheKey = `slang:${Buffer.from(message.toLowerCase().substring(0, 200)).toString('base64')}`;
    await docClient.send(new PutCommand({
      TableName: CACHE_TABLE,
      Item: {
        cacheKey,
        explanation,
        expiresAt: Math.floor(Date.now() / 1000) + (CACHE_TTL_HOURS * 3600),
        createdAt: new Date().toISOString()
      }
    }));
    console.log('[RAG-Simple] Cached result');
  } catch (error) {
    console.log('[RAG-Simple] Cache error:', error.message);
  }
}

// Main handler
exports.handler = async (event) => {
  console.log('[RAG-Simple] Request:', JSON.stringify(event));
  
  try {
    const body = JSON.parse(event.body);
    const { message } = body;
    
    if (!message) {
      return {
        statusCode: 400,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ error: 'Message required' })
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
    
    // Get OpenAI API key
    const openaiApiKey = await getOpenAIKey();
    
    // Step 1: Retrieve relevant slang from DynamoDB
    const relevantSlang = await retrieveRelevantSlang(message);
    
    // Step 2: Generate explanation with OpenAI GPT-4
    const explanation = await generateExplanation(message, relevantSlang, openaiApiKey);
    
    // Cache the result
    await storeCache(message, explanation);
    
    return {
      statusCode: 200,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        success: true,
        result: explanation,
        fromCache: false,
        retrievedTerms: relevantSlang.map(s => s.term)
      })
    };
    
  } catch (error) {
    console.error('[RAG-Simple] Error:', error);
    return {
      statusCode: 500,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        success: false,
        error: error.message
      })
    };
  }
};
