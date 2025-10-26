/**
 * Generate Pre-Signed Upload URL for Voice Messages
 * Returns a temporary URL that iOS can use to upload audio files to S3
 */

const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');

const s3Client = new S3Client({ region: 'us-east-1' });
const BUCKET_NAME = process.env.VOICE_BUCKET_NAME || 'cloudy-voice-messages-alexho';

exports.handler = async (event) => {
  console.log('Generate Upload URL Request:', JSON.stringify(event, null, 2));
  
  // Parse request - handle both API Gateway and Function URL formats
  let body;
  try {
    // For Function URLs, the request is directly in event
    // For API Gateway, it's in event.body
    if (event.body) {
      body = JSON.parse(event.body);
    } else {
      body = event;
    }
  } catch (error) {
    return {
      statusCode: 400,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({ error: 'Invalid request body' })
    };
  }
  
  const { userId, messageId, contentType } = body;
  
  // Validate inputs
  if (!userId || !messageId) {
    return {
      statusCode: 400,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({ error: 'Missing userId or messageId' })
    };
  }
  
  try {
    // Generate S3 key (path in bucket)
    const s3Key = `${userId}/${messageId}.m4a`;
    
    console.log(`Generating upload URL for: ${s3Key}`);
    
    // Create PutObject command
    const command = new PutObjectCommand({
      Bucket: BUCKET_NAME,
      Key: s3Key,
      ContentType: contentType || 'audio/m4a',
      // Optional: Add metadata
      Metadata: {
        userId: userId,
        messageId: messageId,
        uploadedAt: new Date().toISOString()
      }
    });
    
    // Generate pre-signed URL (valid for 5 minutes)
    const uploadURL = await getSignedUrl(s3Client, command, { expiresIn: 300 });
    
    // Permanent URL to access the file (will also need pre-signed for download)
    const permanentURL = `https://${BUCKET_NAME}.s3.us-east-1.amazonaws.com/${s3Key}`;
    
    console.log(`✅ Generated upload URL (expires in 5 minutes)`);
    console.log(`   S3 Key: ${s3Key}`);
    console.log(`   Permanent URL: ${permanentURL}`);
    
    return {
      statusCode: 200,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({
        success: true,
        uploadURL: uploadURL,
        s3URL: permanentURL,
        s3Key: s3Key,
        expiresIn: 300
      })
    };
    
  } catch (error) {
    console.error('Error generating upload URL:', error);
    return {
      statusCode: 500,
      headers: {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*'
      },
      body: JSON.stringify({
        success: false,
        error: 'Failed to generate upload URL',
        message: error.message
      })
    };
  }
};

