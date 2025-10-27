#!/bin/bash

# Setup S3 Bucket for Image Messages
# This script creates an S3 bucket for storing image messages

BUCKET_NAME="cloudy-images-alexho"
REGION="us-east-1"

echo "📦 Setting up S3 bucket for image messages..."

# Check if bucket exists
if aws s3 ls "s3://$BUCKET_NAME" 2>/dev/null; then
  echo "✅ Bucket already exists: $BUCKET_NAME"
else
  echo "Creating S3 bucket..."
  aws s3api create-bucket \
    --bucket $BUCKET_NAME \
    --region $REGION
  
  echo "✅ Bucket created: $BUCKET_NAME"
fi

# Enable versioning
echo "🔄 Enabling versioning..."
aws s3api put-bucket-versioning \
  --bucket $BUCKET_NAME \
  --versioning-configuration Status=Enabled

# Set CORS configuration
echo "🌐 Setting CORS configuration..."
cat > /tmp/cors-config.json << 'EOF'
{
  "CORSRules": [
    {
      "AllowedOrigins": ["*"],
      "AllowedMethods": ["GET", "PUT", "POST", "DELETE", "HEAD"],
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

rm /tmp/cors-config.json

# Set lifecycle policy to delete objects after 90 days (optional)
echo "♻️  Setting lifecycle policy..."
cat > /tmp/lifecycle-policy.json << 'EOF'
{
  "Rules": [
    {
      "Id": "DeleteOldImages",
      "Status": "Enabled",
      "Prefix": "",
      "Expiration": {
        "Days": 90
      }
    }
  ]
}
EOF

aws s3api put-bucket-lifecycle-configuration \
  --bucket $BUCKET_NAME \
  --lifecycle-configuration file:///tmp/lifecycle-policy.json

rm /tmp/lifecycle-policy.json

# Remove public access block (to allow public read)
echo "🔓 Removing public access block..."
aws s3api delete-public-access-block \
  --bucket $BUCKET_NAME

# Set bucket policy for public read
echo "📖 Setting bucket policy for public read..."
cat > /tmp/bucket-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::${BUCKET_NAME}/*"
    }
  ]
}
EOF

aws s3api put-bucket-policy \
  --bucket $BUCKET_NAME \
  --policy file:///tmp/bucket-policy.json

rm /tmp/bucket-policy.json

echo ""
echo "🎉 S3 Bucket setup complete!"
echo ""
echo "Bucket Name: $BUCKET_NAME"
echo "Region: $REGION"
echo "Bucket URL: https://$BUCKET_NAME.s3.$REGION.amazonaws.com"
echo ""
echo "✅ Next steps:"
echo "1. Run ./deploy-image-lambdas.sh to deploy Lambda functions"
echo "2. Update S3ImageStorage.swift with the Lambda function URL"
echo ""

