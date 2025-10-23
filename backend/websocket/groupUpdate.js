/**
 * WebSocket Group Update Handler
 * Triggered when group info is updated (e.g., name change)
 * Notifies all participants about the update
 */

import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, UpdateCommand, QueryCommand, DeleteCommand } from '@aws-sdk/lib-dynamodb';
import { ApiGatewayManagementApiClient, PostToConnectionCommand } from '@aws-sdk/client-apigatewaymanagementapi';

const client = new DynamoDBClient({ region: process.env.AWS_REGION || 'us-east-1' });
const docClient = DynamoDBDocumentClient.from(client);

const CONVERSATIONS_TABLE = process.env.CONVERSATIONS_TABLE || 'Conversations_AlexHo';
const CONNECTIONS_TABLE = process.env.CONNECTIONS_TABLE || 'Connections_AlexHo';

export const handler = async (event) => {
    console.log('WebSocket GroupUpdate Event:', JSON.stringify(event, null, 2));
    
    const domain = event.requestContext.domainName;
    const stage = event.requestContext.stage;
    
    let updateData;
    try {
        updateData = JSON.parse(event.body);
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
        updatedBy,
        updatedByName,
        participantIds,
        timestamp
    } = updateData;
    
    if (!conversationId || !groupName || !participantIds) {
        console.error('❌ Missing required fields');
        return {
            statusCode: 400,
            body: JSON.stringify({ error: 'Missing required fields' })
        };
    }
    
    try {
        // Update group name in DynamoDB
        await docClient.send(new UpdateCommand({
            TableName: CONVERSATIONS_TABLE,
            Key: { conversationId },
            UpdateExpression: 'SET groupName = :name, lastUpdatedBy = :updatedBy, lastUpdatedAt = :updatedAt',
            ExpressionAttributeValues: {
                ':name': groupName,
                ':updatedBy': updatedBy,
                ':updatedAt': timestamp || new Date().toISOString()
            }
        }));
        
        console.log(`✅ Group updated in DynamoDB: ${conversationId}`);
        
        // Notify all participants
        const apiGateway = new ApiGatewayManagementApiClient({
            region: process.env.AWS_REGION || 'us-east-1',
            endpoint: `https://${domain}/${stage}`
        });
        
        const notificationPayload = {
            type: 'groupUpdate',
            data: {
                conversationId,
                groupName,
                updatedBy,
                updatedByName,
                timestamp: timestamp || new Date().toISOString()
            }
        };
        
        // Send to all participants
        for (const participantId of participantIds) {
            try {
                const connections = await docClient.send(new QueryCommand({
                    TableName: CONNECTIONS_TABLE,
                    IndexName: 'userId-index',
                    KeyConditionExpression: 'userId = :userId',
                    ExpressionAttributeValues: { ':userId': participantId }
                }));
                
                if (connections.Items && connections.Items.length > 0) {
                    for (const connection of connections.Items) {
                        try {
                            await apiGateway.send(new PostToConnectionCommand({
                                ConnectionId: connection.connectionId,
                                Data: Buffer.from(JSON.stringify(notificationPayload))
                            }));
                            console.log(`✅ Update notification sent to ${participantId}`);
                        } catch (error) {
                            if (error.statusCode === 410) {
                                await docClient.send(new DeleteCommand({
                                    TableName: CONNECTIONS_TABLE,
                                    Key: { connectionId: connection.connectionId }
                                }));
                            }
                        }
                    }
                }
            } catch (error) {
                console.error(`❌ Error notifying ${participantId}:`, error);
            }
        }
        
        return {
            statusCode: 200,
            body: JSON.stringify({ message: 'Group updated' })
        };
        
    } catch (error) {
        console.error('❌ Error updating group:', error);
        return {
            statusCode: 500,
            body: JSON.stringify({ error: 'Failed to update group' })
        };
    }
};

