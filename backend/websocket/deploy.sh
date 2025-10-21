#!/bin/bash

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Deploy WebSocket Lambda Functions${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Configuration
REGION="us-east-1"
CONNECTIONS_TABLE="Connections_AlexHo"
MESSAGES_TABLE="Messages_AlexHo"
LAMBDA_ROLE_NAME="MessageAI-WebSocket-Role_AlexHo"

# Check if API ID exists
if [ ! -f .api-id.txt ]; then
    echo -e "${RED}❌ API ID not found. Run create-websocket-api.sh first!${NC}"
    exit 1
fi

API_ID=$(cat .api-id.txt)
echo -e "${YELLOW}📡 Using API ID: $API_ID${NC}"
echo ""

# Get AWS Account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
echo -e "${YELLOW}👤 AWS Account ID: $ACCOUNT_ID${NC}"
echo ""

# Step 1: Create IAM Role for Lambda
echo -e "${BLUE}Step 1: Creating IAM Role for Lambda functions...${NC}"

# Create trust policy
cat > /tmp/lambda-trust-policy.json << EOF
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

# Create role
aws iam create-role \
    --role-name $LAMBDA_ROLE_NAME \
    --assume-role-policy-document file:///tmp/lambda-trust-policy.json \
    2>/dev/null

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ IAM Role created${NC}"
else
    echo -e "${YELLOW}⚠️  IAM Role may already exist${NC}"
fi

# Create inline policy for DynamoDB and API Gateway
cat > /tmp/lambda-policy.json << EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "dynamodb:PutItem",
        "dynamodb:GetItem",
        "dynamodb:DeleteItem",
        "dynamodb:Query",
        "dynamodb:Scan"
      ],
      "Resource": [
        "arn:aws:dynamodb:${REGION}:${ACCOUNT_ID}:table/${CONNECTIONS_TABLE}",
        "arn:aws:dynamodb:${REGION}:${ACCOUNT_ID}:table/${CONNECTIONS_TABLE}/index/*",
        "arn:aws:dynamodb:${REGION}:${ACCOUNT_ID}:table/${MESSAGES_TABLE}"
      ]
    },
    {
      "Effect": "Allow",
      "Action": [
        "execute-api:ManageConnections",
        "execute-api:Invoke"
      ],
      "Resource": "arn:aws:execute-api:${REGION}:${ACCOUNT_ID}:${API_ID}/*"
    }
  ]
}
EOF

aws iam put-role-policy \
    --role-name $LAMBDA_ROLE_NAME \
    --policy-name WebSocketLambdaPolicy \
    --policy-document file:///tmp/lambda-policy.json

echo -e "${GREEN}✅ IAM Policy attached${NC}"
echo ""

# Wait for role to propagate
echo "   Waiting for IAM role to propagate..."
sleep 10
echo ""

LAMBDA_ROLE_ARN="arn:aws:iam::${ACCOUNT_ID}:role/${LAMBDA_ROLE_NAME}"

# Step 2: Install dependencies
echo -e "${BLUE}Step 2: Installing Node.js dependencies...${NC}"

npm install --omit=dev

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Dependencies installed${NC}"
else
    echo -e "${RED}❌ Failed to install dependencies${NC}"
    exit 1
fi
echo ""

# Step 3: Package and deploy Lambda functions
echo -e "${BLUE}Step 3: Packaging and deploying Lambda functions...${NC}"
echo ""

# Function to create Lambda
create_lambda() {
    local FUNCTION_NAME=$1
    local HANDLER_FILE=$2
    local DESCRIPTION=$3
    
    echo -e "${YELLOW}📦 Creating Lambda: $FUNCTION_NAME${NC}"
    
    # Create zip file
    zip -q -r /tmp/${FUNCTION_NAME}.zip ${HANDLER_FILE} node_modules/
    
    # Create or update Lambda function
    aws lambda create-function \
        --function-name $FUNCTION_NAME \
        --runtime nodejs18.x \
        --role $LAMBDA_ROLE_ARN \
        --handler ${HANDLER_FILE%.js}.handler \
        --zip-file fileb:///tmp/${FUNCTION_NAME}.zip \
        --description "$DESCRIPTION" \
        --timeout 30 \
        --memory-size 256 \
        --environment "Variables={CONNECTIONS_TABLE=${CONNECTIONS_TABLE},MESSAGES_TABLE=${MESSAGES_TABLE},AWS_REGION=${REGION}}" \
        --region $REGION \
        2>/dev/null
    
    if [ $? -ne 0 ]; then
        # Function exists, update it
        echo -e "${YELLOW}   Updating existing function...${NC}"
        aws lambda update-function-code \
            --function-name $FUNCTION_NAME \
            --zip-file fileb:///tmp/${FUNCTION_NAME}.zip \
            --region $REGION > /dev/null
        
        aws lambda update-function-configuration \
            --function-name $FUNCTION_NAME \
            --environment "Variables={CONNECTIONS_TABLE=${CONNECTIONS_TABLE},MESSAGES_TABLE=${MESSAGES_TABLE},AWS_REGION=${REGION}}" \
            --region $REGION > /dev/null
    fi
    
    echo -e "${GREEN}   ✅ $FUNCTION_NAME deployed${NC}"
    echo ""
}

