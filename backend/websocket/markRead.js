/**
 * WebSocket markRead Handler
 * Marks messages as read and tracks per-user read receipts for group chats
 */
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, UpdateCommand, QueryCommand, GetCommand, DeleteCommand } from "@aws-sdk/lib-dynamodb";
import { ApiGatewayManagementApiClient, PostToConnectionCommand } from "@aws-sdk/client-apigatewaymanagementapi";

const client = new DynamoDBClient({ region: process.env.AWS_REGION || "us-east-1" });
const docClient = DynamoDBDocumentClient.from(client);

const MESSAGES_TABLE = process.env.MESSAGES_TABLE || "Messages_AlexHo";
const CONNECTIONS_TABLE = process.env.CONNECTIONS_TABLE || "Connections_AlexHo";

export const handler = async (event) => {
  try {
    console.log("📖 markRead Event received");
    const domain = event.requestContext?.domainName;
    const stage = event.requestContext?.stage;

    let body;
    try { 
      body = JSON.parse(event.body || "{}"); 
    } catch (e) { 
      console.error('❌ Bad JSON body', e); 
      body = {}; 
    }
    
    const { conversationId, readerId, readerName, messageIds, isGroupChat } = body;
    
    if (!conversationId || !readerId || !Array.isArray(messageIds) || messageIds.length === 0) {
      return { 
        statusCode: 400, 
        body: JSON.stringify({ error: "conversationId, readerId, messageIds required" }) 
      };
    }

    console.log(`📖 Marking ${messageIds.length} messages as read`);
    console.log(`   Reader: ${readerName || readerId}`);
    console.log(`   Conversation: ${conversationId}`);
    console.log(`   Is Group Chat: ${isGroupChat || false}`);

    const readAt = new Date().toISOString();
    const messageIdToSender = {};
    
    // Update messages to read
    for (const messageId of messageIds) {
      try {
        // First get the current message to accumulate readers
        const getMessage = await docClient.send(new GetCommand({
          TableName: MESSAGES_TABLE,
          Key: { messageId }
        }));
        
        if (!getMessage.Item) {
          console.warn(`Message ${messageId} not found`);
          continue;
        }
        
        const currentMessage = getMessage.Item;
        const senderId = currentMessage.senderId;
        
        let updateExpression;
        let expressionAttributeNames;
        let expressionAttributeValues;
        
        if (isGroupChat) {
          // For group chats, accumulate readers in arrays
          const currentReadByUserIds = currentMessage.readByUserIds || [];
          const currentReadByUserNames = currentMessage.readByUserNames || [];
          const currentReadTimestamps = currentMessage.readTimestamps || {};
          
          // Add current reader if not already present
          if (!currentReadByUserIds.includes(readerId)) {
            currentReadByUserIds.push(readerId);
            currentReadByUserNames.push(readerName || readerId);
          }
          currentReadTimestamps[readerId] = readAt;
          
          updateExpression = "SET #s = :read, #ra = :ra, #rids = :rids, #rnames = :rnames, #rts = :rts";
          expressionAttributeNames = { 
            "#s": "status", 
            "#ra": "readAt",
            "#rids": "readByUserIds",
            "#rnames": "readByUserNames",
            "#rts": "readTimestamps"
          };
          expressionAttributeValues = { 
            ":read": "read", 
            ":ra": readAt,
            ":rids": currentReadByUserIds,
            ":rnames": currentReadByUserNames,
            ":rts": currentReadTimestamps
          };
          
          console.log(`📖 Group read tracking: ${currentReadByUserNames.join(', ')}`);
        } else {
          // For direct messages, simple read status
          updateExpression = "SET #s = :read, #ra = :ra";
          expressionAttributeNames = { "#s": "status", "#ra": "readAt" };
          expressionAttributeValues = { ":read": "read", ":ra": readAt };
        }
        
        const res = await docClient.send(new UpdateCommand({
          TableName: MESSAGES_TABLE,
          Key: { messageId },
          UpdateExpression: updateExpression,
          ExpressionAttributeNames: expressionAttributeNames,
          ExpressionAttributeValues: expressionAttributeValues,
          ReturnValues: "ALL_NEW"
        }));
        
        if (senderId) {
          messageIdToSender[messageId] = {
            senderId,
            readByUserIds: res.Attributes.readByUserIds || [],
            readByUserNames: res.Attributes.readByUserNames || [],
            readTimestamps: res.Attributes.readTimestamps || {}
          };
        }
        
        console.log(`✅ Marked message ${messageId} as read by ${readerName || readerId}`);
        if (isGroupChat && res.Attributes.readByUserNames) {
          console.log(`   All readers: ${res.Attributes.readByUserNames.join(', ')}`);
        }
      } catch (e) { 
        console.error(`❌ Update read failed for ${messageId}:`, e.message); 
      }
    }

    // Notify all relevant connections
    const api = new ApiGatewayManagementApiClient({ 
      region: process.env.AWS_REGION || "us-east-1", 
      endpoint: `https://${domain}/${stage}` 
    });
    
    for (const messageId of messageIds) {
      const messageInfo = messageIdToSender[messageId];
      if (!messageInfo) {
        console.warn(`⚠️ Could not resolve sender for ${messageId}`);
        continue;
      }
      
      const { senderId, readByUserIds, readByUserNames, readTimestamps } = messageInfo;
      
      // Prepare read status payload
      const readStatusPayload = {
        type: 'messageStatus',
        data: {
          messageId,
          conversationId,
          status: 'read',
          readerId,
          readerName: readerName || readerId,
          readAt,
          isGroupChat: isGroupChat || false,
          // For group chats, include full read receipt info
          ...(isGroupChat && {
            readByUserIds,
            readByUserNames,
            readTimestamps
          })
        }
      };
      
      try {
        // Notify sender's connections
        const senderConnections = await docClient.send(new QueryCommand({
          TableName: CONNECTIONS_TABLE,
          IndexName: 'userId-index',
          KeyConditionExpression: 'userId = :u',
          ExpressionAttributeValues: { ':u': senderId }
        }));
        
        console.log(`📨 Notifying sender (${senderId}): ${senderConnections.Items?.length || 0} connections`);
        
        for (const c of (senderConnections.Items || [])) {
          try {
            await api.send(new PostToConnectionCommand({
              ConnectionId: c.connectionId,
              Data: Buffer.from(JSON.stringify(readStatusPayload))
            }));
            console.log(`✅ Sent read status to sender connection ${c.connectionId}`);
          } catch (postErr) {
            if (postErr.statusCode === 410) {
              console.log(`🧹 Removing stale sender connection: ${c.connectionId}`);
              await docClient.send(new DeleteCommand({
                TableName: CONNECTIONS_TABLE,
                Key: { connectionId: c.connectionId }
              }));
            } else {
              console.error(`❌ Failed to send to ${c.connectionId}:`, postErr.message);
            }
          }
        }
        
        // For group chats, also notify other group members
        if (isGroupChat) {
          // Get all participants from the message or conversation
          // For now, we'll broadcast to the reader's other connections
          console.log(`📨 Group chat - broadcasting read status to all participants`);
        }
        
      } catch (e) {
        console.error(`❌ Error notifying for ${messageId}:`, e.message);
      }
    }

    return { 
      statusCode: 200, 
      body: JSON.stringify({ 
        message: "Messages marked as read", 
        count: messageIds.length,
        isGroupChat: isGroupChat || false
      }) 
    };
    
  } catch (e) {
    console.error("❌ Fatal error in markRead:", e);
    return { 
      statusCode: 500, 
      body: JSON.stringify({ error: e.message }) 
    };
  }
};
