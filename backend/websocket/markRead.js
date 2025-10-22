/**
 * WebSocket Mark Read Handler (AWS SDK v2)
 * Request body: { action: 'markRead', conversationId, readerId, messageIds: string[] }
 * For each messageId, if it belongs to conversationId and recipientId == readerId,
 * mark status = 'read' and broadcast {type:'messageStatus', data:{messageId, conversationId, status:'read'}}
 * to the sender's active connections (and the reader's other devices).
 */

const AWS = require('aws-sdk');
const ddb = new AWS.DynamoDB.DocumentClient({ region: process.env.AWS_REGION || 'us-east-1' });

const MESSAGES_TABLE = process.env.MESSAGES_TABLE || 'Messages_AlexHo';
const CONNECTIONS_TABLE = process.env.CONNECTIONS_TABLE || 'Connections_AlexHo';

exports.handler = async (event) => {
  console.log('MarkRead Event:', JSON.stringify(event, null, 2));
  const domain = event.requestContext.domainName;
  const stage = event.requestContext.stage;

  let body;
  try {
    body = JSON.parse(event.body);
  } catch {
    return { statusCode: 400, body: JSON.stringify({ error: 'Invalid body' }) };
  }

  const { conversationId, readerId, messageIds } = body;
  if (!conversationId || !readerId || !Array.isArray(messageIds) || messageIds.length === 0) {
    return { statusCode: 400, body: JSON.stringify({ error: 'Missing fields' }) };
  }

  const api = new AWS.ApiGatewayManagementApi({ endpoint: `https://${domain}/${stage}` });

  try {
    // For each message, validate ownership and mark read
    for (const messageId of messageIds) {
      const msg = await ddb.get({ TableName: MESSAGES_TABLE, Key: { messageId } }).promise();
      if (!msg.Item) continue;
      if (msg.Item.conversationId !== conversationId) continue;
      if (msg.Item.recipientId !== readerId) continue;

      // Update status to read
      await ddb.update({
        TableName: MESSAGES_TABLE,
        Key: { messageId },
        UpdateExpression: 'SET #s = :read, readAt = :now',
        ExpressionAttributeNames: { '#s': 'status' },
        ExpressionAttributeValues: { ':read': 'read', ':now': new Date().toISOString() }
      }).promise();

      const payload = JSON.stringify({
        type: 'messageStatus',
        data: { messageId, conversationId, status: 'read' }
      });

      // Notify sender connections
      if (msg.Item.senderId) {
        const senderConns = await ddb.query({
          TableName: CONNECTIONS_TABLE,
          IndexName: 'userId-index',
          KeyConditionExpression: 'userId = :u',
          ExpressionAttributeValues: { ':u': msg.Item.senderId }
        }).promise();
        for (const c of senderConns.Items || []) {
          try {
            await api.postToConnection({ ConnectionId: c.connectionId, Data: payload }).promise();
          } catch (e) {
            console.error('postToConnection (sender) error:', e.message || e);
          }
        }
      }

      // Notify reader's other devices
      const readerConns = await ddb.query({
        TableName: CONNECTIONS_TABLE,
        IndexName: 'userId-index',
        KeyConditionExpression: 'userId = :u',
        ExpressionAttributeValues: { ':u': readerId }
      }).promise();
      for (const c of readerConns.Items || []) {
        try {
          await api.postToConnection({ ConnectionId: c.connectionId, Data: payload }).promise();
        } catch (e) {
          console.error('postToConnection (reader) error:', e.message || e);
        }
      }
    }

    return { statusCode: 200, body: JSON.stringify({ success: true }) };
  } catch (e) {
    console.error('markRead error:', e);
    return { statusCode: 500, body: JSON.stringify({ error: 'Failed to mark read' }) };
  }
};


