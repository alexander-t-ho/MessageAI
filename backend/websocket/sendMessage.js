/**
 * WebSocket Send Message Handler
 * Triggered when a user sends a message
 * 1. Saves message to DynamoDB
 * 2. Finds recipient's connection
 * 3. Sends message to recipient via WebSocket
 */

import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, PutCommand, QueryCommand, DeleteCommand, UpdateCommand } from '@aws-sdk/lib-dynamodb';
import { ApiGatewayManagementApiClient, PostToConnectionCommand } from '@aws-sdk/client-apigatewaymanagementapi';
import { SNSClient, PublishCommand } from '@aws-sdk/client-sns';

const client = new DynamoDBClient({ region: process.env.AWS_REGION || 'us-east-1' });
const docClient = DynamoDBDocumentClient.from(client);
const snsClient = new SNSClient({ region: process.env.AWS_REGION || 'us-east-1' });

const MESSAGES_TABLE = process.env.MESSAGES_TABLE || 'Messages_AlexHo';
const CONNECTIONS_TABLE = process.env.CONNECTIONS_TABLE || 'Connections_AlexHo';
const DEVICES_TABLE = process.env.DEVICES_TABLE || 'DeviceTokens_AlexHo';
const SNS_PLATFORM_APP_ARN = process.env.SNS_PLATFORM_APP_ARN;

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
        recipientIds,  // For group chats
        content,
        timestamp,
        replyToMessageId,
        replyToContent,
        replyToSenderName,
        isGroupChat
    } = messageData;
    
    // Validate required fields
    if (!messageId || !conversationId || !senderId || !content) {
        console.error('❌ Missing required fields');
        return {
            statusCode: 400,
            body: JSON.stringify({ error: 'Missing required fields' })
        };
    }
    
    // For group chats, use recipientIds; for direct messages, use recipientId
    const recipients = isGroupChat && recipientIds ? recipientIds.filter(id => id !== senderId) : [recipientId];
    
    if (recipients.length === 0 || !recipients[0]) {
        console.error('❌ No valid recipients');
        return {
            statusCode: 400,
            body: JSON.stringify({ error: 'No valid recipients' })
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
        console.log(`📡 Sending to ${recipients.length} recipient(s): ${recipients.join(', ')}`);
        
        // 2. Send message to all recipients
        const apiGateway = new ApiGatewayManagementApiClient({
            region: process.env.AWS_REGION || 'us-east-1',
            endpoint: `https://${domain}/${stage}`
        });
        
        let anyDelivered = false;
        
        // Loop through all recipients
        for (const recipientId of recipients) {
            const recipientConnections = await docClient.send(new QueryCommand({
                TableName: CONNECTIONS_TABLE,
                IndexName: 'userId-index',
                KeyConditionExpression: 'userId = :userId',
                ExpressionAttributeValues: {
                    ':userId': recipientId
                }
            }));
            
            console.log(`📡 Found ${recipientConnections.Items?.length || 0} connections for recipient ${recipientId}`);
            
            // Send to all connections for this recipient
            if (recipientConnections.Items && recipientConnections.Items.length > 0) {
                const results = await Promise.all((recipientConnections.Items || []).map(async (connection) => {
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
                    return true;
                } catch (error) {
                    if (error.statusCode === 410) {
                        console.log(`🧹 Removing stale connection: ${connection.connectionId}`);
                        await docClient.send(new DeleteCommand({
                            TableName: CONNECTIONS_TABLE,
                            Key: { connectionId: connection.connectionId }
                        }));
                    } else {
                        console.error(`❌ Error sending to ${connection.connectionId}:`, error);
                    }
                    return false;
                }
                }));

                // Track if any connection succeeded
                if (results.some(Boolean)) {
                    anyDelivered = true;
                }
            }
        }
        
        // 3. Send status ack back to sender if at least one recipient got the message
        if (anyDelivered) {
            // Mark message as delivered in database
            try {
                await docClient.send(new UpdateCommand({
                    TableName: MESSAGES_TABLE,
                    Key: { messageId: messageId },
                    UpdateExpression: "SET isDelivered = :true, #status = :delivered",
                    ExpressionAttributeNames: {
                        "#status": "status"
                    },
                    ExpressionAttributeValues: {
                        ":true": true,
                        ":delivered": "delivered"
                    }
                }));
                console.log(`✅ Message ${messageId} marked as delivered in database`);
            } catch (e) {
                console.error('❌ Error marking message as delivered in database:', e);
            }
            
            try {
                const senderConnections = await docClient.send(new QueryCommand({
                    TableName: CONNECTIONS_TABLE,
                    IndexName: 'userId-index',
                    KeyConditionExpression: 'userId = :userId',
                    ExpressionAttributeValues: { ':userId': senderId }
                }));
                const ackPromises = (senderConnections.Items || []).map(async (connection) => {
                    try {
                        await apiGateway.send(new PostToConnectionCommand({
                            ConnectionId: connection.connectionId,
                            Data: Buffer.from(JSON.stringify({
                                type: 'messageStatus',
                                data: { messageId, conversationId, status: 'delivered' }
                            }))
                        }));
                    } catch (e) {
                        console.error(`❌ Error sending delivery ack to ${connection.connectionId}:`, e);
                    }
                });
                await Promise.all(ackPromises);
            } catch (e) {
                console.error('❌ Error querying/sending sender delivery ack:', e);
            }
        } else {
            // All recipients are offline - message saved to DB, will be delivered when they connect
            console.log(`📴 All recipients offline - message saved for later delivery`);
        }
        
        // Send push notifications to all recipients (both online and offline)
        await sendPushNotifications(recipients, senderName, content, conversationId, conversation.nickname);
        
        // Send status acknowledgment to sender
        if (!anyDelivered) {
            // Send 'sent' ack to sender connections when no one was online
            try {
                const senderConnections = await docClient.send(new QueryCommand({
                    TableName: CONNECTIONS_TABLE,
                    IndexName: 'userId-index',
                    KeyConditionExpression: 'userId = :userId',
                    ExpressionAttributeValues: { ':userId': senderId }
                }));
                const ackPromises = (senderConnections.Items || []).map(async (connection) => {
                    try {
                        await apiGateway.send(new PostToConnectionCommand({
                            ConnectionId: connection.connectionId,
                            Data: Buffer.from(JSON.stringify({
                                type: 'messageStatus',
                                data: { messageId, conversationId, status: 'sent' }
                            }))
                        }));
                    } catch (e) {
                        console.error(`❌ Error sending sent ack to ${connection.connectionId}:`, e);
                    }
                });
                await Promise.all(ackPromises);
            } catch (e) {
                console.error('❌ Error sending sent ack:', e);
            }
        }
        
        return {
            statusCode: 200,
            body: JSON.stringify({
                message: anyDelivered ? 'Message delivered' : 'Message saved',
                messageId: messageId,
                status: anyDelivered ? 'delivered' : 'sent',
                recipientCount: recipients.length
            })
        };
        
    } catch (error) {
        console.error('❌ Error processing message:', error);
        return {
            statusCode: 500,
            body: JSON.stringify({ error: 'Failed to send message' })
        };
    }
};

