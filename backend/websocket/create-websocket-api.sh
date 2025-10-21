#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  MessageAI WebSocket API Setup${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Configuration
REGION="us-east-1"
API_NAME="MessageAI-WebSocket_AlexHo"
CONNECTIONS_TABLE="Connections_AlexHo"
MESSAGES_TABLE="Messages_AlexHo"
LAMBDA_ROLE="MessageAI-WebSocket-Role_AlexHo"

echo -e "${YELLOW}📋 Configuration:${NC}"
echo "   Region: $REGION"
echo "   API Name: $API_NAME"
echo "   Connections Table: $CONNECTIONS_TABLE"
echo "   Messages Table: $MESSAGES_TABLE"
echo ""

# Step 1: Create Connections Table
echo -e "${BLUE}Step 1: Creating Connections DynamoDB Table...${NC}"

aws dynamodb create-table \
    --table-name $CONNECTIONS_TABLE \
    --attribute-definitions \
        AttributeName=connectionId,AttributeType=S \
        AttributeName=userId,AttributeType=S \
    --key-schema \
        AttributeName=connectionId,KeyType=HASH \
    --global-secondary-indexes \
        "[
            {
                \"IndexName\": \"userId-index\",
                \"KeySchema\": [{\"AttributeName\":\"userId\",\"KeyType\":\"HASH\"}],
                \"Projection\":{\"ProjectionType\":\"ALL\"},
                \"ProvisionedThroughput\": {\"ReadCapacityUnits\": 5, \"WriteCapacityUnits\": 5}
            }
        ]" \
    --provisioned-throughput \
        ReadCapacityUnits=5,WriteCapacityUnits=5 \
    --region $REGION 2>/dev/null

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Connections table created${NC}"
else
    echo -e "${YELLOW}⚠️  Connections table may already exist${NC}"
fi

# Wait for table to be active
echo "   Waiting for table to become active..."
aws dynamodb wait table-exists --table-name $CONNECTIONS_TABLE --region $REGION
echo -e "${GREEN}   Table is active${NC}"
echo ""

# Step 2: Enable TTL for automatic cleanup
echo -e "${BLUE}Step 2: Enabling TTL for automatic connection cleanup...${NC}"

aws dynamodb update-time-to-live \
    --table-name $CONNECTIONS_TABLE \
    --time-to-live-specification "Enabled=true, AttributeName=ttl" \
    --region $REGION 2>/dev/null

echo -e "${GREEN}✅ TTL enabled${NC}"
echo ""

# Step 3: Create WebSocket API
echo -e "${BLUE}Step 3: Creating WebSocket API...${NC}"

API_ID=$(aws apigatewayv2 create-api \
    --name $API_NAME \
    --protocol-type WEBSOCKET \
    --route-selection-expression "\$request.body.action" \
    --region $REGION \
    --query 'ApiId' \
    --output text 2>/dev/null)

if [ -z "$API_ID" ]; then
    # API might already exist, try to get it
    API_ID=$(aws apigatewayv2 get-apis \
        --region $REGION \
        --query "Items[?Name=='$API_NAME'].ApiId" \
        --output text)
    
    if [ -z "$API_ID" ]; then
        echo -e "${RED}❌ Failed to create or find API${NC}"
        exit 1
    fi
    echo -e "${YELLOW}⚠️  API already exists${NC}"
fi

echo -e "${GREEN}✅ WebSocket API created/found${NC}"
echo "   API ID: $API_ID"
echo ""

# Save API ID for later use
echo $API_ID > .api-id.txt

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Part 1 Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}📝 What we created:${NC}"
echo "   ✅ Connections DynamoDB table"
echo "   ✅ TTL enabled (auto-cleanup)"
echo "   ✅ WebSocket API Gateway"
echo ""
echo -e "${YELLOW}🔑 Important Info:${NC}"
echo "   API ID: $API_ID"
echo "   Region: $REGION"
echo ""
echo -e "${BLUE}⏭️  Next: Run deploy.sh to deploy Lambda functions${NC}"

