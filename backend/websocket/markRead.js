/**
 * WebSocket markRead Handler
 * Marks messages as read and tracks per-user read receipts for group chats
 */
const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, UpdateCommand, QueryCommand, GetCommand, DeleteCommand } = require("@aws-sdk/lib-dynamodb");
const { ApiGatewayManagementApiClient, PostToConnectionCommand } = require("@aws-sdk/client-apigatewaymanagementapi");

const client = new DynamoDBClient({ region: process.env.AWS_REGION || "us-east-1" });
const docClient = DynamoDBDocumentClient.from(client);

const MESSAGES_TABLE = process.env.MESSAGES_TABLE || "Messages_AlexHo";
const CONNECTIONS_TABLE = process.env.CONNECTIONS_TABLE || "Connections_AlexHo";
const CONVERSATIONS_TABLE = process.env.CONVERSATIONS_TABLE || "Conversations_AlexHo";

exports.handler = async (event) => {
  try {
    console.log("[markRead] Event received");
    const domain = event.requestContext?.domainName;
    const stage = event.requestContext?.stage;

    let body;
    try { 
      body = JSON.parse(event.body || "{}"); 
    } catch (e) { 
      console.error('[error] Bad JSON body', e); 
      body = {}; 
    }
    
    const { conversationId, readerId, readerName, messageIds, isGroupChat } = body;
    
    if (!conversationId || !readerId || !Array.isArray(messageIds) || messageIds.length === 0) {
      return { 
        statusCode: 400, 
        body: JSON.stringify({ error: "conversationId, readerId, messageIds required" }) 
      };
    }

    console.log(`[markRead] Marking ${messageIds.length} messages as read`);
    console.log(`   Reader: ${readerName || readerId}`);
    console.log(`   Conversation: ${conversationId}`);
    console.log(`   Is Group Chat: ${isGroupChat || false}`);

    const readAt = new Date().toISOString();
    const messageIdToSender = {};
    
    // Update messages to read
    for (const messageId of messageIds) {
      try {
        // For group chats, we need to update the per-recipient record
        const dbMessageId = isGroupChat ? `${messageId}_${readerId}` : messageId;
        
        // First get the current message to get sender info
        const getMessage = await docClient.send(new GetCommand({
          TableName: MESSAGES_TABLE,
          Key: { messageId: dbMessageId }
        }));
        
        if (!getMessage.Item) {
          console.warn(`Message ${dbMessageId} not found (originalId: ${messageId})`);
          continue;
        }
        
        const currentMessage = getMessage.Item;
        const senderId = currentMessage.senderId;
        
        // STEP 1: Update the current reader's per-recipient record FIRST
        let updateExpression;
        let expressionAttributeNames;
        let expressionAttributeValues;
        
        if (isGroupChat) {
          // For group chats, update the per-recipient record with read status
          updateExpression = "SET #s = :read, #ra = :ra";
          expressionAttributeNames = { 
            "#s": "status", 
            "#ra": "readAt"
          };
          expressionAttributeValues = { 
            ":read": "read", 
            ":ra": readAt
          };
          
          console.log(`[markRead] Marking message ${messageId} as read by ${readerName}`);
        } else {
          // For direct messages, simple read status
          updateExpression = "SET #s = :read, #ra = :ra";
          expressionAttributeNames = { "#s": "status", "#ra": "readAt" };
          expressionAttributeValues = { ":read": "read", ":ra": readAt };
        }
        
        await docClient.send(new UpdateCommand({
          TableName: MESSAGES_TABLE,
          Key: { messageId: dbMessageId },
          UpdateExpression: updateExpression,
          ExpressionAttributeNames: expressionAttributeNames,
          ExpressionAttributeValues: expressionAttributeValues
        }));
        
        // STEP 2: For group chats, NOW aggregate read status from ALL per-recipient records
        let aggregatedReadByUserIds = [];
        let aggregatedReadByUserNames = [];
        let aggregatedReadTimestamps = {};
        
        if (isGroupChat) {
          // First, get the conversation to map user IDs to names
          let participantNamesMap = new Map();
          try {
            const conversationResult = await docClient.send(new GetCommand({
              TableName: CONVERSATIONS_TABLE,
              Key: { conversationId: conversationId }
            }));
            
            if (conversationResult.Item) {
              const participantIds = conversationResult.Item.participantIds || [];
              const participantNames = conversationResult.Item.participantNames || [];
              
              // Create a map of userId -> name
              participantIds.forEach((id, index) => {
                if (index < participantNames.length) {
                  participantNamesMap.set(id, participantNames[index]);
                }
              });
              
              console.log(`[loaded] Loaded ${participantNamesMap.size} participant names from conversation`);
            }
          } catch (err) {
            console.warn(`[warning] Could not load conversation: ${err.message}`);
          }
          
          // Query all per-recipient records for this message AFTER updating current user
          const allRecords = await docClient.send(new QueryCommand({
            TableName: MESSAGES_TABLE,
            IndexName: 'conversationId-timestamp-index',
            KeyConditionExpression: 'conversationId = :cid',
            FilterExpression: 'originalMessageId = :omid',
            ExpressionAttributeValues: {
              ':cid': conversationId,
              ':omid': messageId
            }
          }));
          
          // Aggregate all readers from all records
          const allReaders = new Set();
          const allReaderNamesMap = new Map(); // userId -> name
          
          (allRecords.Items || []).forEach(record => {
            // Check if this per-recipient record has been marked as read
            if ((record.status === 'read' || record.readAt) && record.recipientId && record.recipientId !== senderId) {
              allReaders.add(record.recipientId);
              
              // Get name from conversation participant map
              if (!allReaderNamesMap.has(record.recipientId)) {
                let name;
                // First try participant names map from conversation
                if (participantNamesMap.has(record.recipientId)) {
                  name = participantNamesMap.get(record.recipientId);
                }
                // If this is the current reader, use their name from the request
                else if (record.recipientId === readerId && readerName) {
                  name = readerName;
                }
                // Fallback to recipientId
                else {
                  name = record.recipientId;
                }
                allReaderNamesMap.set(record.recipientId, name);
                console.log(`      Mapped ${record.recipientId} -> ${name}`);
              }
              
              // Add read timestamp
              if (record.readAt) {
                aggregatedReadTimestamps[record.recipientId] = record.readAt;
              }
            }
          });
          
          aggregatedReadByUserIds = Array.from(allReaders);
          aggregatedReadByUserNames = Array.from(allReaderNamesMap.values());
          
          console.log(`[aggregated] Aggregated readers for ${messageId}:`);
          console.log(`   Total records found: ${allRecords.Items?.length || 0}`);
          console.log(`   Records marked as read: ${allReaders.size}`);
          console.log(`   User IDs: ${aggregatedReadByUserIds.join(', ')}`);
          console.log(`   Names: ${aggregatedReadByUserNames.join(', ')}`);
          console.log(`   Participant map had ${participantNamesMap.size} entries`);
          
          // Detailed debugging
          allRecords.Items?.forEach(record => {
            console.log(`      Record: recipientId=${record.recipientId}, status=${record.status}, readAt=${record.readAt}, senderId=${record.senderId}`);
          });
        }
        
        if (senderId) {
          messageIdToSender[messageId] = {
            senderId,
            readByUserIds: isGroupChat ? aggregatedReadByUserIds : [],
            readByUserNames: isGroupChat ? aggregatedReadByUserNames : [],
            readTimestamps: isGroupChat ? aggregatedReadTimestamps : {}
          };
        }
        
        console.log(`[success] Marked message ${messageId} as read by ${readerName || readerId}`);
        if (isGroupChat && aggregatedReadByUserNames.length > 0) {
          console.log(`   All readers: ${aggregatedReadByUserNames.join(', ')}`);
        }
      } catch (e) { 
        console.error(`[error] Update read failed for ${messageId}:`, e.message); 
      }
    }

    // Notify all relevant connections
    const api = new ApiGatewayManagementApiClient({ 
      region: process.env.AWS_REGION || "us-east-1", 
      endpoint: `https://${domain}/${stage}` 
    });
    
    for (const messageId of messageIds) {
      const messageInfo = messageIdToSender[messageId];
      if (!messageInfo) {
        console.warn(`[warning] Could not resolve sender for ${messageId}`);
        continue;
      }
      
      const { senderId, readByUserIds, readByUserNames, readTimestamps } = messageInfo;
      
      // Prepare read status payload
      const readStatusPayload = {
        type: 'messageStatus',
        data: {
          messageId,
          conversationId,
          status: 'read',
          readerId,
          readerName: readerName || readerId,
          readAt,
          isGroupChat: isGroupChat || false,
          // For group chats, include full read receipt info
          ...(isGroupChat && {
            readByUserIds,
            readByUserNames,
            readTimestamps
          })
        }
      };
      
      console.log(`[sending] Sending read status payload for message ${messageId}:`);
      console.log(`   isGroupChat: ${isGroupChat}`);
      console.log(`   readByUserIds: ${JSON.stringify(readByUserIds)}`);
      console.log(`   readByUserNames: ${JSON.stringify(readByUserNames)}`);
      console.log(`   Full payload: ${JSON.stringify(readStatusPayload, null, 2)}`);
      
      try {
        // Notify sender's connections
        const senderConnections = await docClient.send(new QueryCommand({
          TableName: CONNECTIONS_TABLE,
          IndexName: 'userId-index',
          KeyConditionExpression: 'userId = :u',
          ExpressionAttributeValues: { ':u': senderId }
        }));
        
        console.log(`[notifying] Notifying sender (${senderId}): ${senderConnections.Items?.length || 0} connections`);
        
        for (const c of (senderConnections.Items || [])) {
          try {
            await api.send(new PostToConnectionCommand({
              ConnectionId: c.connectionId,
              Data: Buffer.from(JSON.stringify(readStatusPayload))
            }));
            console.log(`[success] Sent read status to sender connection ${c.connectionId}`);
          } catch (postErr) {
            if (postErr.statusCode === 410) {
              console.log(`[cleanup] Removing stale sender connection: ${c.connectionId}`);
              await docClient.send(new DeleteCommand({
                TableName: CONNECTIONS_TABLE,
                Key: { connectionId: c.connectionId }
              }));
            } else {
              console.error(`[error] Failed to send to ${c.connectionId}:`, postErr.message);
            }
          }
        }
        
        // For group chats, also notify other group members
        if (isGroupChat) {
          // Need to get all per-recipient records to find all participants
          // Query all messages with the same originalMessageId
          const allMessageRecords = await docClient.send(new QueryCommand({
            TableName: MESSAGES_TABLE,
            IndexName: 'conversationId-timestamp-index',
            KeyConditionExpression: 'conversationId = :cid',
            FilterExpression: '(originalMessageId = :omid OR messageId = :mid)',
            ExpressionAttributeValues: { 
              ':cid': conversationId,
              ':omid': messageId,
              ':mid': messageId
            }
          }));
          
          // Extract all participant IDs
          const allParticipantIds = new Set([senderId]); // Include sender
          (allMessageRecords.Items || []).forEach(item => {
            if (item.recipientId) {
              allParticipantIds.add(item.recipientId);
            }
          });
          
          if (allParticipantIds.size > 1) {
            const allParticipants = allParticipantIds;
            
            console.log(`[notifying] Group chat - broadcasting to ${allParticipants.size} participants`);
            
            for (const participantId of allParticipants) {
              // Skip if we already notified them
              if (participantId === senderId || participantId === readerId) {
                continue; // Already handled above or is the reader themselves
              }
              
              // Get connections for this participant
              const participantConnections = await docClient.send(new QueryCommand({
                TableName: CONNECTIONS_TABLE,
                IndexName: 'userId-index',
                KeyConditionExpression: 'userId = :u',
                ExpressionAttributeValues: { ':u': participantId }
              }));
              
              console.log(`[notifying] Notifying participant (${participantId}): ${participantConnections.Items?.length || 0} connections`);
              
              for (const c of (participantConnections.Items || [])) {
                try {
                  await api.send(new PostToConnectionCommand({
                    ConnectionId: c.connectionId,
                    Data: Buffer.from(JSON.stringify(readStatusPayload))
                  }));
                  console.log(`[success] Sent read status to participant connection ${c.connectionId}`);
                } catch (postErr) {
                  if (postErr.statusCode === 410) {
                    console.log(`[cleanup] Removing stale participant connection: ${c.connectionId}`);
                    await docClient.send(new DeleteCommand({
                      TableName: CONNECTIONS_TABLE,
                      Key: { connectionId: c.connectionId }
                    }));
                  } else {
                    console.error(`[error] Failed to send to ${c.connectionId}:`, postErr.message);
                  }
                }
              }
            }
          }
        }
        
      } catch (e) {
        console.error(`[error] Error notifying for ${messageId}:`, e.message);
      }
    }

    return { 
      statusCode: 200, 
      body: JSON.stringify({ 
        message: "Messages marked as read", 
        count: messageIds.length,
        isGroupChat: isGroupChat || false
      }) 
    };
    
  } catch (e) {
    console.error("[error] Fatal error in markRead:", e);
    return { 
      statusCode: 500, 
      body: JSON.stringify({ error: e.message }) 
    };
  }
};
