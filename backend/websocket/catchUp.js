/**
 * WebSocket Catch-up Handler
 * Resolve userId from connectionId, then push recent messages to that connection.
 */
const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, QueryCommand, GetCommand, UpdateCommand } = require('@aws-sdk/lib-dynamodb');
const { ApiGatewayManagementApiClient, PostToConnectionCommand } = require('@aws-sdk/client-apigatewaymanagementapi');

const client = new DynamoDBClient({ region: process.env.AWS_REGION || "us-east-1" });
const docClient = DynamoDBDocumentClient.from(client);

const MESSAGES_TABLE = process.env.MESSAGES_TABLE || "Messages_AlexHo";
const CONNECTIONS_TABLE = process.env.CONNECTIONS_TABLE || "Connections_AlexHo";

exports.handler = async (event) => {
  console.log("CatchUp Event:", JSON.stringify(event, null, 2));
  const connectionId = event.requestContext.connectionId;
  const domain = event.requestContext.domainName;
  const stage = event.requestContext.stage;

  // Resolve userId for this connection from Connections table
  let userId;
  try {
    const conn = await docClient.send(new GetCommand({
      TableName: CONNECTIONS_TABLE,
      Key: { connectionId },
    }));
    userId = conn.Item && conn.Item.userId;
  } catch (e) {
    console.error("Failed to read connection mapping:", e);
  }

  if (!userId) {
    // Fallback to body userId if provided
    try { const b = JSON.parse(event.body || "{}"); userId = b.userId; } catch {}
  }

  if (!userId) {
    return { statusCode: 400, body: JSON.stringify({ error: "userId not found for connection" }) };
  }

  const limit = 100;
  
  // Only get messages from the last 48 hours to avoid flooding with old messages
  const twoDaysAgo = new Date();
  twoDaysAgo.setDate(twoDaysAgo.getDate() - 2);
  const twoDaysAgoISO = twoDaysAgo.toISOString();

  try {
    const resp = await docClient.send(new QueryCommand({
      TableName: MESSAGES_TABLE,
      IndexName: "recipientId-index",
      KeyConditionExpression: "recipientId = :r AND #ts > :cutoff",
      FilterExpression: "attribute_not_exists(isDelivered)",
      ExpressionAttributeNames: {
        "#ts": "timestamp"
      },
      ExpressionAttributeValues: { 
        ":r": userId,
        ":cutoff": twoDaysAgoISO
      },
      ScanIndexForward: false,
      Limit: limit,
    }));

    const api = new ApiGatewayManagementApiClient({
      region: process.env.AWS_REGION || "us-east-1",
      endpoint: `https://${domain}/${stage}`,
    });

    console.log(`CatchUp: Found ${resp.Items?.length || 0} undelivered messages for ${userId} from last 48 hours`);

    for (const m of (resp.Items || [])) {
      if (m.isDeleted) continue;
      
      // Use originalMessageId for group chats, regular messageId for direct
      const actualMessageId = m.originalMessageId || m.messageId;
      
      console.log(`  - Message ${actualMessageId} from ${m.senderName} in conversation ${m.conversationId}${m.isGroupChat ? ' (GROUP)' : ''}`);
      
      // Log voice message details if present
      if (m.messageType === 'voice') {
        console.log(`🎤 Voice message being delivered via catchUp:`);
        console.log(`   Audio URL: ${m.audioUrl || 'nil'}`);
        console.log(`   Duration: ${m.audioDuration || 0}s`);
        console.log(`   Transcript: ${m.transcript || 'none'}`);
      }
      
      const messagePayload = {
        type: "message",
        data: {
          messageId: actualMessageId,
          conversationId: m.conversationId,
          senderId: m.senderId,
          senderName: m.senderName,
          content: m.content,
          timestamp: m.timestamp,
          status: "delivered",
          replyToMessageId: m.replyToMessageId || null,
          replyToContent: m.replyToContent || null,
          replyToSenderName: m.replyToSenderName || null,
          isEdited: m.isEdited || false,
          editedAt: m.editedAt || null,
          // Voice message fields
          messageType: m.messageType || null,
          audioUrl: m.audioUrl || null,
          audioDuration: m.audioDuration || null,
          transcript: m.transcript || null,
          isTranscribing: m.isTranscribing || false,
        },
      };
      
      console.log(`📤 Sending catchUp message payload:`, JSON.stringify(messagePayload, null, 2));
      
      await api.send(new PostToConnectionCommand({
        ConnectionId: connectionId,
        Data: Buffer.from(JSON.stringify(messagePayload)),
      }));

      // Mark the message as delivered in the database
      // Use the actual stored messageId (which may be messageId_recipientId for group chats)
      try {
        await docClient.send(new UpdateCommand({
          TableName: MESSAGES_TABLE,
          Key: { messageId: m.messageId }, // This is the stored ID (with _recipientId for groups)
          UpdateExpression: "SET isDelivered = :true",
          ExpressionAttributeValues: {
            ":true": true
          }
        }));
      } catch (e) {
        console.error('catchUp: failed to mark message as delivered', e);
      }

      // Also notify the sender that delivery has occurred now that recipient reconnected
      try {
        const senderConnections = await docClient.send(new QueryCommand({
          TableName: CONNECTIONS_TABLE,
          IndexName: 'userId-index',
          KeyConditionExpression: 'userId = :u',
          ExpressionAttributeValues: { ':u': m.senderId }
        }));
        for (const c of (senderConnections.Items || [])) {
          await api.send(new PostToConnectionCommand({
            ConnectionId: c.connectionId,
            Data: Buffer.from(JSON.stringify({ 
              type: 'messageStatus', 
              data: { 
                messageId: actualMessageId, // Send original message ID to client
                conversationId: m.conversationId, 
                status: 'delivered' 
              } 
            }))
          }));
        }
      } catch (e) {
        console.error('catchUp: notify sender delivery error', e);
      }
    }

    // Send summary (recipient should auto mark read if at bottom)
    await api.send(new PostToConnectionCommand({
      ConnectionId: connectionId,
      Data: Buffer.from(JSON.stringify({ type: "catchUpComplete", data: { count: (resp.Items && resp.Items.length) || 0 } }))
    }));

    const count = (resp.Items && resp.Items.length) || 0;
    return { statusCode: 200, body: JSON.stringify({ success: true, count }) };
  } catch (e) {
    console.error("CatchUp error:", e);
    return { statusCode: 500, body: JSON.stringify({ error: "catchUp failed" }) };
  }
};
