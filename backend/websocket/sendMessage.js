/**
 * WebSocket Send Message Handler
 * Triggered when a user sends a message
 * 1. Saves message to DynamoDB
 * 2. Finds recipient's connection
 * 3. Sends message to recipient via WebSocket
 */

import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, PutCommand, QueryCommand, DeleteCommand } from '@aws-sdk/lib-dynamodb';
import { ApiGatewayManagementApiClient, PostToConnectionCommand } from '@aws-sdk/client-apigatewaymanagementapi';

const client = new DynamoDBClient({ region: process.env.AWS_REGION || 'us-east-1' });
const docClient = DynamoDBDocumentClient.from(client);

const MESSAGES_TABLE = process.env.MESSAGES_TABLE || 'Messages_AlexHo';
const CONNECTIONS_TABLE = process.env.CONNECTIONS_TABLE || 'Connections_AlexHo';

export const handler = async (event) => {
    console.log('WebSocket SendMessage Event:', JSON.stringify(event, null, 2));
    
    const connectionId = event.requestContext.connectionId;
    const domain = event.requestContext.domainName;
    const stage = event.requestContext.stage;
    
    let messageData;
    try {
        messageData = JSON.parse(event.body);
    } catch (error) {
        console.error('❌ Invalid JSON in message body');
        return {
            statusCode: 400,
            body: JSON.stringify({ error: 'Invalid message format' })
        };
    }
    
    const {
        messageId,
        conversationId,
        senderId,
        senderName,
        recipientId,
        content,
        timestamp,
        replyToMessageId,
        replyToContent,
        replyToSenderName
    } = messageData;
    
    // Validate required fields
    if (!messageId || !conversationId || !senderId || !recipientId || !content) {
        console.error('❌ Missing required fields');
        return {
            statusCode: 400,
            body: JSON.stringify({ error: 'Missing required fields' })
        };
    }
    
    try {
        // 1. Save message to DynamoDB
        await docClient.send(new PutCommand({
            TableName: MESSAGES_TABLE,
            Item: {
                messageId: messageId,
                conversationId: conversationId,
                senderId: senderId,
                senderName: senderName,
                recipientId: recipientId,
                content: content,
                timestamp: timestamp || new Date().toISOString(),
                status: 'sent',
                isDeleted: false,
                replyToMessageId: replyToMessageId || null,
                replyToContent: replyToContent || null,
                replyToSenderName: replyToSenderName || null
            }
        }));
        
        console.log(`✅ Message saved to DynamoDB: ${messageId}`);
        
        // 2. Find recipient's connection(s)
        const recipientConnections = await docClient.send(new QueryCommand({
            TableName: CONNECTIONS_TABLE,
            IndexName: 'userId-index',
            KeyConditionExpression: 'userId = :userId',
            ExpressionAttributeValues: {
                ':userId': recipientId
            }
        }));
        
        console.log(`📡 Found ${recipientConnections.Items?.length || 0} connections for recipient ${recipientId}`);
        
        // 3. Send message to recipient's connection(s)
        if (recipientConnections.Items && recipientConnections.Items.length > 0) {
            const apiGateway = new ApiGatewayManagementApiClient({
                region: process.env.AWS_REGION || 'us-east-1',
                endpoint: `https://${domain}/${stage}`
            });
            
            const sendPromises = recipientConnections.Items.map(async (connection) => {
                try {
                    await apiGateway.send(new PostToConnectionCommand({
                        ConnectionId: connection.connectionId,
                        Data: Buffer.from(JSON.stringify({
                            type: 'message',
                            data: {
                                messageId,
                                conversationId,
                                senderId,
                                senderName,
                                content,
                                timestamp: timestamp || new Date().toISOString(),
                                status: 'delivered',
                                replyToMessageId,
                                replyToContent,
                                replyToSenderName
                            }
                        }))
                    }));
                    
                    console.log(`✅ Message sent to connection: ${connection.connectionId}`);
                } catch (error) {
                    if (error.statusCode === 410) {
                        // Connection is stale, remove it
                        console.log(`🧹 Removing stale connection: ${connection.connectionId}`);
                        await docClient.send(new DeleteCommand({
                            TableName: CONNECTIONS_TABLE,
                            Key: { connectionId: connection.connectionId }
                        }));
                    } else {
                        console.error(`❌ Error sending to ${connection.connectionId}:`, error);
                    }
                }
            });
            
            await Promise.all(sendPromises);
            
            return {
                statusCode: 200,
                body: JSON.stringify({
                    message: 'Message sent',
                    messageId: messageId,
                    status: 'delivered'
                })
            };
        } else {
            // Recipient is offline - message saved to DB, will be delivered when they connect
            console.log(`📴 Recipient ${recipientId} is offline - message saved for later delivery`);
            
            return {
                statusCode: 200,
                body: JSON.stringify({
                    message: 'Message saved',
                    messageId: messageId,
                    status: 'sent'
                })
            };
        }
        
    } catch (error) {
        console.error('❌ Error processing message:', error);
        return {
            statusCode: 500,
            body: JSON.stringify({ error: 'Failed to send message' })
        };
    }
};

