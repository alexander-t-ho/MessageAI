/**
 * WebSocket Disconnect Handler
 * Triggered when a user disconnects from the WebSocket API
 * Removes connection ID from DynamoDB
 */

const { DynamoDBClient } = require('@aws-sdk/client-dynamodb');
const { DynamoDBDocumentClient, DeleteCommand } = require('@aws-sdk/lib-dynamodb');

const client = new DynamoDBClient({ region: process.env.AWS_REGION || 'us-east-1' });
const docClient = DynamoDBDocumentClient.from(client);

const CONNECTIONS_TABLE = process.env.CONNECTIONS_TABLE || 'Connections_AlexHo';

exports.handler = async (event) => {
    console.log('WebSocket Disconnect Event:', JSON.stringify(event, null, 2));
    
    const connectionId = event.requestContext.connectionId;
    
    try {
        // Remove connection from DynamoDB
        await docClient.send(new DeleteCommand({
            TableName: CONNECTIONS_TABLE,
            Key: {
                connectionId: connectionId
            }
        }));
        
        console.log(`✅ Connection removed: ${connectionId}`);
        
        return {
            statusCode: 200,
            body: JSON.stringify({ message: 'Disconnected' })
        };
        
    } catch (error) {
        console.error('❌ Error removing connection:', error);
        return {
            statusCode: 500,
            body: JSON.stringify({ error: 'Failed to disconnect' })
        };
    }
};

