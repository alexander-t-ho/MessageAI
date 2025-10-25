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

// Retrieve ALL slang from DynamoDB (let GPT-4 decide what's relevant)
async function retrieveAllSlang() {
  console.log('[RAG-Simple] Retrieving ALL slang from DynamoDB...');
  
  try {
    const result = await docClient.send(new ScanCommand({
      TableName: SLANG_TABLE
    }));
    
    if (!result.Items || result.Items.length === 0) {
      console.log('[RAG-Simple] WARNING: No slang in database!');
      return [];
    }
    
    console.log(`[RAG-Simple] Loaded ${result.Items.length} slang terms from database`);
    return result.Items;
    
  } catch (error) {
    console.error('[RAG-Simple] Error loading slang database:', error);
    return []; // Fallback to empty - GPT-4 will still work
  }
}

// Generate explanation with OpenAI (in user's preferred language)
async function generateExplanation(message, relevantSlang, openaiApiKey, targetLang = 'en') {
  console.log(`[RAG-Simple] Generating explanation with OpenAI GPT-4 in ${targetLang}...`);
  
  // Language names for the prompt
  const languageNames = {
    'en': 'English',
    'es': 'Spanish',
    'fr': 'French',
    'de': 'German',
    'it': 'Italian',
    'pt': 'Portuguese',
    'ru': 'Russian',
    'ja': 'Japanese',
    'ko': 'Korean',
    'zh': 'Chinese',
    'ar': 'Arabic',
    'hi': 'Hindi',
    'nl': 'Dutch',
    'sv': 'Swedish',
    'pl': 'Polish',
    'tr': 'Turkish',
    'vi': 'Vietnamese',
    'th': 'Thai',
    'id': 'Indonesian',
    'he': 'Hebrew'
  };
  
  const targetLanguageName = languageNames[targetLang] || 'English';
  
  // Build rich context from ALL slang in database
  let knownSlang = '';
  if (relevantSlang.length > 0) {
    knownSlang = 'Reference slang database (use as hints, but detect ANY slang you find):\n\n';
    relevantSlang.forEach(slang => {
      knownSlang += `- "${slang.term}": ${slang.definition}\n`;
    });
    knownSlang += '\n';
  }
  
  const prompt = `${knownSlang}You are an expert on Gen Z slang, internet culture, and youth language.

Analyze this message and detect ANY slang, abbreviations, or youth expressions:

"${message}"

Common slang to watch for (detect these even if not in reference list):
- rizz (charisma), no cap (no lie), bussin (really good), slay (do amazingly)
- fr/frfr (for real), ngl (not gonna lie), iykyk (if you know you know)
- lowkey/highkey, vibe check, mid, fire, lit, bet, cap, flex, simp

For EACH slang term or expression found, explain it clearly **in ${targetLanguageName}**.

CRITICAL: 
- Detect slang EVEN IF not in the reference list above
- "rizz", "bussin", "no cap" are DEFINITELY slang - always detect them!
- Keep original slang term in "phrase" field (don't translate the term itself)
- Write explanation and meaning in ${targetLanguageName}

Return ONLY valid JSON:
{
  "hasContext": true/false,
  "hints": [
    {
      "phrase": "exact term from message (in original language)",
      "explanation": "who uses this, in ${targetLanguageName}",
      "literalMeaning": "literal meaning in ${targetLanguageName}, or empty string",
      "actualMeaning": "simple explanation in ${targetLanguageName}"
    }
  ]
}

If absolutely NO slang exists, return {"hasContext": false, "hints": []}`;

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
    const { message, targetLang = 'en' } = body;
    
    if (!message) {
      return {
        statusCode: 400,
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ error: 'Message required' })
      };
    }
    
    console.log(`[RAG-Simple] Target language: ${targetLang}`);
    
    // Check cache first (cache key includes language)
    const cacheKey = `${targetLang}:${message}`;
    const cached = await checkCache(cacheKey);
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
    
    // Step 1: Retrieve ALL slang from DynamoDB (GPT-4 will filter)
    const allSlang = await retrieveAllSlang();
    console.log(`[RAG-Simple] Using ${allSlang.length} slang terms as context`);
    
    // Step 2: Generate explanation with OpenAI GPT-4 in target language
    // GPT-4 is smart enough to detect slang even without perfect keyword matches
    const explanation = await generateExplanation(message, allSlang, openaiApiKey, targetLang);
    
    // Cache the result
    await storeCache(message, explanation);
    
    return {
      statusCode: 200,
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        success: true,
        result: explanation,
        fromCache: false,
        databaseSize: allSlang.length,
        detectedCount: explanation.hints?.length || 0
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
