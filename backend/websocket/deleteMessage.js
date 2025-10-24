/**
 * WebSocket Delete Message Handler
 * Updates message as deleted in DynamoDB and notifies the recipient
 */

import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, UpdateCommand, QueryCommand } from "@aws-sdk/lib-dynamodb";
import { ApiGatewayManagementApiClient, PostToConnectionCommand } from "@aws-sdk/client-apigatewaymanagementapi";

const client = new DynamoDBClient({ region: process.env.AWS_REGION || "us-east-1" });
const docClient = DynamoDBDocumentClient.from(client);

const MESSAGES_TABLE = process.env.MESSAGES_TABLE || "Messages_AlexHo";
const CONNECTIONS_TABLE = process.env.CONNECTIONS_TABLE || "Connections_AlexHo";

export const handler = async (event) => {
  console.log("Delete Message Event:", JSON.stringify(event, null, 2));
  const domain = event.requestContext?.domainName;
  const stage = event.requestContext?.stage;
  const connectionId = event.requestContext?.connectionId;

  let body;
  try { 
    body = JSON.parse(event.body || "{}"); 
  } catch (e) { 
    console.error('Bad JSON body', e); 
    return { statusCode: 400, body: JSON.stringify({ error: "Invalid body" }) };
  }
  
  const { messageId, conversationId, senderId, recipientId, recipientIds, isGroupChat } = body;
  
  if (!messageId || !conversationId || !senderId) {
    return { 
      statusCode: 400, 
      body: JSON.stringify({ error: "messageId, conversationId, and senderId required" }) 
    };
  }
  
  // For group chats, use recipientIds; for direct messages, use recipientId
  const allRecipientIds = isGroupChat && recipientIds ? recipientIds : [recipientId];
  
  try {
    // Update message as deleted in DynamoDB
    await docClient.send(new UpdateCommand({
      TableName: MESSAGES_TABLE,
      Key: { messageId },
      UpdateExpression: "SET #del = :true, #cont = :deletedText, deletedAt = :now, deletedBy = :sender",
      ExpressionAttributeNames: {
        "#del": "isDeleted",
        "#cont": "content"
      },
      ExpressionAttributeValues: {
        ":true": true,
        ":deletedText": "This message was deleted",
        ":now": new Date().toISOString(),
        ":sender": senderId
      }
    }));
    
    console.log(`Message ${messageId} marked as deleted`);
    
    // Notify all recipients' connections
    const api = new ApiGatewayManagementApiClient({
      region: process.env.AWS_REGION || "us-east-1",
      endpoint: `https://${domain}/${stage}`
    });
    
    const deleteData = JSON.stringify({
      type: "messageDeleted",
      data: {
        messageId,
        conversationId
      }
    });
    
    console.log(`Broadcasting delete to ${allRecipientIds.length} recipient(s)`);
    console.log(`Is group chat: ${isGroupChat}`);
    
    // Notify all recipients
    for (const recipId of allRecipientIds) {
      if (!recipId) continue; // Skip empty recipient IDs
      
      // Find this recipient's connections
      const recipientConnections = await docClient.send(new QueryCommand({
        TableName: CONNECTIONS_TABLE,
        IndexName: "userId-index",
        KeyConditionExpression: "userId = :u",
        ExpressionAttributeValues: { ":u": recipId }
      }));
      
      console.log(`Found ${recipientConnections.Items?.length || 0} connections for recipient ${recipId}`);
      
      const postCalls = (recipientConnections.Items || []).map(async (conn) => {
        // Don't send to the sender's connection
        if (conn.connectionId === connectionId) return;
        
        try {
          await api.send(new PostToConnectionCommand({
            ConnectionId: conn.connectionId,
            Data: Buffer.from(deleteData)
          }));
          console.log(`✅ Sent delete notification to ${recipId} connection ${conn.connectionId}`);
        } catch (sendErr) {
          if (sendErr.statusCode === 410) {
            console.log(`Stale connection ${conn.connectionId}, skipping`);
          } else {
            console.error(`Failed to send delete to ${conn.connectionId}:`, sendErr);
          }
        }
      });
      
      await Promise.all(postCalls);
    }
    
    return { statusCode: 200, body: JSON.stringify({ success: true }) };
  } catch (e) {
    console.error('Delete handler error:', e);
    return { statusCode: 500, body: JSON.stringify({ error: 'Failed to process delete' }) };
  }
};