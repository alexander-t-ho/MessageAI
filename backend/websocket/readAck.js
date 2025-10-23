/**
 * WebSocket readAck Handler
 * Receives { conversationId, readerId, messageIds, readAt } and notifies senders with messageStatus=read.
 */
import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, GetCommand, QueryCommand } from "@aws-sdk/lib-dynamodb";
import { ApiGatewayManagementApiClient, PostToConnectionCommand } from "@aws-sdk/client-apigatewaymanagementapi";

const client = new DynamoDBClient({ region: process.env.AWS_REGION || "us-east-1" });
const docClient = DynamoDBDocumentClient.from(client);

const MESSAGES_TABLE = process.env.MESSAGES_TABLE || "Messages_AlexHo";
const CONNECTIONS_TABLE = process.env.CONNECTIONS_TABLE || "Connections_AlexHo";

export const handler = async (event) => {
  try {
    console.log("readAck Event:", JSON.stringify(event, null, 2));
    const domain = event.requestContext?.domainName;
    const stage = event.requestContext?.stage;
    const api = new ApiGatewayManagementApiClient({
      region: process.env.AWS_REGION || "us-east-1",
      endpoint: `https://${domain}/${stage}`
    });

    let body; try { body = JSON.parse(event.body || "{}"); } catch { body = {}; }
    const { conversationId, readerId, messageIds, readAt } = body;
    if (!conversationId || !readerId || !Array.isArray(messageIds) || messageIds.length === 0) {
      return { statusCode: 200, body: JSON.stringify({ ok: false, error: "bad_request" }) };
    }

    const timestamp = readAt || new Date().toISOString();

    for (const messageId of messageIds) {
      // Resolve original senderId for this message
      let senderId;
      try {
        const got = await docClient.send(new GetCommand({ TableName: MESSAGES_TABLE, Key: { messageId } }));
        senderId = got.Item && got.Item.senderId;
      } catch (e) { console.error("readAck GetItem failed", messageId, e); }
      if (!senderId) continue;

      try {
        const conns = await docClient.send(new QueryCommand({
          TableName: CONNECTIONS_TABLE,
          IndexName: "userId-index",
          KeyConditionExpression: "userId = :u",
          ExpressionAttributeValues: { ":u": senderId }
        }));
        for (const c of (conns.Items || [])) {
          await api.send(new PostToConnectionCommand({
            ConnectionId: c.connectionId,
            Data: Buffer.from(JSON.stringify({
              type: "messageStatus",
              data: { messageId, conversationId, status: "read", readerId, readAt: timestamp }
            }))
          }));
        }
      } catch (e) {
        console.error("readAck notify error", e);
      }
    }

    return { statusCode: 200, body: JSON.stringify({ ok: true }) };
  } catch (e) {
    console.error("readAck fatal", e);
    return { statusCode: 200, body: JSON.stringify({ ok: false }) };
  }
};


