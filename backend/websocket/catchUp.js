/**
 * WebSocket Catch-up Handler
 * Resolve userId from connectionId, then push recent messages to that connection.
 */
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, QueryCommand, GetCommand } from "@aws-sdk/lib-dynamodb";
import { ApiGatewayManagementApiClient, PostToConnectionCommand } from "@aws-sdk/client-apigatewaymanagementapi";

const client = new DynamoDBClient({ region: process.env.AWS_REGION || "us-east-1" });
const docClient = DynamoDBDocumentClient.from(client);

const MESSAGES_TABLE = process.env.MESSAGES_TABLE || "Messages_AlexHo";
const CONNECTIONS_TABLE = process.env.CONNECTIONS_TABLE || "Connections_AlexHo";

export const handler = async (event) => {
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

  try {
    const resp = await docClient.send(new QueryCommand({
      TableName: MESSAGES_TABLE,
      IndexName: "recipientId-index",
      KeyConditionExpression: "recipientId = :r",
      ExpressionAttributeValues: { ":r": userId },
      ScanIndexForward: false,
      Limit: limit,
    }));

    const api = new ApiGatewayManagementApiClient({
      region: process.env.AWS_REGION || "us-east-1",
      endpoint: `https://${domain}/${stage}`,
    });

    for (const m of (resp.Items || [])) {
      if (m.isDeleted) continue;
      await api.send(new PostToConnectionCommand({
        ConnectionId: connectionId,
        Data: Buffer.from(JSON.stringify({
          type: "message",
          data: {
            messageId: m.messageId,
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
          },
        })),
      }));

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
            Data: Buffer.from(JSON.stringify({ type: 'messageStatus', data: { messageId: m.messageId, conversationId: m.conversationId, status: 'delivered' } }))
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
