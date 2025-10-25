/**
 * AI Translation Service Lambda
 * Handles real-time translation using Claude 3.5 Sonnet
 */

const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, GetCommand, PutCommand } = require("@aws-sdk/lib-dynamodb");
const { SecretsManagerClient, GetSecretValueCommand } = require("@aws-sdk/client-secrets-manager");

const client = new DynamoDBClient({ region: process.env.AWS_REGION || "us-east-1" });
const docClient = DynamoDBDocumentClient.from(client);
const secretsClient = new SecretsManagerClient({ region: process.env.AWS_REGION || "us-east-1" });

const TRANSLATIONS_CACHE_TABLE = process.env.TRANSLATIONS_CACHE_TABLE || "TranslationsCache_AlexHo";
const CACHE_TTL_HOURS = 24 * 7; // Cache for 1 week

// Get OpenAI API key from AWS Secrets Manager
async function getOpenAIApiKey() {
  try {
    const response = await secretsClient.send(
      new GetSecretValueCommand({
        SecretId: "openai-api-key-alexho",
        VersionStage: "AWSCURRENT",
      })
    );
    const secret = JSON.parse(response.SecretString);
    return secret.apiKey;
  } catch (error) {
    console.error("[translate] Error getting OpenAI API key:", error);
    throw new Error("Failed to retrieve API key");
  }
}

// Generate cache key for translation
function generateCacheKey(text, targetLang, feature) {
  const normalized = text.toLowerCase().trim().substring(0, 500);
  return `${feature}:${targetLang}:${Buffer.from(normalized).toString('base64')}`;
}

// Check cache for existing translation
async function checkCache(cacheKey) {
  try {
    const response = await docClient.send(new GetCommand({
      TableName: TRANSLATIONS_CACHE_TABLE,
      Key: { cacheKey }
    }));
    
    if (response.Item && response.Item.expiresAt > Date.now() / 1000) {
      console.log("[translate] Cache hit for key:", cacheKey);
      return response.Item;
    }
  } catch (error) {
    console.log("[translate] Cache check error (non-fatal):", error.message);
  }
  return null;
}

// Store translation in cache
async function storeCache(cacheKey, data) {
  try {
    await docClient.send(new PutCommand({
      TableName: TRANSLATIONS_CACHE_TABLE,
      Item: {
        cacheKey,
        ...data,
        expiresAt: Math.floor(Date.now() / 1000) + (CACHE_TTL_HOURS * 3600),
        createdAt: new Date().toISOString()
      }
    }));
  } catch (error) {
    console.log("[translate] Cache store error (non-fatal):", error.message);
  }
}

// Call Claude API for translation
async function callClaude(apiKey, messages) {
  const response = await fetch('https://api.anthropic.com/v1/messages', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'x-api-key': apiKey,
      'anthropic-version': '2023-06-01'
    },
    body: JSON.stringify({
      model: 'claude-3-5-sonnet-20241022',
      max_tokens: 1500,
      messages,
      temperature: 0.3 // Lower temperature for more consistent translations
    })
  });

  if (!response.ok) {
    const error = await response.text();
    throw new Error(`Claude API error: ${response.status} - ${error}`);
  }

  return await response.json();
}

// Main translation function
async function translateText(text, targetLang, sourceLang = 'auto', apiKey) {
  const cacheKey = generateCacheKey(text, targetLang, 'translate');
  
  // Check cache first
  const cached = await checkCache(cacheKey);
  if (cached) {
    return {
      translatedText: cached.translatedText,
      detectedLanguage: cached.detectedLanguage,
      fromCache: true
    };
  }

  // Prepare Claude prompt
  const prompt = `Translate the following text to ${targetLang}. 
If the source language is 'auto', detect it first.
Preserve the tone, formality level, and any cultural nuances.
Return ONLY a JSON object with this exact format:
{
  "translatedText": "the translation",
  "detectedLanguage": "detected source language code (e.g., 'en', 'es', 'zh')",
  "confidence": 0.95
}

Text to translate: "${text}"`;

  const claudeResponse = await callClaude(apiKey, [
    { role: 'user', content: prompt }
  ]);

  try {
    const result = JSON.parse(claudeResponse.content[0].text);
    
    // Store in cache
    await storeCache(cacheKey, result);
    
    return {
      ...result,
      fromCache: false
    };
  } catch (parseError) {
    // Fallback if JSON parsing fails
    return {
      translatedText: claudeResponse.content[0].text,
      detectedLanguage: sourceLang === 'auto' ? 'unknown' : sourceLang,
      confidence: 0.8,
      fromCache: false
    };
  }
}

