#!/bin/bash

# Deploy Image Message Lambda Functions
# This script deploys the Lambda for generating S3 upload URLs for images

FUNCTION_NAME="image-generateUploadUrl_AlexHo"
REGION="us-east-1"
BUCKET_NAME="cloudy-images-alexho"

echo "📦 Installing dependencies..."
npm install

echo "📦 Creating deployment package..."
zip -r function.zip generateImageUploadUrl.js node_modules/ package.json

echo "🚀 Deploying Lambda function..."

# Check if function exists
if aws lambda get-function --function-name $FUNCTION_NAME --region $REGION 2>/dev/null; then
  echo "♻️  Function exists, updating code..."
  aws lambda update-function-code \
    --function-name $FUNCTION_NAME \
    --zip-file fileb://function.zip \
    --region $REGION
else
  echo "🆕 Creating new function..."
  
  # Create IAM role first if needed
  ROLE_NAME="CloudyImageLambdaRole"
  
  # Check if role exists
  if ! aws iam get-role --role-name $ROLE_NAME 2>/dev/null; then
    echo "Creating IAM role..."
    
    cat > /tmp/trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
    
    aws iam create-role \
      --role-name $ROLE_NAME \
      --assume-role-policy-document file:///tmp/trust-policy.json
    
    # Attach policies
    aws iam attach-role-policy \
      --role-name $ROLE_NAME \
      --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole
    
    # Create and attach S3 policy
    cat > /tmp/s3-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::${BUCKET_NAME}/*"
    }
  ]
}
EOF
    
    aws iam put-role-policy \
      --role-name $ROLE_NAME \
      --policy-name S3ImageMessagesPolicy \
      --policy-document file:///tmp/s3-policy.json
    
    echo "⏳ Waiting 10 seconds for role to propagate..."
    sleep 10
    
    rm /tmp/trust-policy.json /tmp/s3-policy.json
  fi
  
  # Get role ARN
  ROLE_ARN=$(aws iam get-role --role-name $ROLE_NAME --query 'Role.Arn' --output text)
  
  # Create Lambda function
  aws lambda create-function \
    --function-name $FUNCTION_NAME \
    --runtime nodejs20.x \
    --role $ROLE_ARN \
    --handler generateImageUploadUrl.handler \
    --zip-file fileb://function.zip \
    --timeout 10 \
    --memory-size 256 \
    --environment "Variables={IMAGE_BUCKET_NAME=$BUCKET_NAME}" \
    --region $REGION
fi

echo "✅ Lambda function deployed: $FUNCTION_NAME"

# Create function URL for easy access
echo "🔗 Creating function URL..."
aws lambda create-function-url-config \
  --function-name $FUNCTION_NAME \
  --auth-type NONE \
  --cors '{"AllowOrigins":["*"],"AllowMethods":["POST"],"AllowHeaders":["*"],"MaxAge":86400}' \
  --region $REGION 2>/dev/null || echo "Function URL already exists"

# Get function URL
FUNCTION_URL=$(aws lambda get-function-url-config \
  --function-name $FUNCTION_NAME \
  --region $REGION \
  --query 'FunctionUrl' \
  --output text)

echo ""
echo "🎉 Deployment complete!"
echo ""
echo "Function Name: $FUNCTION_NAME"
echo "Function URL: $FUNCTION_URL"
echo "S3 Bucket: $BUCKET_NAME"
echo ""
echo "📝 Update S3ImageStorage.swift with this URL:"
echo "   uploadURLEndpoint = \"$FUNCTION_URL\""
echo ""
echo "🧪 Test with:"
echo "curl -X POST $FUNCTION_URL \\"
echo "  -H 'Content-Type: application/json' \\"
echo "  -d '{\"bucketName\":\"$BUCKET_NAME\",\"key\":\"test/image.jpg\",\"contentType\":\"image/jpeg\"}'"
echo ""

# Clean up
rm function.zip

echo "✅ Setup complete! Image messages ready for S3 upload."

