/**
 * WebSocket Presence Update Handler
 * Fan-out { userId, isOnline } to all connections in Connections_AlexHo.
 */

import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, ScanCommand, DeleteCommand } from "@aws-sdk/lib-dynamodb";
import { ApiGatewayManagementApiClient, PostToConnectionCommand } from "@aws-sdk/client-apigatewaymanagementapi";

const client = new DynamoDBClient({ region: process.env.AWS_REGION || "us-east-1" });
const docClient = DynamoDBDocumentClient.from(client);

const CONNECTIONS_TABLE = process.env.CONNECTIONS_TABLE || 'Connections_AlexHo';

export const handler = async (event) => {
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
    // Get all connections
    const all = await docClient.send(new ScanCommand({ TableName: CONNECTIONS_TABLE }));
    
    // Create API Gateway Management client
    const api = new ApiGatewayManagementApiClient({ 
      region: process.env.AWS_REGION || 'us-east-1',
      endpoint: `https://${domain}/${stage}` 
    });
    
    // Prepare presence data
    const presenceData = JSON.stringify({ 
      type: 'presence', 
      data: { userId, isOnline } 
    });
    
    // Send to all connections
    const sends = (all.Items || []).map(async (c) => {
      try {
        await api.send(new PostToConnectionCommand({ 
          ConnectionId: c.connectionId, 
          Data: Buffer.from(presenceData) 
        }));
        console.log(`✅ Sent presence to connection ${c.connectionId}`);
      } catch (e) {
        if (e.statusCode === 410) {
          console.log(`Stale connection ${c.connectionId}, cleaning up`);
          // Clean up stale connection
          try {
            await docClient.send(new DeleteCommand({
              TableName: CONNECTIONS_TABLE,
              Key: { connectionId: c.connectionId }
            }));
            console.log(`Cleaned up stale connection ${c.connectionId}`);
          } catch (deleteError) {
            console.error(`Failed to delete stale connection ${c.connectionId}:`, deleteError);
          }
        } else {
          console.error('Presence send error:', e);
        }
      }
    });
    
    await Promise.all(sends);
    return { statusCode: 200, body: JSON.stringify({ success: true }) };
  } catch (e) {
    console.error('Presence handler error:', e);
    return { statusCode: 500, body: JSON.stringify({ error: 'Failed to broadcast presence' }) };
  }
};