# Deploy Lambda functions
create_lambda "websocket-connect_AlexHo" "connect.js" "Handle WebSocket connections"
create_lambda "websocket-disconnect_AlexHo" "disconnect.js" "Handle WebSocket disconnections"
create_lambda "websocket-sendMessage_AlexHo" "sendMessage.js" "Handle sending messages"

# Step 4: Create API Gateway routes and integrations
echo -e "${BLUE}Step 4: Creating API Gateway routes...${NC}"
echo ""

# Function to create route and integration
create_route() {
    local ROUTE_KEY=$1
    local LAMBDA_NAME=$2
    local ROUTE_NAME=$3
    
    echo -e "${YELLOW}🔗 Creating route: $ROUTE_KEY${NC}"
    
    LAMBDA_ARN="arn:aws:lambda:${REGION}:${ACCOUNT_ID}:function/${LAMBDA_NAME}"
    
    # Create integration
    INTEGRATION_ID=$(aws apigatewayv2 create-integration \
        --api-id $API_ID \
        --integration-type AWS_PROXY \
        --integration-uri $LAMBDA_ARN \
        --region $REGION \
        --query 'IntegrationId' \
        --output text 2>/dev/null)
    
    if [ -z "$INTEGRATION_ID" ]; then
        echo -e "${YELLOW}   ⚠️  Integration may already exist, getting existing...${NC}"
        INTEGRATION_ID=$(aws apigatewayv2 get-integrations \
            --api-id $API_ID \
            --region $REGION \
            --query "Items[?contains(IntegrationUri, '${LAMBDA_NAME}')].IntegrationId" \
            --output text | head -n1)
    fi
    
    echo "   Integration ID: $INTEGRATION_ID"
    
    # Create route
    ROUTE_ID=$(aws apigatewayv2 create-route \
        --api-id $API_ID \
        --route-key "$ROUTE_KEY" \
        --target "integrations/${INTEGRATION_ID}" \
        --region $REGION \
        --query 'RouteId' \
        --output text 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        echo -e "${YELLOW}   ⚠️  Route may already exist${NC}"
    fi
    
    # Grant API Gateway permission to invoke Lambda
    aws lambda add-permission \
        --function-name $LAMBDA_NAME \
        --statement-id "apigateway-${ROUTE_NAME}-${API_ID}" \
        --action lambda:InvokeFunction \
        --principal apigateway.amazonaws.com \
        --source-arn "arn:aws:execute-api:${REGION}:${ACCOUNT_ID}:${API_ID}/*" \
        --region $REGION \
        2>/dev/null
    
    echo -e "${GREEN}   ✅ Route created and permissions granted${NC}"
    echo ""
}

# Create routes
create_route "\$connect" "websocket-connect_AlexHo" "connect"
create_route "\$disconnect" "websocket-disconnect_AlexHo" "disconnect"
create_route "sendMessage" "websocket-sendMessage_AlexHo" "sendMessage"

# Step 5: Deploy API
echo -e "${BLUE}Step 5: Deploying API...${NC}"

STAGE_NAME="production"

# Create or update stage
aws apigatewayv2 create-stage \
    --api-id $API_ID \
    --stage-name $STAGE_NAME \
    --description "Production stage" \
    --region $REGION \
    2>/dev/null

if [ $? -ne 0 ]; then
    echo -e "${YELLOW}⚠️  Stage may already exist${NC}"
fi

# Create deployment
DEPLOYMENT_ID=$(aws apigatewayv2 create-deployment \
    --api-id $API_ID \
    --stage-name $STAGE_NAME \
    --region $REGION \
    --query 'DeploymentId' \
    --output text)

echo -e "${GREEN}✅ API deployed${NC}"
echo "   Deployment ID: $DEPLOYMENT_ID"
echo ""

# Get WebSocket URL
WEBSOCKET_URL="wss://${API_ID}.execute-api.${REGION}.amazonaws.com/${STAGE_NAME}"

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  🎉 Deployment Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${YELLOW}📡 WebSocket URL:${NC}"
echo "   $WEBSOCKET_URL"
echo ""
echo -e "${YELLOW}🔧 Lambda Functions:${NC}"
echo "   ✅ websocket-connect_AlexHo"
echo "   ✅ websocket-disconnect_AlexHo"
echo "   ✅ websocket-sendMessage_AlexHo"
echo ""
echo -e "${YELLOW}📊 DynamoDB Tables:${NC}"
echo "   ✅ $CONNECTIONS_TABLE"
echo "   ✅ $MESSAGES_TABLE (existing)"
echo ""
echo -e "${YELLOW}🔗 API Gateway:${NC}"
echo "   API ID: $API_ID"
echo "   Stage: $STAGE_NAME"
echo "   Routes: \$connect, \$disconnect, sendMessage"
echo ""

# Save WebSocket URL to Config.swift location
cat > ../../websocket-url.txt << EOF
$WEBSOCKET_URL
EOF

echo -e "${BLUE}💾 WebSocket URL saved to: websocket-url.txt${NC}"
echo ""
echo -e "${YELLOW}⏭️  Next Steps:${NC}"
echo "   1. Update iOS app with WebSocket URL"
echo "   2. Implement WebSocketService.swift"
echo "   3. Test connection from iOS app"
echo ""
echo -e "${GREEN}🚀 Ready to build real-time messaging!${NC}"

