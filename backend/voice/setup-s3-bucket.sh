#!/bin/bash

# Setup S3 bucket for voice messages
# Run this script to create and configure the S3 bucket

BUCKET_NAME="cloudy-voice-messages-alexho"
REGION="us-east-1"

echo "🪣 Creating S3 bucket for voice messages..."

# Create S3 bucket
aws s3api create-bucket \
  --bucket $BUCKET_NAME \
  --region $REGION

echo "✅ Bucket created: $BUCKET_NAME"

# Enable versioning (optional but recommended)
aws s3api put-bucket-versioning \
  --bucket $BUCKET_NAME \
  --versioning-configuration Status=Enabled

echo "✅ Versioning enabled"

# Configure lifecycle policy (delete files after 30 days to save costs)
cat > /tmp/lifecycle-policy.json << 'EOF'
{
  "Rules": [
    {
      "Id": "DeleteOldVoiceMessages",
      "Status": "Enabled",
      "Prefix": "",
      "Expiration": {
        "Days": 30
      }
    }
  ]
}
EOF

aws s3api put-bucket-lifecycle-configuration \
  --bucket $BUCKET_NAME \
  --lifecycle-configuration file:///tmp/lifecycle-policy.json

echo "✅ Lifecycle policy set (30 day deletion)"

# Configure CORS for browser/app uploads
cat > /tmp/cors-config.json << 'EOF'
{
  "CORSRules": [
    {
      "AllowedOrigins": ["*"],
      "AllowedMethods": ["GET", "PUT", "POST"],
      "AllowedHeaders": ["*"],
      "ExposeHeaders": ["ETag"],
      "MaxAgeSeconds": 3000
    }
  ]
}
EOF

aws s3api put-bucket-cors \
  --bucket $BUCKET_NAME \
  --cors-configuration file:///tmp/cors-config.json

echo "✅ CORS configured"

# Block public access (we'll use pre-signed URLs)
aws s3api put-public-access-block \
  --bucket $BUCKET_NAME \
  --public-access-block-configuration \
    "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"

echo "✅ Public access blocked (using pre-signed URLs)"

# Clean up temp files
rm /tmp/lifecycle-policy.json
rm /tmp/cors-config.json

echo ""
echo "🎉 S3 bucket setup complete!"
echo ""
echo "Bucket Name: $BUCKET_NAME"
echo "Region: $REGION"
echo "Lifecycle: 30 days auto-delete"
echo "Access: Pre-signed URLs only"
echo ""
echo "Next step: Deploy Lambda functions"

