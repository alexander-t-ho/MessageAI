/**
 * Simplified WebSocket handler for Translate & Explain
 * Uses OpenAI for both translation and slang detection
 */

const { ApiGatewayManagementApiClient, PostToConnectionCommand } = require("@aws-sdk/client-apigatewaymanagementapi");
const { SecretsManagerClient, GetSecretValueCommand } = require("@aws-sdk/client-secrets-manager");
const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, ScanCommand } = require("@aws-sdk/lib-dynamodb");

const secretsClient = new SecretsManagerClient({ region: "us-east-1" });
const dynamoClient = new DynamoDBClient({ region: "us-east-1" });
const docClient = DynamoDBDocumentClient.from(dynamoClient);

// Get OpenAI API key
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
    console.error("[translateAndExplain] Error getting OpenAI API key:", error);
    throw new Error("Failed to retrieve API key");
  }
}

// Get all slang from DynamoDB
async function getAllSlang() {
  try {
    const response = await docClient.send(new ScanCommand({
      TableName: "SlangDatabase_AlexHo"
    }));
    return response.Items || [];
  } catch (error) {
    console.error("[translateAndExplain] Error getting slang database:", error);
    return [];
  }
}

// Use OpenAI to do BOTH translation and slang detection in one call
async function translateAndDetectSlang(text, targetLang, slangDatabase, apiKey) {
  try {
    // Create a slang reference for the prompt
    const slangList = slangDatabase.slice(0, 30).map(s => `"${s.term}": ${s.meaning}`).join(', ');
    
    const systemPrompt = `You are a helpful translator and cultural expert.

TASK 1 - TRANSLATION:
Translate the user's message to ${targetLang}. Be natural and conversational.

TASK 2 - SLANG DETECTION:
Check if the message contains any slang or informal language. Here are some common slang terms for reference:
${slangList}

Even if the slang isn't in the list, detect it if it's informal or trendy language (like "rizz", "bussin", "no cap", "fr", "slay", etc.).

RESPOND IN THIS EXACT JSON FORMAT:
{
  "translation": "your translation in ${targetLang}",
  "slang": [
    {
      "phrase": "the slang phrase in original language",
      "actualMeaning": "what it means in simple ${targetLang}",
      "explanation": "cultural context or origin explained in ${targetLang}",
      "literalMeaning": "literal word-for-word translation in ${targetLang} if applicable, or empty string"
    }
  ]
}

IMPORTANT:
- "actualMeaning" MUST be in ${targetLang} and NEVER be empty or undefined
- For "rizz": actualMeaning should be "Sức quyến rũ" (Vietnamese) or "Carisma" (Spanish)
- All fields except literalMeaning are REQUIRED
- If no slang detected, return: {"translation": "...", "slang": []}

ONLY return valid JSON, nothing else.`;

    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`
      },
      body: JSON.stringify({
        model: 'gpt-4',
        messages: [
          { role: 'system', content: systemPrompt },
          { role: 'user', content: text }
        ],
        temperature: 0.3,
        max_tokens: 800
      })
    });
    
    const data = await response.json();
    if (!response.ok) {
      throw new Error(`OpenAI API error: ${JSON.stringify(data)}`);
    }
    
    const content = data.choices[0].message.content.trim();
    console.log("[translateAndExplain] GPT-4 response:", content);
    
    // Parse the JSON response
    const result = JSON.parse(content);
    return result;
  } catch (error) {
    console.error("[translateAndExplain] OpenAI error:", error);
    return { translation: null, slang: [] };
  }
}

exports.handler = async (event) => {
  console.log("[translateAndExplain] Starting handler");
  console.log("[translateAndExplain] Event:", JSON.stringify(event));
  
  const connectionId = event.requestContext.connectionId;
  const domain = event.requestContext.domainName;
  const stage = event.requestContext.stage;
  
  const apiGw = new ApiGatewayManagementApiClient({
    endpoint: `https://${domain}/${stage}`
  });
  
  try {
    const body = JSON.parse(event.body);
    const { message, messageId, targetLang = 'es' } = body;
    
    console.log(`[translateAndExplain] Processing: "${message}" -> ${targetLang}`);
    
    // Get OpenAI API key and slang database
    const [apiKey, slangDatabase] = await Promise.all([
      getOpenAIApiKey(),
      getAllSlang()
    ]);
    
    console.log(`[translateAndExplain] Got API key and ${slangDatabase.length} slang terms`);
    
    // Do both translation and slang detection
    const result = await translateAndDetectSlang(message, targetLang, slangDatabase, apiKey);
    
    console.log("[translateAndExplain] Result:", JSON.stringify(result));
    
    // Format response for iOS app
    const response = {
      type: 'translate_and_explain',
      messageId,
      translation: {
        success: !!result.translation,
        translatedText: result.translation,
        targetLanguage: targetLang,
        sourceLanguage: 'auto'
      },
      slang: {
        success: true,
        hasContext: result.slang && result.slang.length > 0,
        hints: result.slang || []
      }
    };
    
    console.log("[translateAndExplain] Sending response:", JSON.stringify(response));
    
    // Send result back to client
    await apiGw.send(new PostToConnectionCommand({
      ConnectionId: connectionId,
      Data: JSON.stringify(response)
    }));
    
    console.log("[translateAndExplain] Success!");
    return { statusCode: 200, body: JSON.stringify({ success: true }) };
    
  } catch (error) {
    console.error("[translateAndExplain] Error:", error);
    console.error("[translateAndExplain] Stack:", error.stack);
    
    // Send error to client
    try {
      await apiGw.send(new PostToConnectionCommand({
        ConnectionId: connectionId,
        Data: JSON.stringify({
          type: 'translate_and_explain_error',
          error: error.message
        })
      }));
    } catch (sendError) {
      console.error("[translateAndExplain] Error sending error:", sendError);
    }
    
    return {
      statusCode: 500,
      body: JSON.stringify({ error: error.message })
    };
  }
};

