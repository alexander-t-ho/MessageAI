#!/bin/bash

# Create AWS Backend Resources for MessageAI
# All resources will have "_AlexHo" suffix for shared AWS account

echo "🚀 Creating MessageAI Backend Resources with _AlexHo suffix..."
echo ""

# ========================================
# Step 1: Create Cognito User Pool
# ========================================
echo "📝 Step 1: Creating Cognito User Pool..."

USER_POOL_OUTPUT=$(aws cognito-idp create-user-pool \
  --pool-name MessageAI-UserPool_AlexHo \
  --policies '{
    "PasswordPolicy": {
      "MinimumLength": 8,
      "RequireUppercase": true,
      "RequireLowercase": true,
      "RequireNumbers": true,
      "RequireSymbols": true
    }
  }' \
  --auto-verified-attributes email \
  --username-attributes email \
  --schema '[
    {
      "Name": "email",
      "AttributeDataType": "String",
      "Required": true,
      "Mutable": true
    },
    {
      "Name": "name",
      "AttributeDataType": "String",
      "Required": true,
      "Mutable": true
    }
  ]' \
  --verification-message-template '{
    "DefaultEmailOption": "CONFIRM_WITH_CODE"
  }' \
  --region us-east-1 \
  --output json)

USER_POOL_ID=$(echo $USER_POOL_OUTPUT | grep -o '"Id": "[^"]*' | cut -d'"' -f4)

echo "✅ Cognito User Pool Created!"
echo "   Name: MessageAI-UserPool_AlexHo"
echo "   ID: $USER_POOL_ID"
echo ""

# Create App Client
APP_CLIENT_OUTPUT=$(aws cognito-idp create-user-pool-client \
  --user-pool-id $USER_POOL_ID \
  --client-name MessageAI-iOS_AlexHo \
  --no-generate-secret \
  --explicit-auth-flows ALLOW_USER_PASSWORD_AUTH ALLOW_REFRESH_TOKEN_AUTH \
  --region us-east-1 \
  --output json)

APP_CLIENT_ID=$(echo $APP_CLIENT_OUTPUT | grep -o '"ClientId": "[^"]*' | cut -d'"' -f4)

echo "✅ Cognito App Client Created!"
echo "   Name: MessageAI-iOS_AlexHo"
echo "   ID: $APP_CLIENT_ID"
echo ""

# ========================================
# Step 2: Create DynamoDB Tables
# ========================================
echo "📝 Step 2: Creating DynamoDB Tables..."

# Users Table
aws dynamodb create-table \
  --table-name MessageAI-Users_AlexHo \
  --attribute-definitions \
    AttributeName=userId,AttributeType=S \
    AttributeName=email,AttributeType=S \
  --key-schema \
    AttributeName=userId,KeyType=HASH \
  --global-secondary-indexes \
    "[{
      \"IndexName\": \"email-index\",
      \"KeySchema\": [{\"AttributeName\":\"email\",\"KeyType\":\"HASH\"}],
      \"Projection\": {\"ProjectionType\":\"ALL\"},
      \"ProvisionedThroughput\": {\"ReadCapacityUnits\":5,\"WriteCapacityUnits\":5}
    }]" \
  --provisioned-throughput \
    ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region us-east-1 \
  --output json > /dev/null 2>&1

echo "✅ DynamoDB Users Table Created!"
echo "   Name: MessageAI-Users_AlexHo"
echo ""

# Conversations Table (for future phases)
aws dynamodb create-table \
  --table-name MessageAI-Conversations_AlexHo \
  --attribute-definitions \
    AttributeName=conversationId,AttributeType=S \
  --key-schema \
    AttributeName=conversationId,KeyType=HASH \
  --provisioned-throughput \
    ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region us-east-1 \
  --output json > /dev/null 2>&1

echo "✅ DynamoDB Conversations Table Created!"
echo "   Name: MessageAI-Conversations_AlexHo"
echo ""

# Messages Table (for future phases)
aws dynamodb create-table \
  --table-name MessageAI-Messages_AlexHo \
  --attribute-definitions \
    AttributeName=conversationId,AttributeType=S \
    AttributeName=timestamp,AttributeType=N \
    AttributeName=messageId,AttributeType=S \
  --key-schema \
    AttributeName=conversationId,KeyType=HASH \
    AttributeName=timestamp,KeyType=RANGE \
  --global-secondary-indexes \
    "[{
      \"IndexName\": \"messageId-index\",
      \"KeySchema\": [{\"AttributeName\":\"messageId\",\"KeyType\":\"HASH\"}],
      \"Projection\": {\"ProjectionType\":\"ALL\"},
      \"ProvisionedThroughput\": {\"ReadCapacityUnits\":5,\"WriteCapacityUnits\":5}
    }]" \
  --provisioned-throughput \
    ReadCapacityUnits=5,WriteCapacityUnits=5 \
  --region us-east-1 \
  --output json > /dev/null 2>&1

echo "✅ DynamoDB Messages Table Created!"
echo "   Name: MessageAI-Messages_AlexHo"
echo ""

# Wait for tables to become active
echo "⏳ Waiting for tables to become active (30 seconds)..."
sleep 30

# ========================================
# Save Configuration
# ========================================
cat > messageai-config_AlexHo.txt << EOF
===========================================
MessageAI Backend Configuration - AlexHo
===========================================

COGNITO:
--------
User Pool ID: $USER_POOL_ID
App Client ID: $APP_CLIENT_ID
User Pool Name: MessageAI-UserPool_AlexHo
Region: us-east-1

DYNAMODB TABLES:
----------------
Users Table: MessageAI-Users_AlexHo
Conversations Table: MessageAI-Conversations_AlexHo
Messages Table: MessageAI-Messages_AlexHo

NOTES:
------
- All resources have "_AlexHo" suffix
- User Pool configured for email authentication
- Password requires: 8+ chars, uppercase, lowercase, number, symbol
- Required attributes: email, name

NEXT STEPS:
-----------
1. Create Lambda functions
2. Set up API Gateway
3. Build iOS authentication screens

===========================================
EOF

echo ""
echo "✅ All Backend Resources Created Successfully!"
echo ""
echo "📝 Configuration saved to: messageai-config_AlexHo.txt"
echo ""
cat messageai-config_AlexHo.txt