// Get cultural context hints and slang explanations (in target language)
async function getCulturalContext(text, sourceLang, targetLang, apiKey) {
  const cacheKey = generateCacheKey(text, `${sourceLang}-${targetLang}`, 'cultural');
  
  const cached = await checkCache(cacheKey);
  if (cached) {
    return cached.culturalHints;
  }

  // Language names for better prompt
  const languageNames = {
    'en': 'English', 'es': 'Spanish', 'fr': 'French', 'de': 'German',
    'it': 'Italian', 'pt': 'Portuguese', 'ru': 'Russian', 'ja': 'Japanese',
    'ko': 'Korean', 'zh': 'Chinese', 'ar': 'Arabic', 'hi': 'Hindi'
  };
  const targetLangName = languageNames[targetLang] || 'English';

  const prompt = `Analyze this text for slang, idioms, cultural references, or Gen Z/youth expressions that an older reader might not understand.

Focus on:
- Modern slang (e.g., "rizz", "no cap", "bussin", "slay", "stan", "ghosting", "situationship")
- Internet/social media language (e.g., "FR", "ngl", "iykyk", "periodt")
- Cultural references that need context
- Idioms that don't translate literally
- Regional or generational expressions

For EACH slang term or expression found, explain it clearly **in ${targetLangName}**.

IMPORTANT:
- Keep the original slang term in the "phrase" field (don't translate the term itself)
- Write the explanation, literalMeaning, and actualMeaning in ${targetLangName}
- Make it easy for a ${targetLangName} speaker to understand

Return ONLY a JSON object with this format:
{
  "hasContext": true/false,
  "hints": [
    {
      "phrase": "the exact slang term from the message (in original language)",
      "explanation": "explanation in ${targetLangName} (e.g., 'Jerga de la Generación Z que significa...' if Spanish)",
      "literalMeaning": "literal meaning in ${targetLangName} if applicable, otherwise empty",
      "actualMeaning": "what it actually means in ${targetLangName}"
    }
  ]
}

Important: Only include terms that might confuse someone unfamiliar with youth/internet culture.

Text to analyze: "${text}"`;

  // Call OpenAI instead of Claude
  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Content-Type': 'application/json',
      'Authorization': `Bearer ${apiKey}`
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
    console.error('[cultural] OpenAI API error:', response.status);
    return { hasContext: false, hints: [] };
  }

  try {
    const openaiResult = await response.json();
    const result = JSON.parse(openaiResult.choices[0].message.content);
    await storeCache(cacheKey, { culturalHints: result });
    return result;
  } catch (parseError) {
    console.log('[cultural] Parse error, returning empty hints');
    return { hasContext: false, hints: [] };
  }
}

// Detect and adjust formality level
async function adjustFormality(text, targetLang, desiredLevel, apiKey) {
  const cacheKey = generateCacheKey(text, `${targetLang}-${desiredLevel}`, 'formality');
  
  const cached = await checkCache(cacheKey);
  if (cached) {
    return cached.adjustedText;
  }

  const prompt = `Adjust the formality level of this ${targetLang} text to be ${desiredLevel}.
Formality levels: casual, neutral, formal, very_formal
Keep the meaning exactly the same, only adjust the formality.
Return ONLY a JSON object:
{
  "adjustedText": "the adjusted text",
  "originalLevel": "detected formality level",
  "changes": ["list of what was changed"]
}

Text: "${text}"
Desired level: ${desiredLevel}`;

  const claudeResponse = await callClaude(apiKey, [
    { role: 'user', content: prompt }
  ]);

  try {
    const result = JSON.parse(claudeResponse.content[0].text);
    await storeCache(cacheKey, { adjustedText: result });
    return result;
  } catch (parseError) {
    return { adjustedText: text, originalLevel: 'neutral', changes: [] };
  }
}

// Generate smart reply suggestions
async function generateSmartReplies(conversationContext, userLang, apiKey) {
  const prompt = `Based on this conversation, suggest 3 contextually appropriate quick replies in ${userLang}.
Consider the conversation tone, topic, and cultural appropriateness.
The replies should be natural and fit the user's typical communication style.

Conversation context:
${conversationContext}

Return ONLY a JSON object:
{
  "replies": [
    {
      "text": "reply text",
      "tone": "casual/neutral/formal",
      "intent": "brief description of intent"
    }
  ]
}`;

  const claudeResponse = await callClaude(apiKey, [
    { role: 'user', content: prompt }
  ]);

  try {
    return JSON.parse(claudeResponse.content[0].text);
  } catch (parseError) {
    return { replies: [] };
  }
}

// Lambda handler
exports.handler = async (event) => {
  console.log("[translate] Request received:", JSON.stringify(event));
  
  try {
    const body = JSON.parse(event.body);
    const { action, text, targetLang, sourceLang, desiredLevel, conversationContext } = body;
    
    // Get API key
    const apiKey = await getOpenAIApiKey();
    
    let result;
    
    switch (action) {
      case 'translate':
        result = await translateText(text, targetLang, sourceLang || 'auto', apiKey);
        break;
        
      case 'cultural_context':
        result = await getCulturalContext(text, sourceLang, targetLang, apiKey);
        break;
        
      case 'adjust_formality':
        result = await adjustFormality(text, targetLang, desiredLevel, apiKey);
        break;
        
      case 'smart_replies':
        result = await generateSmartReplies(conversationContext, targetLang || 'en', apiKey);
        break;
        
      default:
        throw new Error(`Unknown action: ${action}`);
    }
    
    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({
        success: true,
        action,
        result
      })
    };
    
  } catch (error) {
    console.error("[translate] Error:", error);
    return {
      statusCode: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({
        success: false,
        error: error.message
      })
    };
  }
};
