/**
 * WebSocket handler for Translate & Explain action
 * Does BOTH translation and slang explanation
 */

const { LambdaClient, InvokeCommand } = require("@aws-sdk/client-lambda");
const { ApiGatewayManagementApiClient, PostToConnectionCommand } = require("@aws-sdk/client-apigatewaymanagementapi");
const { SecretsManagerClient, GetSecretValueCommand } = require("@aws-sdk/client-secrets-manager");

const lambda = new LambdaClient({ region: "us-east-1" });
const secretsClient = new SecretsManagerClient({ region: "us-east-1" });

// Get OpenAI API key for direct translation (faster than Lambda invoke)
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

// Translate text using OpenAI directly
async function translateText(text, targetLang, apiKey) {
  try {
    const response = await fetch('https://api.openai.com/v1/chat/completions', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${apiKey}`
      },
      body: JSON.stringify({
        model: 'gpt-4',
        messages: [{
          role: 'system',
          content: `You are a professional translator. Translate the following text to ${targetLang}. 
                   Maintain the tone and style. Only respond with the translation, nothing else.`
        }, {
          role: 'user',
          content: text
        }],
        temperature: 0.3,
        max_tokens: 500
      })
    });
    
    const data = await response.json();
    if (!response.ok) {
      throw new Error(`OpenAI API error: ${JSON.stringify(data)}`);
    }
    
    return data.choices[0].message.content.trim();
  } catch (error) {
    console.error("[translateAndExplain] Translation error:", error);
    return null;
  }
}

exports.handler = async (event) => {
  console.log("[translateAndExplain] Request:", JSON.stringify(event));
  
  const connectionId = event.requestContext.connectionId;
  const domain = event.requestContext.domainName;
  const stage = event.requestContext.stage;
  
  const apiGw = new ApiGatewayManagementApiClient({
    endpoint: `https://${domain}/${stage}`
  });
  
  try {
    const body = JSON.parse(event.body);
    const { message, messageId, targetLang = 'es' } = body;
    
    console.log(`[translateAndExplain] Message: "${message}", Target Language: ${targetLang}`);
    
    // Get OpenAI API key
    const apiKey = await getOpenAIApiKey();
    
    // Run translation and slang detection in parallel
    const [translationResult, slangResult] = await Promise.all([
      // 1. Translate the text
      translateText(message, targetLang, apiKey),
      
      // 2. Get slang explanation
      lambda.send(new InvokeCommand({
        FunctionName: "rag-slang_AlexHo",
        Payload: JSON.stringify({
          body: JSON.stringify({ message, targetLang })
        })
      })).then(response => {
        const lambdaResult = JSON.parse(Buffer.from(response.Payload).toString());
        if (lambdaResult.statusCode === 200) {
          return JSON.parse(lambdaResult.body);
        }
        return null;
      }).catch(err => {
        console.error("[translateAndExplain] Slang detection error:", err);
        return null;
      })
    ]);
    
    console.log(`[translateAndExplain] Translation: ${translationResult}`);
    console.log(`[translateAndExplain] Slang result:`, JSON.stringify(slangResult));
    
    // Send combined result back to client
    const response = {
      type: 'translate_and_explain',
      messageId,
      translation: {
        success: !!translationResult,
        translatedText: translationResult,
        targetLanguage: targetLang,
        sourceLanguage: 'auto'
      },
      slang: slangResult ? {
        success: slangResult.success,
        hasContext: slangResult.result?.hasContext || false,
        hints: slangResult.result?.hints || []
      } : {
        success: false,
        hasContext: false,
        hints: []
      }
    };
    
    console.log(`[translateAndExplain] Sending response:`, JSON.stringify(response));
    
    await apiGw.send(new PostToConnectionCommand({
      ConnectionId: connectionId,
      Data: JSON.stringify(response)
    }));
    
    return { statusCode: 200, body: JSON.stringify({ success: true }) };
    
  } catch (error) {
    console.error("[translateAndExplain] Error:", error);
    
    // Send error to client
    try {
      await apiGw.send(new PostToConnectionCommand({
        ConnectionId: connectionId,
        Data: JSON.stringify({
          type: 'translate_and_explain_error',
          messageId: body?.messageId,
          error: error.message
        })
      }));
    } catch (sendError) {
      console.error("[translateAndExplain] Error sending error message:", sendError);
    }
    
    return {
      statusCode: 500,
      body: JSON.stringify({ error: error.message })
    };
  }
};
