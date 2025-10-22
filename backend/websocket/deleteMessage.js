/**
 * WebSocket Delete Message Handler
 * Marks a message as deleted and notifies recipient to hide it locally
 */

import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, UpdateCommand, QueryCommand, DeleteCommand } from '@aws-sdk/lib-dynamodb';
import { ApiGatewayManagementApiClient, PostToConnectionCommand } from '@aws-sdk/client-apigatewaymanagementapi';

const client = new DynamoDBClient({ region: process.env.AWS_REGION || 'us-east-1' });
const docClient = DynamoDBDocumentClient.from(client);

const MESSAGES_TABLE = process.env.MESSAGES_TABLE || 'Messages_AlexHo';
const CONNECTIONS_TABLE = process.env.CONNECTIONS_TABLE || 'Connections_AlexHo';

export const handler = async (event) => {
  console.log('WebSocket DeleteMessage Event:', JSON.stringify(event, null, 2));
  const domain = event.requestContext.domainName;
  const stage = event.requestContext.stage;
  
  let body;
  try {
    body = JSON.parse(event.body);
  } catch {
    return { statusCode: 400, body: JSON.stringify({ error: 'Invalid format' }) };
  }
  const { messageId, conversationId, senderId, recipientId } = body;
  if (!messageId || !conversationId || !senderId || !recipientId) {
    return { statusCode: 400, body: JSON.stringify({ error: 'Missing fields' }) };
  }
  try {
    // Mark as deleted (soft delete)
    await docClient.send(new UpdateCommand({
      TableName: MESSAGES_TABLE,
      Key: { messageId },
      UpdateExpression: 'SET isDeleted = :true',
      ExpressionAttributeValues: { ':true': true }
    }));
    
    // Notify recipient
    const recipientConnections = await docClient.send(new QueryCommand({
      TableName: CONNECTIONS_TABLE,
      IndexName: 'userId-index',
      KeyConditionExpression: 'userId = :u',
      ExpressionAttributeValues: { ':u': recipientId }
    }));
    const apiGateway = new ApiGatewayManagementApiClient({
      region: process.env.AWS_REGION || 'us-east-1',
      endpoint: `https://${domain}/${stage}`
    });
    const notify = recipientConnections.Items?.map(async (c) => {
      try {
        await apiGateway.send(new PostToConnectionCommand({
          ConnectionId: c.connectionId,
          Data: Buffer.from(JSON.stringify({
            type: 'messageDeleted',
            data: { messageId, conversationId }
          }))
        }));
      } catch (error) {
        if (error.statusCode === 410) {
          await docClient.send(new DeleteCommand({ TableName: CONNECTIONS_TABLE, Key: { connectionId: c.connectionId } }));
        } else {
          console.error('Notify error:', error);
        }
      }
    }) || [];
    await Promise.all(notify);
    
    return { statusCode: 200, body: JSON.stringify({ success: true }) };
  } catch (e) {
    console.error('Delete error:', e);
    return { statusCode: 500, body: JSON.stringify({ error: 'Failed to delete' }) };
  }
};


