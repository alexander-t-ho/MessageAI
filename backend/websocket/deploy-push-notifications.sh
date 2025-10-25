#!/bin/bash

# Deploy push notification infrastructure
# Run from backend/websocket directory

set -e

echo "🚀 Deploying Push Notification Infrastructure..."

# Variables
AWS_REGION="us-east-1"
USER_SUFFIX="_AlexHo"
API_ID=$(cat .api-id.txt 2>/dev/null || echo "")

# Check if API ID exists
if [ -z "$API_ID" ]; then
    echo "❌ No API ID found. Run deploy.sh first."
    exit 1
fi

# Create DynamoDB table for device tokens
echo "📱 Creating DeviceTokens table..."
aws dynamodb create-table \
    --table-name "DeviceTokens${USER_SUFFIX}" \
    --attribute-definitions \
        AttributeName=userId,AttributeType=S \
        AttributeName=deviceToken,AttributeType=S \
    --key-schema \
        AttributeName=userId,KeyType=HASH \
        AttributeName=deviceToken,KeyType=RANGE \
    --billing-mode PAY_PER_REQUEST \
    --region $AWS_REGION 2>/dev/null || echo "Table already exists"

# Deploy registerDevice Lambda
echo "📦 Deploying registerDevice Lambda..."
cp registerDevice.js index.js
zip -r registerDevice.zip index.js package.json node_modules > /dev/null 2>&1
rm index.js

aws lambda create-function \
    --function-name "websocket-registerDevice${USER_SUFFIX}" \
    --runtime nodejs20.x \
    --role "arn:aws:iam::$(aws sts get-caller-identity --query Account --output text):role/MessageAI-WebSocket-Role${USER_SUFFIX}" \
    --handler index.handler \
    --zip-file fileb://registerDevice.zip \
    --environment Variables="{DEVICES_TABLE=DeviceTokens${USER_SUFFIX}}" \
    --region $AWS_REGION 2>/dev/null || \
aws lambda update-function-code \
    --function-name "websocket-registerDevice${USER_SUFFIX}" \
    --zip-file fileb://registerDevice.zip \
    --region $AWS_REGION > /dev/null

rm registerDevice.zip

# Update registerDevice Lambda configuration
aws lambda update-function-configuration \
    --function-name "websocket-registerDevice${USER_SUFFIX}" \
    --handler index.handler \
    --runtime nodejs20.x \
    --environment Variables="{DEVICES_TABLE=DeviceTokens${USER_SUFFIX}}" \
    --region $AWS_REGION > /dev/null

# Create route for registerDevice
echo "🔗 Creating registerDevice route..."
REGISTER_INTEGRATION_ID=$(aws apigatewayv2 create-integration \
    --api-id $API_ID \
    --integration-type AWS_PROXY \
    --integration-uri "arn:aws:lambda:$AWS_REGION:$(aws sts get-caller-identity --query Account --output text):function:websocket-registerDevice${USER_SUFFIX}" \
    --region $AWS_REGION \
    --query IntegrationId \
    --output text 2>/dev/null || echo "")

if [ -n "$REGISTER_INTEGRATION_ID" ]; then
    aws apigatewayv2 create-route \
        --api-id $API_ID \
        --route-key registerDevice \
        --target "integrations/$REGISTER_INTEGRATION_ID" \
        --region $AWS_REGION > /dev/null 2>&1 || echo "Route already exists"
fi

# Add Lambda permission for API Gateway
aws lambda add-permission \
    --function-name "websocket-registerDevice${USER_SUFFIX}" \
    --statement-id "APIGatewayInvoke-$(date +%s)" \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:$AWS_REGION:$(aws sts get-caller-identity --query Account --output text):$API_ID/*/*" \
    --region $AWS_REGION > /dev/null 2>&1 || true

# Update sendMessage Lambda with SNS permissions
echo "📦 Updating sendMessage Lambda..."
cp sendMessage.js index.js
zip -r sendMessage.zip index.js package.json node_modules > /dev/null 2>&1
rm index.js

aws lambda update-function-code \
    --function-name "websocket-sendMessage${USER_SUFFIX}" \
    --zip-file fileb://sendMessage.zip \
    --region $AWS_REGION > /dev/null

aws lambda update-function-configuration \
    --function-name "websocket-sendMessage${USER_SUFFIX}" \
    --handler index.handler \
    --runtime nodejs20.x \
    --environment Variables="{MESSAGES_TABLE=Messages${USER_SUFFIX},CONNECTIONS_TABLE=Connections${USER_SUFFIX},DEVICES_TABLE=DeviceTokens${USER_SUFFIX}}" \
    --region $AWS_REGION > /dev/null

rm sendMessage.zip

# Deploy API changes
echo "🚀 Deploying API..."
aws apigatewayv2 create-deployment \
    --api-id $API_ID \
    --stage-name production \
    --region $AWS_REGION > /dev/null

echo "✅ Push notification infrastructure deployed!"
echo ""
echo "⚠️  IMPORTANT: To enable push notifications, you need to:"
echo "1. Create an iOS App ID with Push Notification capability in Apple Developer Portal"
echo "2. Create an APNs certificate or key"
echo "3. Create an SNS Platform Application in AWS Console"
echo "4. Set the SNS_PLATFORM_APP_ARN environment variable in sendMessage Lambda"
echo ""
echo "📱 Your WebSocket API endpoint: wss://$API_ID.execute-api.$AWS_REGION.amazonaws.com/production"
