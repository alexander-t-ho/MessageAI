/**
 * WebSocket markRead Handler
 * Marks a batch of messages as read for a conversation and notifies sender.
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
    console.log("markRead Event:", JSON.stringify(event, null, 2));
    const domain = event.requestContext?.domainName;
    const stage = event.requestContext?.stage;

    let body;
    try { body = JSON.parse(event.body || "{}"); } catch (e) { console.error('Bad JSON body', e); body = {}; }
    const { conversationId, readerId, messageIds } = body;
    if (!conversationId || !readerId || !Array.isArray(messageIds) || messageIds.length === 0) {
      return { statusCode: 400, body: JSON.stringify({ error: "conversationId, readerId, messageIds required" }) };
    }

    const readAt = new Date().toISOString();
  // Update messages to read and store readAt; capture senderId for notify
    const messageIdToSender = {};
    for (const messageId of messageIds) {
      try {
        const res = await docClient.send(new UpdateCommand({
          TableName: MESSAGES_TABLE,
          Key: { messageId },
          UpdateExpression: "SET #s = :read, #ra = :ra",
          ExpressionAttributeNames: { "#s": "status", "#ra": "readAt" },
          ExpressionAttributeValues: { ":read": "read", ":ra": readAt },
          ReturnValues: "ALL_NEW"
        }));
        const senderId = res.Attributes && res.Attributes.senderId;
        if (senderId) messageIdToSender[messageId] = senderId;
      } catch (e) { console.error("Update read failed", messageId, e); }
    }

  // Notify sender connections for each message
    const api = new ApiGatewayManagementApiClient({ region: process.env.AWS_REGION || "us-east-1", endpoint: `https://${domain}/${stage}` });
    for (const messageId of messageIds) {
    let senderId = messageIdToSender[messageId];
    if (!senderId) {
      // Fallback: fetch the message to resolve senderId without mutating it
      try {
        const got = await docClient.send(new GetCommand({
          TableName: MESSAGES_TABLE,
          Key: { messageId }
        }));
        senderId = got.Item && got.Item.senderId;
      } catch (e) {
        console.error('markRead: GetItem failed for', messageId, e);
      }
    }
    if (!senderId) {
      console.warn('markRead: could not resolve senderId for', messageId);
      continue;
    }
    try {
      const senderConnections = await docClient.send(new QueryCommand({
        TableName: CONNECTIONS_TABLE,
        IndexName: 'userId-index',
        KeyConditionExpression: 'userId = :u',
        ExpressionAttributeValues: { ':u': senderId }
      }));
      console.log(`Found ${senderConnections.Items?.length || 0} connections for sender ${senderId}`);
      for (const c of (senderConnections.Items || [])) {
        try {
          await api.send(new PostToConnectionCommand({
            ConnectionId: c.connectionId,
            Data: Buffer.from(JSON.stringify({ type: 'messageStatus', data: { messageId, conversationId, status: 'read', readerId, readAt } }))
          }));
          console.log(`✅ Sent read status to connection ${c.connectionId}`);
        } catch (sendErr) {
          if (sendErr.statusCode === 410) {
            // Connection is gone - clean it up
            console.log(`Removing stale connection ${c.connectionId}`);
            try {
              await docClient.send(new DeleteCommand({
                TableName: CONNECTIONS_TABLE,
                Key: { connectionId: c.connectionId }
              }));
            } catch (delErr) {
              console.error(`Failed to delete stale connection ${c.connectionId}:`, delErr);
            }
          } else {
            console.error(`Failed to send to ${c.connectionId}:`, sendErr);
          }
        }
      }
    } catch (e) {
      console.error('Notify sender error', e);
    }
  }

    // Always return 200 even if some messageIds could not be resolved
    return { statusCode: 200, body: JSON.stringify({ ok: true, updated: Object.keys(messageIdToSender).length }) };
  } catch (e) {
    console.error('markRead fatal error', e);
    return { statusCode: 200, body: JSON.stringify({ ok: false, error: 'handled', detail: String(e) }) };
  }
};
