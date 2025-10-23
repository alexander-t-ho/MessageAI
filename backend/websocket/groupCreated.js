/**
 * WebSocket Group Created Handler
 * Triggered when a user creates a group chat
 * 1. Saves group info to DynamoDB
 * 2. Notifies all participants about the new group
 */

import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, PutCommand, QueryCommand, DeleteCommand } from '@aws-sdk/lib-dynamodb';
import { ApiGatewayManagementApiClient, PostToConnectionCommand } from '@aws-sdk/client-apigatewaymanagementapi';

const client = new DynamoDBClient({ region: process.env.AWS_REGION || 'us-east-1' });
const docClient = DynamoDBDocumentClient.from(client);

const CONVERSATIONS_TABLE = process.env.CONVERSATIONS_TABLE || 'Conversations_AlexHo';
const CONNECTIONS_TABLE = process.env.CONNECTIONS_TABLE || 'Connections_AlexHo';

export const handler = async (event) => {
    console.log('WebSocket GroupCreated Event:', JSON.stringify(event, null, 2));
    
    const connectionId = event.requestContext.connectionId;
    const domain = event.requestContext.domainName;
    const stage = event.requestContext.stage;
    
    let groupData;
    try {
        groupData = JSON.parse(event.body);
    } catch (error) {
        console.error('❌ Invalid JSON in message body');
        return {
            statusCode: 400,
            body: JSON.stringify({ error: 'Invalid message format' })
        };
    }
    
    const {
        conversationId,
        groupName,
        participantIds,
        participantNames,
        createdBy,
        createdByName,
        timestamp
    } = groupData;
    
    // Validate required fields
    if (!conversationId || !participantIds || !Array.isArray(participantIds) || participantIds.length < 2) {
        console.error('❌ Missing or invalid required fields');
        return {
            statusCode: 400,
            body: JSON.stringify({ error: 'Missing or invalid required fields' })
        };
    }
    
    try {
        // 1. Save group conversation to DynamoDB
        await docClient.send(new PutCommand({
            TableName: CONVERSATIONS_TABLE,
            Item: {
                conversationId: conversationId,
                participantIds: participantIds,
                participantNames: participantNames || [],
                isGroupChat: true,
                groupName: groupName || 'Group Chat',
                createdBy: createdBy,
                createdByName: createdByName,
                createdAt: timestamp || new Date().toISOString(),
                groupAdmins: [createdBy],
                lastUpdatedAt: timestamp || new Date().toISOString()
            }
        }));
        
        console.log(`✅ Group conversation saved to DynamoDB: ${conversationId}`);
        
        // 2. Notify all participants about the new group
        const apiGateway = new ApiGatewayManagementApiClient({
            region: process.env.AWS_REGION || 'us-east-1',
            endpoint: `https://${domain}/${stage}`
        });
        
        const notificationPayload = {
            type: 'groupCreated',
            data: {
                conversationId,
                groupName: groupName || 'Group Chat',
                participantIds,
                participantNames: participantNames || [],
                isGroupChat: true,
                createdBy,
                createdByName,
                createdAt: timestamp || new Date().toISOString(),
                groupAdmins: [createdBy]
            }
        };
        
        // Send to all participants except creator (they already have it locally)
        const otherParticipants = participantIds.filter(id => id !== createdBy);
        
        for (const participantId of otherParticipants) {
            try {
                const connections = await docClient.send(new QueryCommand({
                    TableName: CONNECTIONS_TABLE,
                    IndexName: 'userId-index',
                    KeyConditionExpression: 'userId = :userId',
                    ExpressionAttributeValues: {
                        ':userId': participantId
                    }
                }));
                
                if (connections.Items && connections.Items.length > 0) {
                    for (const connection of connections.Items) {
                        try {
                            await apiGateway.send(new PostToConnectionCommand({
                                ConnectionId: connection.connectionId,
                                Data: Buffer.from(JSON.stringify(notificationPayload))
                            }));
                            console.log(`✅ Group notification sent to ${participantId} (${connection.connectionId})`);
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
                        }
                    }
                } else {
                    console.log(`📴 Participant ${participantId} is offline - will receive group on reconnect`);
                }
            } catch (error) {
                console.error(`❌ Error processing participant ${participantId}:`, error);
            }
        }
        
        return {
            statusCode: 200,
            body: JSON.stringify({
                message: 'Group created',
                conversationId: conversationId
            })
        };
        
    } catch (error) {
        console.error('❌ Error creating group:', error);
        return {
            statusCode: 500,
            body: JSON.stringify({ error: 'Failed to create group' })
        };
    }
};

