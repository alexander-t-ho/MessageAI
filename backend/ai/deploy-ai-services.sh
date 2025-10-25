#!/bin/bash

# Deploy AI Services for MessageAI
# This script creates the Lambda functions and DynamoDB tables for AI features

REGION="us-east-1"
ACCOUNT_ID="971422717446"
LAMBDA_ROLE="MessageAI-AI-Role_AlexHo"
API_NAME="messageai-api_AlexHo"

echo "🚀 Deploying AI Services for MessageAI..."

# Create DynamoDB table for translation cache
echo "📊 Creating TranslationsCache table..."
aws dynamodb create-table \
  --table-name TranslationsCache_AlexHo \
  --attribute-definitions \
    AttributeName=cacheKey,AttributeType=S \
  --key-schema \
    AttributeName=cacheKey,KeyType=HASH \
  --provisioned-throughput \
    ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region $REGION \
  --no-cli-pager 2>/dev/null || echo "Table may already exist"

# Wait for table to be active
echo "⏳ Waiting for table to be active..."
aws dynamodb wait table-exists --table-name TranslationsCache_AlexHo --region $REGION

# Create IAM role for AI Lambda functions
echo "🔐 Creating IAM role for AI Lambda..."
aws iam create-role \
  --role-name $LAMBDA_ROLE \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "lambda.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }' \
  --region $REGION \
  --no-cli-pager 2>/dev/null || echo "Role may already exist"

# Attach policies to the role
echo "📝 Attaching policies to IAM role..."
aws iam attach-role-policy \
  --role-name $LAMBDA_ROLE \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole \
  --region $REGION \
  --no-cli-pager 2>/dev/null

# Create custom policy for DynamoDB and Secrets Manager access
aws iam put-role-policy \
  --role-name $LAMBDA_ROLE \
  --policy-name MessageAI-AI-Policy \
  --policy-document '{
    "Version": "2012-10-17",
    "Statement": [
      {
        "Effect": "Allow",
        "Action": [
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:Query",
          "dynamodb:Scan"
        ],
        "Resource": [
          "arn:aws:dynamodb:'$REGION':'$ACCOUNT_ID':table/TranslationsCache_AlexHo",
          "arn:aws:dynamodb:'$REGION':'$ACCOUNT_ID':table/TranslationsCache_AlexHo/index/*"
        ]
      },
      {
        "Effect": "Allow",
        "Action": [
          "secretsmanager:GetSecretValue"
        ],
        "Resource": "arn:aws:secretsmanager:'$REGION':'$ACCOUNT_ID':secret:claude-api-key-alexho*"
      }
    ]
  }' \
  --region $REGION \
  --no-cli-pager

# Wait for IAM role to propagate
echo "⏳ Waiting for IAM role to propagate..."
sleep 10

# Install dependencies
echo "📦 Installing dependencies..."
npm install

# Create the translate Lambda function
echo "🔄 Creating translate Lambda function..."
zip -q translate.zip translate.js node_modules

aws lambda create-function \
  --function-name ai-translate_AlexHo \
  --runtime nodejs20.x \
  --role arn:aws:iam::$ACCOUNT_ID:role/$LAMBDA_ROLE \
  --handler translate.handler \
  --zip-file fileb://translate.zip \
  --timeout 30 \
  --memory-size 512 \
  --environment Variables="{
    TRANSLATIONS_CACHE_TABLE=TranslationsCache_AlexHo,
    AWS_REGION=$REGION
  }" \
  --region $REGION \
  --no-cli-pager 2>/dev/null || {
  echo "Function exists, updating code..."
  aws lambda update-function-code \
    --function-name ai-translate_AlexHo \
    --zip-file fileb://translate.zip \
    --region $REGION \
    --no-cli-pager
  
  aws lambda update-function-configuration \
    --function-name ai-translate_AlexHo \
    --timeout 30 \
    --memory-size 512 \
    --environment Variables="{
      TRANSLATIONS_CACHE_TABLE=TranslationsCache_AlexHo,
      AWS_REGION=$REGION
    }" \
    --region $REGION \
    --no-cli-pager
}

rm translate.zip

# Get the API Gateway ID
echo "🌐 Setting up API Gateway integration..."
API_ID=$(aws apigatewayv2 get-apis --region $REGION --no-cli-pager --query "Items[?Name=='$API_NAME'].ApiId" --output text)

if [ -z "$API_ID" ]; then
  echo "❌ API Gateway not found. Please ensure the main API is set up first."
  exit 1
fi

# Create integration for translate Lambda
echo "🔗 Creating API Gateway integration..."
INTEGRATION_ID=$(aws apigatewayv2 create-integration \
  --api-id $API_ID \
  --integration-type AWS_PROXY \
  --integration-uri arn:aws:lambda:$REGION:$ACCOUNT_ID:function:ai-translate_AlexHo \
  --payload-format-version 2.0 \
  --region $REGION \
  --no-cli-pager \
  --query IntegrationId \
  --output text 2>/dev/null) || {
  echo "Integration may already exist"
  INTEGRATION_ID=$(aws apigatewayv2 get-integrations --api-id $API_ID --region $REGION --no-cli-pager --query "Items[?IntegrationUri=='arn:aws:lambda:$REGION:$ACCOUNT_ID:function:ai-translate_AlexHo'].IntegrationId" --output text)
}

# Create route for translate endpoint
echo "🛣️ Creating API route..."
aws apigatewayv2 create-route \
  --api-id $API_ID \
  --route-key "POST /translate" \
  --target integrations/$INTEGRATION_ID \
  --authorization-type JWT \
  --authorizer-id $(aws apigatewayv2 get-authorizers --api-id $API_ID --region $REGION --no-cli-pager --query "Items[0].AuthorizerId" --output text) \
  --region $REGION \
  --no-cli-pager 2>/dev/null || echo "Route may already exist"

# Grant API Gateway permission to invoke Lambda
aws lambda add-permission \
  --function-name ai-translate_AlexHo \
  --statement-id apigateway-invoke \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:$REGION:$ACCOUNT_ID:$API_ID/*/*" \
  --region $REGION \
  --no-cli-pager 2>/dev/null || echo "Permission may already exist"

echo "✅ AI Services deployment complete!"
echo ""
echo "📝 Next steps:"
echo "1. Create the Claude API key secret in AWS Secrets Manager:"
echo "   aws secretsmanager create-secret --name claude-api-key-alexho --secret-string '{\"apiKey\":\"YOUR_CLAUDE_API_KEY\"}'"
echo ""
echo "2. API Endpoint: https://$API_ID.execute-api.$REGION.amazonaws.com/translate"
echo ""
echo "3. Update the iOS app with the new endpoint"
