/**
 * WebSocket Edit Message Handler
 * Updates message content in DynamoDB and broadcasts edit to all participants
 */

const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, UpdateCommand, QueryCommand, DeleteCommand } = require("@aws-sdk/lib-dynamodb");
const { ApiGatewayManagementApiClient, PostToConnectionCommand } = require("@aws-sdk/client-apigatewaymanagementapi");

const client = new DynamoDBClient({ region: process.env.AWS_REGION || "us-east-1" });
const docClient = DynamoDBDocumentClient.from(client);

const MESSAGES_TABLE = process.env.MESSAGES_TABLE || "Messages_AlexHo";
const CONNECTIONS_TABLE = process.env.CONNECTIONS_TABLE || "Connections_AlexHo";

exports.handler = async (event) => {
  console.log("🎯 WebSocket editMessage Event RECEIVED");
  console.log("Event:", JSON.stringify(event, null, 2));

  const domain = event.requestContext?.domainName;
  const stage = event.requestContext?.stage;
  const connectionId = event.requestContext?.connectionId;

  let body;
  try { body = JSON.parse(event.body || "{}"); } catch (e) { console.error('❌ Bad JSON body', e); body = {}; }

  const { messageId, conversationId, senderId, senderName, newContent, recipientIds, isGroupChat, editedAt } = body;
  console.log(`Editor: ${senderName} (${senderId}), Message: ${messageId}, New Content: ${newContent}, IsGroupChat: ${isGroupChat}`);

  if (!messageId || !conversationId || !senderId || !newContent || !editedAt) {
    console.error("❌ Missing required fields: messageId, conversationId, senderId, newContent, editedAt");
    return { statusCode: 400, body: JSON.stringify({ error: "Missing required fields" }) };
  }

  try {
    // Update message in DynamoDB
    if (isGroupChat && recipientIds && Array.isArray(recipientIds)) {
      // For group chats: Update all per-recipient records
      console.log(`Editing group chat message for ${recipientIds.length} recipients`);
      const editPromises = recipientIds.map(async (recipId) => {
        if (recipId === senderId) return; // Skip sender's own record
        const perRecipientMessageId = `${messageId}_${recipId}`;
        try {
          await docClient.send(new UpdateCommand({
            TableName: MESSAGES_TABLE,
            Key: { messageId: perRecipientMessageId },
            UpdateExpression: "SET #c = :newContent, #ie = :isEdited, #ea = :editedAt",
            ExpressionAttributeNames: {
              "#c": "content",
              "#ie": "isEdited",
              "#ea": "editedAt"
            },
            ExpressionAttributeValues: {
              ":newContent": newContent,
              ":isEdited": true,
              ":editedAt": editedAt
            }
          }));
          console.log(`  - Updated ${perRecipientMessageId}`);
        } catch (e) {
          console.error(`  - Error editing ${perRecipientMessageId}:`, e);
        }
      });
      await Promise.all(editPromises);
    } else {
      // For direct messages: Update single record
      await docClient.send(new UpdateCommand({
        TableName: MESSAGES_TABLE,
        Key: { messageId },
        UpdateExpression: "SET #c = :newContent, #ie = :isEdited, #ea = :editedAt",
        ExpressionAttributeNames: {
          "#c": "content",
          "#ie": "isEdited",
          "#ea": "editedAt"
        },
        ExpressionAttributeValues: {
          ":newContent": newContent,
          ":isEdited": true,
          ":editedAt": editedAt
        },
        ReturnValues: "UPDATED_NEW"
      }));
    }
    console.log(`✅ Message ${messageId} updated in DynamoDB.`);

    // Notify all relevant connections
    const api = new ApiGatewayManagementApiClient({ region: process.env.AWS_REGION || "us-east-1", endpoint: `https://${domain}/${stage}` });

    const connectionsToNotify = new Set();

    // Add sender's connections (for multi-device sync)
    const senderConnections = await docClient.send(new QueryCommand({
      TableName: CONNECTIONS_TABLE,
      IndexName: 'userId-index',
      KeyConditionExpression: 'userId = :u',
      ExpressionAttributeValues: { ':u': senderId }
    }));
    (senderConnections.Items || []).forEach(c => connectionsToNotify.add(c.connectionId));

    // Add recipient(s) connections
    if (isGroupChat && recipientIds && Array.isArray(recipientIds)) {
      for (const recipient of recipientIds) {
        if (recipient === senderId) continue; // Skip sender
        const recipientConnections = await docClient.send(new QueryCommand({
          TableName: CONNECTIONS_TABLE,
          IndexName: 'userId-index',
          KeyConditionExpression: 'userId = :u',
          ExpressionAttributeValues: { ':u': recipient }
        }));
        (recipientConnections.Items || []).forEach(c => connectionsToNotify.add(c.connectionId));
      }
    } else {
      // Direct message - recipientIds should be an array with one recipient
      if (recipientIds && recipientIds.length > 0) {
        for (const recipientId of recipientIds) {
          if (recipientId === senderId) continue; // Skip sender
          const recipientConnections = await docClient.send(new QueryCommand({
            TableName: CONNECTIONS_TABLE,
            IndexName: 'userId-index',
            KeyConditionExpression: 'userId = :u',
            ExpressionAttributeValues: { ':u': recipientId }
          }));
          (recipientConnections.Items || []).forEach(c => connectionsToNotify.add(c.connectionId));
        }
      }
    }

    const notificationPayload = {
      type: 'messageEdited',
      data: {
        messageId,
        conversationId,
        newContent,
        editedAt
      }
    };

    const postToConnectionPromises = Array.from(connectionsToNotify).map(async (connId) => {
      try {
        await api.send(new PostToConnectionCommand({
          ConnectionId: connId,
          Data: Buffer.from(JSON.stringify(notificationPayload))
        }));
        console.log(`✅ Sent edit notification for message ${messageId} to connection ${connId}`);
      } catch (error) {
        if (error.statusCode === 410) {
          console.log(`🧹 Removing stale connection: ${connId}`);
          await docClient.send(new DeleteCommand({
            TableName: CONNECTIONS_TABLE,
            Key: { connectionId: connId }
          }));
        } else {
          console.error(`❌ Error sending edit notification to ${connId}:`, error);
        }
      }
    });
    await Promise.all(postToConnectionPromises);

  } catch (e) {
    console.error(`❌ Error processing editMessage:`, e);
    return { statusCode: 500, body: JSON.stringify({ error: "Failed to process message edit" }) };
  }

  return { statusCode: 200, body: JSON.stringify({ message: "Message edited successfully" }) };
};
