/**
 * WebSocket Register Device Handler
 * Stores device tokens for push notifications
 */

import { DynamoDBClient } from "@aws-sdk/client-dynamodb";
import { DynamoDBDocumentClient, PutCommand } from "@aws-sdk/lib-dynamodb";

const client = new DynamoDBClient({ region: process.env.AWS_REGION || "us-east-1" });
const docClient = DynamoDBDocumentClient.from(client);

const DEVICES_TABLE = process.env.DEVICES_TABLE || "DeviceTokens_AlexHo";

export const handler = async (event) => {
  console.log("Register Device Event:", JSON.stringify(event, null, 2));
  
  let body;
  try {
    body = JSON.parse(event.body || "{}");
  } catch (e) {
    console.error('Bad JSON body', e);
    return { statusCode: 400, body: JSON.stringify({ error: "Invalid body" }) };
  }
  
  const { userId, deviceToken, platform = "ios" } = body;
  const connectionId = event.requestContext?.connectionId;
  
  if (!userId || !deviceToken) {
    return {
      statusCode: 400,
      body: JSON.stringify({ error: "userId and deviceToken required" })
    };
  }
  
  try {
    // Store device token in DynamoDB
    await docClient.send(new PutCommand({
      TableName: DEVICES_TABLE,
      Item: {
        userId,
        deviceToken,
        platform,
        connectionId,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString()
      }
    }));
    
    console.log(`✅ Device token registered for user ${userId}`);
    
    return {
      statusCode: 200,
      body: JSON.stringify({ 
        success: true,
        message: "Device token registered"
      })
    };
  } catch (e) {
    console.error('Register device error:', e);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: 'Failed to register device' })
    };
  }
};
