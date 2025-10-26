/**
 * WebSocket Typing Indicator Handler
 * Broadcasts typing status to the recipient in a conversation
 */
const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, QueryCommand } = require("@aws-sdk/lib-dynamodb");
const { ApiGatewayManagementApiClient, PostToConnectionCommand } = require("@aws-sdk/client-apigatewaymanagementapi");

const client = new DynamoDBClient({ region: process.env.AWS_REGION || "us-east-1" });
const docClient = DynamoDBDocumentClient.from(client);

const CONNECTIONS_TABLE = process.env.CONNECTIONS_TABLE || "Connections_AlexHo";

exports.handler = async (event) => {
  console.log("Typing Event:", JSON.stringify(event, null, 2));
  
  const domain = event.requestContext?.domainName;
  const stage = event.requestContext?.stage;
  
  let body;
  try {
    body = JSON.parse(event.body || "{}");
  } catch (e) {
    console.error("Bad JSON body", e);
    return { statusCode: 400, body: JSON.stringify({ error: "Invalid body" }) };
  }
  
  const { conversationId, senderId, senderName, recipientId, isTyping } = body;
  
  if (!conversationId || !senderId || !senderName || !recipientId || typeof isTyping !== "boolean") {
    return { 
      statusCode: 400, 
      body: JSON.stringify({ error: "conversationId, senderId, senderName, recipientId, and isTyping required" }) 
    };
  }
  
  try {
    // Find recipient's connections
    const recipientConnections = await docClient.send(new QueryCommand({
      TableName: CONNECTIONS_TABLE,
      IndexName: "userId-index",
      KeyConditionExpression: "userId = :u",
      ExpressionAttributeValues: { ":u": recipientId }
    }));
    
    console.log(`Found ${recipientConnections.Items?.length || 0} connections for recipient ${recipientId}`);
    
    // Send typing indicator to recipient
    const api = new ApiGatewayManagementApiClient({
      region: process.env.AWS_REGION || "us-east-1",
      endpoint: `https://${domain}/${stage}`
    });
    
    const typingData = JSON.stringify({
      type: "typing",
      data: {
        conversationId,
        senderId,
        senderName,
        isTyping
      }
    });
    
    for (const conn of (recipientConnections.Items || [])) {
      try {
        await api.send(new PostToConnectionCommand({
          ConnectionId: conn.connectionId,
          Data: Buffer.from(typingData)
        }));
        console.log(`✅ Sent typing indicator to connection ${conn.connectionId}`);
      } catch (sendErr) {
        if (sendErr.statusCode === 410) {
          console.log(`Stale connection ${conn.connectionId}, skipping`);
        } else {
          console.error(`Failed to send to ${conn.connectionId}:`, sendErr);
        }
      }
    }
    
    return { statusCode: 200, body: JSON.stringify({ success: true }) };
    
  } catch (e) {
    console.error("Typing handler error:", e);
    return { statusCode: 500, body: JSON.stringify({ error: "Failed to send typing indicator" }) };
  }
};
