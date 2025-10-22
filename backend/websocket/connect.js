/**
 * WebSocket Connect Handler
 * Triggered when a user connects to the WebSocket API
 * Saves connection ID and user ID to DynamoDB
 */

import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, PutCommand, QueryCommand } from '@aws-sdk/lib-dynamodb';
import { ApiGatewayManagementApiClient, PostToConnectionCommand } from '@aws-sdk/client-apigatewaymanagementapi';

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

        // Catch-up delivery: query undelivered (saved) messages for this user (last N)
        try {
            const api = new ApiGatewayManagementApiClient({
                region: process.env.AWS_REGION || 'us-east-1',
                endpoint: `https://${event.requestContext.domainName}/${event.requestContext.stage}`
            });
            const messagesTable = process.env.MESSAGES_TABLE || 'Messages_AlexHo';
            const resp = await docClient.send(new QueryCommand({
                TableName: messagesTable,
                IndexName: 'recipientId-index',
                KeyConditionExpression: 'recipientId = :r',
                ExpressionAttributeValues: { ':r': userId },
                // newest first so most recent messages are delivered immediately
                ScanIndexForward: false,
                Limit: 100
            }));
            for (const m of (resp.Items || [])) {
                // Skip deleted
                if (m.isDeleted) continue;
                await api.send(new PostToConnectionCommand({
                    ConnectionId: connectionId,
                    Data: Buffer.from(JSON.stringify({
                        type: 'message',
                        data: {
                            messageId: m.messageId,
                            conversationId: m.conversationId,
                            senderId: m.senderId,
                            senderName: m.senderName,
                            content: m.content,
                            timestamp: m.timestamp,
                            status: 'delivered',
                            replyToMessageId: m.replyToMessageId || null,
                            replyToContent: m.replyToContent || null,
                            replyToSenderName: m.replyToSenderName || null
                        }
                    }))
                }));
            }
        } catch (e) {
            console.error('Catch-up delivery error:', e);
        }

        return {
            statusCode: 200,
            body: JSON.stringify({ 
                message: 'Connected',
                connectionId: connectionId,
                userId
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

