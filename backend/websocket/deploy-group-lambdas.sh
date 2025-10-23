#!/bin/bash

# Deploy Group Chat Lambda Functions
# This script deploys the group-related WebSocket Lambda functions

set -e

REGION="us-east-1"
API_ID="bnbr75tld0"  # Your API Gateway WebSocket API ID

echo "📦 Deploying Group Chat Lambda Functions..."
echo ""

# 1. Deploy groupCreated Lambda
echo "1️⃣ Deploying groupCreated Lambda..."
cd /Users/alexho/MessageAI/backend/websocket
zip -r groupCreated.zip groupCreated.js package.json node_modules/ > /dev/null 2>&1

aws lambda update-function-code \
    --function-name websocket-groupCreated_AlexHo \
    --zip-file fileb://groupCreated.zip \
    --region $REGION \
    --no-cli-pager || echo "⚠️ Lambda doesn't exist, creating..."

if [ $? -ne 0 ]; then
    aws lambda create-function \
        --function-name websocket-groupCreated_AlexHo \
        --runtime nodejs20.x \
        --role arn:aws:iam::590183761174:role/websocket-lambda-role_AlexHo \
        --handler groupCreated.handler \
        --zip-file fileb://groupCreated.zip \
        --region $REGION \
        --timeout 30 \
        --environment "Variables={CONNECTIONS_TABLE=Connections_AlexHo,CONVERSATIONS_TABLE=Conversations_AlexHo}" \
        --no-cli-pager
fi

rm groupCreated.zip
echo "✅ groupCreated Lambda deployed"
echo ""

# 2. Deploy groupUpdate Lambda
echo "2️⃣ Deploying groupUpdate Lambda..."
zip -r groupUpdate.zip groupUpdate.js package.json node_modules/ > /dev/null 2>&1

aws lambda update-function-code \
    --function-name websocket-groupUpdate_AlexHo \
    --zip-file fileb://groupUpdate.zip \
    --region $REGION \
    --no-cli-pager || echo "⚠️ Lambda doesn't exist, creating..."

if [ $? -ne 0 ]; then
    aws lambda create-function \
        --function-name websocket-groupUpdate_AlexHo \
        --runtime nodejs20.x \
        --role arn:aws:iam::590183761174:role/websocket-lambda-role_AlexHo \
        --handler groupUpdate.handler \
        --zip-file fileb://groupUpdate.zip \
        --region $REGION \
        --timeout 30 \
        --environment "Variables={CONNECTIONS_TABLE=Connections_AlexHo,CONVERSATIONS_TABLE=Conversations_AlexHo}" \
        --no-cli-pager
fi

rm groupUpdate.zip
echo "✅ groupUpdate Lambda deployed"
echo ""

# 3. Create API Gateway Routes
echo "3️⃣ Creating API Gateway Routes..."

# groupCreated route
aws apigatewayv2 create-route \
    --api-id $API_ID \
    --route-key "groupCreated" \
    --target "integrations/$(aws apigatewayv2 create-integration \
        --api-id $API_ID \
        --integration-type AWS_PROXY \
        --integration-uri "arn:aws:apigateway:$REGION:lambda:path/2015-03-31/functions/arn:aws:lambda:$REGION:590183761174:function:websocket-groupCreated_AlexHo/invocations" \
        --query 'IntegrationId' \
        --output text)" \
    --region $REGION \
    --no-cli-pager 2>/dev/null || echo "⚠️ groupCreated route already exists"

# groupUpdate route
aws apigatewayv2 create-route \
    --api-id $API_ID \
    --route-key "groupUpdate" \
    --target "integrations/$(aws apigatewayv2 create-integration \
        --api-id $API_ID \
        --integration-type AWS_PROXY \
        --integration-uri "arn:aws:apigateway:$REGION:lambda:path/2015-03-31/functions/arn:aws:lambda:$REGION:590183761174:function:websocket-groupUpdate_AlexHo/invocations" \
        --query 'IntegrationId' \
        --output text)" \
    --region $REGION \
    --no-cli-pager 2>/dev/null || echo "⚠️ groupUpdate route already exists"

echo "✅ API Gateway routes created"
echo ""

# 4. Grant API Gateway permission to invoke Lambda
echo "4️⃣ Granting API Gateway permissions..."

aws lambda add-permission \
    --function-name websocket-groupCreated_AlexHo \
    --statement-id apigateway-invoke-groupCreated \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:$REGION:590183761174:$API_ID/*" \
    --region $REGION \
    --no-cli-pager 2>/dev/null || echo "⚠️ Permission already exists"

aws lambda add-permission \
    --function-name websocket-groupUpdate_AlexHo \
    --statement-id apigateway-invoke-groupUpdate \
    --action lambda:InvokeFunction \
    --principal apigateway.amazonaws.com \
    --source-arn "arn:aws:execute-api:$REGION:590183761174:$API_ID/*" \
    --region $REGION \
    --no-cli-pager 2>/dev/null || echo "⚠️ Permission already exists"

echo "✅ Permissions granted"
echo ""

# 5. Deploy API Gateway
echo "5️⃣ Deploying API Gateway..."
aws apigatewayv2 create-deployment \
    --api-id $API_ID \
    --stage-name production \
    --region $REGION \
    --no-cli-pager

echo "✅ API Gateway deployed"
echo ""
echo "🎉 Group Chat Lambda Functions Deployment Complete!"
echo ""
echo "Available routes:"
echo "  - groupCreated"
echo "  - groupUpdate"

