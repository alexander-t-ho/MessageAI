/**
 * Lambda Function: Generate Pre-signed S3 Upload URLs for Images
 * This function generates pre-signed URLs that allow clients to upload images directly to S3
 */

const { S3Client, PutObjectCommand } = require('@aws-sdk/client-s3');
const { getSignedUrl } = require('@aws-sdk/s3-request-presigner');

const s3Client = new S3Client({ region: process.env.AWS_REGION || 'us-east-1' });

exports.handler = async (event) => {
    console.log('📸 Image Upload URL Request:', JSON.stringify(event, null, 2));
    
    let body;
    try {
        body = JSON.parse(event.body || '{}');
    } catch (error) {
        console.error('❌ Invalid JSON in request body');
        return {
            statusCode: 400,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({ error: 'Invalid request format' })
        };
    }
    
    const { bucketName, key, contentType } = body;
    
    // Validate required fields
    if (!bucketName || !key || !contentType) {
        console.error('❌ Missing required fields');
        return {
            statusCode: 400,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({ error: 'Missing required fields: bucketName, key, contentType' })
        };
    }
    
    console.log(`📦 Bucket: ${bucketName}`);
    console.log(`🔑 Key: ${key}`);
    console.log(`📄 Content-Type: ${contentType}`);
    
    try {
        // Create S3 PutObject command
        const command = new PutObjectCommand({
            Bucket: bucketName,
            Key: key,
            ContentType: contentType,
            // Optional: Add ACL for public read if needed
            // ACL: 'public-read'
        });
        
        // Generate pre-signed URL (valid for 5 minutes)
        const uploadURL = await getSignedUrl(s3Client, command, { expiresIn: 300 });
        
        console.log(`✅ Pre-signed URL generated for: ${key}`);
        
        return {
            statusCode: 200,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({
                uploadURL: uploadURL,
                s3URL: `https://${bucketName}.s3.${process.env.AWS_REGION || 'us-east-1'}.amazonaws.com/${key}`
            })
        };
        
    } catch (error) {
        console.error('❌ Error generating pre-signed URL:', error);
        return {
            statusCode: 500,
            headers: {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            body: JSON.stringify({ error: 'Failed to generate upload URL' })
        };
    }
};

