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
    console.log('Event:', JSON.stringify(event, null, 2));
    
    const connectionId = event.requestContext.connectionId;
    const domain = event.requestContext.domainName;
    const stage = event.requestContext.stage;
    
    console.log(`📡 Connection ID: ${connectionId}`);
    console.log(`📡 Domain: ${domain}`);
    console.log(`📡 Stage: ${stage}`);
    
    let groupData;
    try {
        groupData = JSON.parse(event.body);
        console.log('📦 Parsed group data:', JSON.stringify(groupData, null, 2));
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
        timestamp,
        groupAdmins,
        createdAt
    } = groupData;
    
    console.log(`👥 Group Name: ${groupName}`);
    console.log(`👥 Participants: ${participantIds?.length} - ${participantIds?.join(', ')}`);
    console.log(`👥 Created By: ${createdByName} (${createdBy})`);
    
    // Validate required fields
    if (!conversationId || !participantIds || !Array.isArray(participantIds) || participantIds.length < 2) {
        console.error('❌ Missing or invalid required fields');
        console.error(`   conversationId: ${conversationId}`);
        console.error(`   participantIds: ${JSON.stringify(participantIds)}`);
        console.error(`   participantIds.length: ${participantIds?.length}`);
        console.error(`   groupName: ${groupName}`);
        console.error(`   createdBy: ${createdBy}`);
        return {
            statusCode: 400,
            body: JSON.stringify({ error: 'Missing or invalid required fields' })
        };
    }
    
    console.log('✅ Validation passed, processing group creation...');
    
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
                createdAt: createdAt || timestamp || new Date().toISOString(),
                groupAdmins: groupAdmins || [createdBy],
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
                createdAt: createdAt || timestamp || new Date().toISOString(),
                groupAdmins: groupAdmins || [createdBy]
            }
        };
        
        // Send to ALL participants to ensure everyone gets the group
        // Including the creator to handle multi-device scenarios
        console.log(`📨 Broadcasting to ALL ${participantIds.length} participants`);
        
        for (const participantId of participantIds) {
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