// Helper function to send push notifications
async function sendPushNotifications(recipientIds, senderName, content, conversationId, conversationName) {
    if (!SNS_PLATFORM_APP_ARN) {
        console.log('⚠️ SNS Platform App ARN not configured - skipping push notifications');
        return;
    }
    
    for (const recipientId of recipientIds) {
        try {
            // Get device tokens for recipient
            const deviceResult = await docClient.send(new QueryCommand({
                TableName: DEVICES_TABLE,
                KeyConditionExpression: 'userId = :userId',
                ExpressionAttributeValues: { ':userId': recipientId }
            }));
            
            if (!deviceResult.Items || deviceResult.Items.length === 0) {
                console.log(`No device tokens found for user ${recipientId}`);
                continue;
            }
            
            // Send push notification to each device
            for (const device of deviceResult.Items) {
                try {
                    const notificationBody = conversationName 
                        ? `${senderName} in ${conversationName}: ${content}`
                        : `${senderName}: ${content}`;
                    
                    const message = {
                        default: notificationBody,
                        APNS: JSON.stringify({
                            aps: {
                                alert: {
                                    title: conversationName || senderName,
                                    body: content
                                },
                                sound: 'default',
                                badge: 1,
                                'content-available': 1
                            },
                            conversationId: conversationId
                        }),
                        APNS_SANDBOX: JSON.stringify({
                            aps: {
                                alert: {
                                    title: conversationName || senderName,
                                    body: content
                                },
                                sound: 'default',
                                badge: 1,
                                'content-available': 1
                            },
                            conversationId: conversationId
                        })
                    };
                    
                    // Create platform endpoint for device
                    const endpointArn = `${SNS_PLATFORM_APP_ARN}/${device.deviceToken}`;
                    
                    await snsClient.send(new PublishCommand({
                        Message: JSON.stringify(message),
                        MessageStructure: 'json',
                        TargetArn: endpointArn
                    }));
                    
                    console.log(`✅ Push notification sent to device ${device.deviceToken.substring(0, 10)}...`);
                } catch (error) {
                    console.error(`❌ Failed to send push to device:`, error);
                }
            }
        } catch (error) {
            console.error(`❌ Error getting device tokens for ${recipientId}:`, error);
        }
    }
}
