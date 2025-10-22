/**
 * WebSocket Presence Update Handler (AWS SDK v2)
 * Fan-out { userId, isOnline } to all connections in Connections_AlexHo.
 * Uses built-in aws-sdk v2 in Lambda runtime to avoid bundling deps.
 */

const AWS = require('aws-sdk');
const ddb = new AWS.DynamoDB.DocumentClient({ region: process.env.AWS_REGION || 'us-east-1' });

const CONNECTIONS_TABLE = process.env.CONNECTIONS_TABLE || 'Connections_AlexHo';

exports.handler = async (event) => {
  console.log('Presence Update Event:', JSON.stringify(event, null, 2));
  const domain = event.requestContext.domainName;
  const stage = event.requestContext.stage;
  let body;
  try {
    body = JSON.parse(event.body);
  } catch {
    return { statusCode: 400, body: JSON.stringify({ error: 'Invalid body' }) };
  }
  const { userId, isOnline } = body;
  if (!userId || typeof isOnline !== 'boolean') {
    return { statusCode: 400, body: JSON.stringify({ error: 'Missing fields' }) };
  }

  try {
    const all = await ddb.scan({ TableName: CONNECTIONS_TABLE }).promise();
    const api = new AWS.ApiGatewayManagementApi({ endpoint: `https://${domain}/${stage}` });
    const data = JSON.stringify({ type: 'presence', data: { userId, isOnline } });
    const sends = (all.Items || []).map(async (c) => {
      try {
        await api.postToConnection({ ConnectionId: c.connectionId, Data: data }).promise();
      } catch (e) {
        console.error('Presence send error:', e && e.message ? e.message : e);
      }
    });
    await Promise.all(sends);
    return { statusCode: 200, body: JSON.stringify({ success: true }) };
  } catch (e) {
    console.error('Presence handler error:', e);
    return { statusCode: 500, body: JSON.stringify({ error: 'Failed to broadcast presence' }) };
  }
};


