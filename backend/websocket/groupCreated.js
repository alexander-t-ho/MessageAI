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
    console.log('🎯🎯🎯 WebSocket GroupCreated Event RECEIVED 🎯🎯🎯');
    
    try {
        // Parse request
        const connectionId = event.requestContext.connectionId;
        const domain = event.requestContext.domainName;
        const stage = event.requestContext.stage;
        
        console.log(`📡 Connection: ${connectionId}, Domain: ${domain}/${stage}`);
        
        // Parse body
        let groupData;
        try {
            groupData = JSON.parse(event.body);
            console.log('📦 Group data received');
        } catch (error) {
            console.error('❌ Invalid JSON in body:', event.body);
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
            timestamp,
            groupAdmins,
            createdAt
        } = groupData;
        
        console.log(`👥 Creating group: ${groupName}`);
        console.log(`👥 Participants: ${participantIds?.length} users`);
        console.log(`👥 IDs: ${participantIds?.join(', ')}`);
        
        // Validate
        if (!conversationId || !participantIds || !Array.isArray(participantIds) || participantIds.length < 2) {
            console.error('❌ Invalid group data');
            return {
                statusCode: 400,
                body: JSON.stringify({ error: 'Invalid group data' })
            };
        }
        
        // 1. Save to DynamoDB
        console.log('💾 Saving group to DynamoDB...');
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
                createdAt: createdAt || timestamp || new Date().toISOString(),
                groupAdmins: groupAdmins || [createdBy],
                lastUpdatedAt: new Date().toISOString()
            }
        }));
        console.log(`✅ Group saved: ${conversationId}`);
        
        // 2. Broadcast to all participants
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
                createdAt: createdAt || timestamp || new Date().toISOString(),
                groupAdmins: groupAdmins || [createdBy]
            }
        };
        
        console.log(`📨 Broadcasting to ${participantIds.length} participants...`);
        let successCount = 0;
        let failCount = 0;
        
        // Send to ALL participants (including creator for multi-device support)
        for (const participantId of participantIds) {
            try {
                // Get all connections for this user
                const connections = await docClient.send(new QueryCommand({
                    TableName: CONNECTIONS_TABLE,
                    IndexName: 'userId-index',
                    KeyConditionExpression: 'userId = :userId',
                    ExpressionAttributeValues: {
                        ':userId': participantId
                    }
                }));
                
                if (connections.Items && connections.Items.length > 0) {
                    console.log(`📱 User ${participantId} has ${connections.Items.length} connection(s)`);
                    
                    for (const connection of connections.Items) {
                        try {
                            await apiGateway.send(new PostToConnectionCommand({
                                ConnectionId: connection.connectionId,
                                Data: Buffer.from(JSON.stringify(notificationPayload))
                            }));
                            successCount++;
                            console.log(`✅ Sent to ${participantId} (${connection.connectionId})`);
                        } catch (error) {
                            if (error.statusCode === 410) {
                                // Stale connection - remove it
                                console.log(`🧹 Removing stale connection: ${connection.connectionId}`);
                                await docClient.send(new DeleteCommand({
                                    TableName: CONNECTIONS_TABLE,
                                    Key: { connectionId: connection.connectionId }
                                }));
                            } else {
                                console.error(`❌ Failed to send to ${connection.connectionId}:`, error.message);
                                failCount++;
                            }
                        }
                    }
                } else {
                    console.log(`📴 User ${participantId} is offline`);
                }
            } catch (error) {
                console.error(`❌ Error processing user ${participantId}:`, error.message);
                failCount++;
            }
        }
        
        console.log(`📊 Broadcast complete: ${successCount} sent, ${failCount} failed`);
        
        return {
            statusCode: 200,
            body: JSON.stringify({
                message: 'Group created successfully',
                conversationId: conversationId,
                notified: successCount,
                failed: failCount
            })
        };
        
    } catch (error) {
        console.error('❌ Fatal error:', error.message);
        console.error('Stack:', error.stack);
        
        return {
            statusCode: 500,
            body: JSON.stringify({ error: 'Internal server error' })
        };
    }
};