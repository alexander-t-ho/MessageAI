/**
 * WebSocket Connect Handler
 * Triggered when a user connects to the WebSocket API
 * Saves connection ID and user ID to DynamoDB
 */

import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, PutCommand } from '@aws-sdk/lib-dynamodb';

const client = new DynamoDBClient({ region: process.env.AWS_REGION || 'us-east-1' });
const docClient = DynamoDBDocumentClient.from(client);

const CONNECTIONS_TABLE = process.env.CONNECTIONS_TABLE || 'Connections_AlexHo';

export const handler = async (event) => {
    console.log('WebSocket Connect Event:', JSON.stringify(event, null, 2));
    
    const connectionId = event.requestContext.connectionId;
    const userId = event.queryStringParameters?.userId;
    
    // Validate userId
    if (!userId) {
        console.error('Missing userId in query parameters');
        return {
            statusCode: 400,
            body: JSON.stringify({ error: 'userId is required' })
        };
    }
    
    try {
        // Save connection to DynamoDB
        const timestamp = Date.now();
        const ttl = Math.floor(timestamp / 1000) + (24 * 60 * 60); // 24 hours from now
        
        await docClient.send(new PutCommand({
            TableName: CONNECTIONS_TABLE,
            Item: {
                connectionId: connectionId,
                userId: userId,
                connectedAt: timestamp,
                ttl: ttl
            }
        }));
        
        console.log(`✅ Connection saved: ${connectionId} for user: ${userId}`);
        
        return {
            statusCode: 200,
            body: JSON.stringify({ 
                message: 'Connected',
                connectionId: connectionId 
            })
        };
        
    } catch (error) {
        console.error('❌ Error saving connection:', error);
        return {
            statusCode: 500,
            body: JSON.stringify({ error: 'Failed to connect' })
        };
    }
};

