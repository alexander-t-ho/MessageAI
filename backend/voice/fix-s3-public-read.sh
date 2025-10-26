#!/bin/bash

# Fix S3 bucket to allow public read access for voice messages
# This allows the iOS app to download voice messages directly

BUCKET_NAME="cloudy-voice-messages-alexho"
REGION="us-east-1"

echo "🔧 Fixing S3 bucket for public read access..."

# Remove public access block
aws s3api delete-public-access-block \
  --bucket $BUCKET_NAME

echo "✅ Public access block removed"

# Create bucket policy for public read access
cat > /tmp/bucket-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "PublicReadGetObject",
      "Effect": "Allow",
      "Principal": "*",
      "Action": "s3:GetObject",
      "Resource": "arn:aws:s3:::$BUCKET_NAME/*"
    }
  ]
}
EOF

aws s3api put-bucket-policy \
  --bucket $BUCKET_NAME \
  --policy file:///tmp/bucket-policy.json

echo "✅ Public read policy applied"

# Clean up temp files
rm /tmp/bucket-policy.json

echo ""
echo "🎉 S3 bucket fixed for public read access!"
echo ""
echo "Bucket Name: $BUCKET_NAME"
echo "Access: Public read, private write"
echo "Voice messages can now be downloaded directly"
echo ""
