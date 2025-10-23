/**
 * WebSocket editMessage Handler
 * Updates a message in DynamoDB and broadcasts the edit to all relevant users
 */
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, UpdateCommand, QueryCommand, GetCommand, DeleteCommand } from "@aws-sdk/lib-dynamodb";
import { ApiGatewayManagementApiClient, PostToConnectionCommand } from "@aws-sdk/client-apigatewaymanagementapi";

const client = new DynamoDBClient({ region: process.env.AWS_REGION || "us-east-1" });
const docClient = DynamoDBDocumentClient.from(client);

const MESSAGES_TABLE = process.env.MESSAGES_TABLE || "Messages_AlexHo";
const CONNECTIONS_TABLE = process.env.CONNECTIONS_TABLE || "Connections_AlexHo";

export const handler = async (event) => {
  console.log("✏️✏️✏️ WebSocket editMessage Event RECEIVED ✏️✏️✏️");
  console.log("Event:", JSON.stringify(event, null, 2));

  const domain = event.requestContext?.domainName;
  const stage = event.requestContext?.stage;
  const connectionId = event.requestContext?.connectionId;

  let body;
  try { body = JSON.parse(event.body || "{}"); } catch (e) { console.error('❌ Bad JSON body', e); body = {}; }

  const { messageId, conversationId, senderId, senderName, newContent, recipientIds, isGroupChat, editedAt } = body;
  
  console.log(`✏️ Edit request:`);
  console.log(`   Message ID: ${messageId}`);
  console.log(`   Conversation ID: ${conversationId}`);
  console.log(`   Sender: ${senderName} (${senderId})`);
  console.log(`   New content: ${newContent}`);
  console.log(`   Recipients: ${recipientIds?.length || 0}`);
  console.log(`   Is group chat: ${isGroupChat}`);

  if (!messageId || !conversationId || !senderId || !newContent || !recipientIds) {
    console.error("❌ Missing required fields");
    return { statusCode: 400, body: JSON.stringify({ error: "Missing required fields" }) };
  }

  try {
    // 1. Update the message in DynamoDB
    await docClient.send(new UpdateCommand({
      TableName: MESSAGES_TABLE,
      Key: { messageId },
      UpdateExpression: "SET #content = :content, #isEdited = :isEdited, #editedAt = :editedAt",
      ExpressionAttributeNames: {
        "#content": "content",
        "#isEdited": "isEdited",
        "#editedAt": "editedAt"
      },
      ExpressionAttributeValues: {
        ":content": newContent,
        ":isEdited": true,
        ":editedAt": editedAt || new Date().toISOString()
      }
    }));

    console.log(`✅ Message ${messageId} updated in DynamoDB`);

    // 2. Broadcast the edit to all relevant users
    const api = new ApiGatewayManagementApiClient({ 
      region: process.env.AWS_REGION || "us-east-1", 
      endpoint: `https://${domain}/${stage}` 
    });

    const editPayload = {
      type: 'messageEdited',
      data: {
        messageId,
        conversationId,
        newContent,
        editedAt: editedAt || new Date().toISOString()
      }
    };

    // Notify all recipients (for group chats, this includes all participants except sender)
    const notifyUserIds = isGroupChat ? recipientIds : recipientIds.filter(id => id !== senderId);
    
    console.log(`📨 Broadcasting edit to ${notifyUserIds.length} users`);

    for (const userId of notifyUserIds) {
      try {
        const connections = await docClient.send(new QueryCommand({
          TableName: CONNECTIONS_TABLE,
          IndexName: 'userId-index',
          KeyConditionExpression: 'userId = :u',
          ExpressionAttributeValues: { ':u': userId }
        }));

        if (connections.Items && connections.Items.length > 0) {
          for (const connection of connections.Items) {
            try {
              await api.send(new PostToConnectionCommand({
                ConnectionId: connection.connectionId,
                Data: Buffer.from(JSON.stringify(editPayload))
              }));
              console.log(`✅ Edit notification sent to ${userId} (${connection.connectionId})`);
            } catch (error) {
              if (error.statusCode === 410) {
                console.log(`🧹 Removing stale connection: ${connection.connectionId}`);
                await docClient.send(new DeleteCommand({
                  TableName: CONNECTIONS_TABLE,
                  Key: { connectionId: connection.connectionId }
                }));
              } else {
                console.error(`❌ Error sending to ${connection.connectionId}:`, error);
              }
            }
          }
        } else {
          console.log(`📴 User ${userId} is offline - will see edit on reconnect`);
        }
      } catch (error) {
        console.error(`❌ Error processing user ${userId}:`, error);
      }
    }

    console.log(`✅ Edit broadcast complete`);
    
    return { 
      statusCode: 200, 
      body: JSON.stringify({ message: "Message edited successfully" }) 
    };

  } catch (error) {
    console.error("❌ Error editing message:", error);
    console.error("Stack:", error.stack);
    return { 
      statusCode: 500, 
      body: JSON.stringify({ error: "Failed to edit message" }) 
    };
  }
};

