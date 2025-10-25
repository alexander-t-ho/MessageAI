/**
 * WebSocket handler for Explain Slang action
 * Invokes RAG Lambda and returns result via WebSocket
 */

const { LambdaClient, InvokeCommand } = require("@aws-sdk/client-lambda");
const { ApiGatewayManagementApiClient, PostToConnectionCommand } = require("@aws-sdk/client-apigatewaymanagementapi");

const lambda = new LambdaClient({ region: "us-east-1" });

exports.handler = async (event) => {
  console.log("[explainSlang] Request:", JSON.stringify(event));
  
  const connectionId = event.requestContext.connectionId;
  const domain = event.requestContext.domainName;
  const stage = event.requestContext.stage;
  
  const apiGw = new ApiGatewayManagementApiClient({
    endpoint: `https://${domain}/${stage}`
  });
  
  try {
    const body = JSON.parse(event.body);
    const { message, messageId, targetLang = 'en' } = body;
    
    console.log(`[explainSlang] Message: "${message}", Language: ${targetLang}`);
    
    // Invoke RAG Lambda
    const invokeResponse = await lambda.send(new InvokeCommand({
      FunctionName: "rag-slang_AlexHo",
      Payload: JSON.stringify({
        body: JSON.stringify({ message, targetLang })
      })
    }));
    
    // Parse Lambda response
    const lambdaResult = JSON.parse(Buffer.from(invokeResponse.Payload).toString());
    const ragResponse = JSON.parse(lambdaResult.body);
    
    console.log(`[explainSlang] RAG result:`, JSON.stringify(ragResponse));
    
    // Send result back to client via WebSocket
    await apiGw.send(new PostToConnectionCommand({
      ConnectionId: connectionId,
      Data: JSON.stringify({
        type: 'slang_explanation',
        messageId,
        data: ragResponse.result,
        fromCache: ragResponse.fromCache,
        success: ragResponse.success
      })
    }));
    
    return { statusCode: 200, body: JSON.stringify({ success: true }) };
    
  } catch (error) {
    console.error("[explainSlang] Error:", error);
    
    // Send error to client
    try {
      await apiGw.send(new PostToConnectionCommand({
        ConnectionId: connectionId,
        Data: JSON.stringify({
          type: 'slang_explanation_error',
          error: error.message
        })
      }));
    } catch (sendError) {
      console.error("[explainSlang] Error sending error message:", sendError);
    }
    
    return {
      statusCode: 500,
      body: JSON.stringify({ error: error.message })
    };
  }
};
