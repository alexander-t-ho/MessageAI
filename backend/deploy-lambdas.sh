#!/bin/bash

# Deploy Lambda Functions and API Gateway for MessageAI
# All resources will have "_AlexHo" suffix

echo "🚀 Deploying MessageAI Lambda Functions and API Gateway..."
echo ""

# Load configuration
USER_POOL_ID="us-east-1_aJN47Jgfy"
APP_CLIENT_ID="55d6h6f4he7j72082d086red5b"
USERS_TABLE="MessageAI-Users_AlexHo"
REGION="us-east-1"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

echo "Account ID: $AWS_ACCOUNT_ID"
echo "Region: $REGION"
echo ""

# ========================================
# Step 1: Create IAM Role for Lambda
# ========================================
echo "📝 Step 1: Creating IAM Role for Lambda functions..."

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
  --role-name MessageAI-Lambda-Role_AlexHo \
  --assume-role-policy-document file:///tmp/lambda-trust-policy.json \
  --output json > /dev/null 2>&1

# Attach policies
aws iam attach-role-policy \
  --role-name MessageAI-Lambda-Role_AlexHo \
  --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

aws iam attach-role-policy \
  --role-name MessageAI-Lambda-Role_AlexHo \
  --policy-arn arn:aws:iam::aws:policy/AmazonCognitoPowerUser

aws iam attach-role-policy \
  --role-name MessageAI-Lambda-Role_AlexHo \
  --policy-arn arn:aws:iam::aws:policy/AmazonDynamoDBFullAccess

echo "✅ IAM Role created: MessageAI-Lambda-Role_AlexHo"
echo "⏳ Waiting 10 seconds for role to propagate..."
sleep 10
echo ""

LAMBDA_ROLE_ARN="arn:aws:iam::${AWS_ACCOUNT_ID}:role/MessageAI-Lambda-Role_AlexHo"

# ========================================
# Step 2: Package and Deploy Lambda Functions
# ========================================
echo "📝 Step 2: Packaging Lambda functions..."

cd auth

# Create deployment packages
mkdir -p /tmp/lambda-packages

# Signup Lambda
cp signup.js /tmp/lambda-packages/
cd /tmp/lambda-packages
zip -q signup.zip signup.js
cd - > /dev/null

# Login Lambda  
cp login.js /tmp/lambda-packages/
cd /tmp/lambda-packages
zip -q login.zip login.js
cd - > /dev/null

cd ..

echo "✅ Lambda functions packaged"
echo ""

# Deploy Signup Lambda
echo "📤 Deploying signup-lambda..."
aws lambda create-function \
  --function-name messageai-signup_AlexHo \
  --runtime nodejs18.x \
  --role $LAMBDA_ROLE_ARN \
  --handler signup.handler \
  --zip-file fileb:///tmp/lambda-packages/signup.zip \
  --timeout 30 \
  --memory-size 256 \
  --environment "Variables={USER_POOL_ID=$USER_POOL_ID,APP_CLIENT_ID=$APP_CLIENT_ID,USERS_TABLE=$USERS_TABLE}" \
  --region $REGION \
  --output json > /dev/null 2>&1

echo "✅ signup-lambda deployed"

# Deploy Login Lambda
echo "📤 Deploying login-lambda..."
aws lambda create-function \
  --function-name messageai-login_AlexHo \
  --runtime nodejs18.x \
  --role $LAMBDA_ROLE_ARN \
  --handler login.handler \
  --zip-file fileb:///tmp/lambda-packages/login.zip \
  --timeout 30 \
  --memory-size 256 \
  --environment "Variables={APP_CLIENT_ID=$APP_CLIENT_ID,USERS_TABLE=$USERS_TABLE}" \
  --region $REGION \
  --output json > /dev/null 2>&1

echo "✅ login-lambda deployed"
echo ""

# ========================================
# Step 3: Create API Gateway
# ========================================
echo "📝 Step 3: Creating API Gateway..."

# Create REST API
API_OUTPUT=$(aws apigateway create-rest-api \
  --name MessageAI-API_AlexHo \
  --description "MessageAI Authentication API" \
  --region $REGION \
  --output json)

API_ID=$(echo $API_OUTPUT | grep -o '"id": "[^"]*' | cut -d'"' -f4)

echo "✅ API Gateway created: $API_ID"

# Get root resource ID
ROOT_RESOURCE_ID=$(aws apigateway get-resources \
  --rest-api-id $API_ID \
  --region $REGION \
  --query 'items[0].id' \
  --output text)

# Create /auth resource
AUTH_RESOURCE=$(aws apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id $ROOT_RESOURCE_ID \
  --path-part auth \
  --region $REGION \
  --output json)

AUTH_RESOURCE_ID=$(echo $AUTH_RESOURCE | grep -o '"id": "[^"]*' | cut -d'"' -f4)

# Create /auth/signup resource
SIGNUP_RESOURCE=$(aws apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id $AUTH_RESOURCE_ID \
  --path-part signup \
  --region $REGION \
  --output json)

SIGNUP_RESOURCE_ID=$(echo $SIGNUP_RESOURCE | grep -o '"id": "[^"]*' | cut -d'"' -f4)

# Create /auth/login resource
LOGIN_RESOURCE=$(aws apigateway create-resource \
  --rest-api-id $API_ID \
  --parent-id $AUTH_RESOURCE_ID \
  --path-part login \
  --region $REGION \
  --output json)

LOGIN_RESOURCE_ID=$(echo $LOGIN_RESOURCE | grep -o '"id": "[^"]*' | cut -d'"' -f4)

echo "✅ API resources created"

# Create POST method for /auth/signup
aws apigateway put-method \
  --rest-api-id $API_ID \
  --resource-id $SIGNUP_RESOURCE_ID \
  --http-method POST \
  --authorization-type NONE \
  --region $REGION \
  --output json > /dev/null

# Integrate signup Lambda
aws apigateway put-integration \
  --rest-api-id $API_ID \
  --resource-id $SIGNUP_RESOURCE_ID \
  --http-method POST \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri "arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/arn:aws:lambda:${REGION}:${AWS_ACCOUNT_ID}:function:messageai-signup_AlexHo/invocations" \
  --region $REGION \
  --output json > /dev/null

# Add Lambda permission for signup
aws lambda add-permission \
  --function-name messageai-signup_AlexHo \
  --statement-id apigateway-signup \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:${REGION}:${AWS_ACCOUNT_ID}:${API_ID}/*/POST/auth/signup" \
  --region $REGION \
  --output json > /dev/null 2>&1

# Create POST method for /auth/login
aws apigateway put-method \
  --rest-api-id $API_ID \
  --resource-id $LOGIN_RESOURCE_ID \
  --http-method POST \
  --authorization-type NONE \
  --region $REGION \
  --output json > /dev/null

# Integrate login Lambda
aws apigateway put-integration \
  --rest-api-id $API_ID \
  --resource-id $LOGIN_RESOURCE_ID \
  --http-method POST \
  --type AWS_PROXY \
  --integration-http-method POST \
  --uri "arn:aws:apigateway:${REGION}:lambda:path/2015-03-31/functions/arn:aws:lambda:${REGION}:${AWS_ACCOUNT_ID}:function:messageai-login_AlexHo/invocations" \
  --region $REGION \
  --output json > /dev/null

# Add Lambda permission for login
aws lambda add-permission \
  --function-name messageai-login_AlexHo \
  --statement-id apigateway-login \
  --action lambda:InvokeFunction \
  --principal apigateway.amazonaws.com \
  --source-arn "arn:aws:execute-api:${REGION}:${AWS_ACCOUNT_ID}:${API_ID}/*/POST/auth/login" \
  --region $REGION \
  --output json > /dev/null 2>&1

echo "✅ Lambda integrations configured"

# Enable CORS
for RESOURCE_ID in $SIGNUP_RESOURCE_ID $LOGIN_RESOURCE_ID; do
  aws apigateway put-method \
    --rest-api-id $API_ID \
    --resource-id $RESOURCE_ID \
    --http-method OPTIONS \
    --authorization-type NONE \
    --region $REGION \
    --output json > /dev/null
  
  aws apigateway put-integration \
    --rest-api-id $API_ID \
    --resource-id $RESOURCE_ID \
    --http-method OPTIONS \
    --type MOCK \
    --request-templates '{"application/json":"{\"statusCode\": 200}"}' \
    --region $REGION \
    --output json > /dev/null
  
  aws apigateway put-method-response \
    --rest-api-id $API_ID \
    --resource-id $RESOURCE_ID \
    --http-method OPTIONS \
    --status-code 200 \
    --response-parameters '{"method.response.header.Access-Control-Allow-Headers":false,"method.response.header.Access-Control-Allow-Methods":false,"method.response.header.Access-Control-Allow-Origin":false}' \
    --region $REGION \
    --output json > /dev/null
  
  aws apigateway put-integration-response \
    --rest-api-id $API_ID \
    --resource-id $RESOURCE_ID \
    --http-method OPTIONS \
    --status-code 200 \
    --response-parameters '{"method.response.header.Access-Control-Allow-Headers":"'"'"'Content-Type,Authorization'"'"'","method.response.header.Access-Control-Allow-Methods":"'"'"'POST,OPTIONS'"'"'","method.response.header.Access-Control-Allow-Origin":"'"'"'*'"'"'"}' \
    --region $REGION \
    --output json > /dev/null
done

echo "✅ CORS enabled"

# Deploy API
aws apigateway create-deployment \
  --rest-api-id $API_ID \
  --stage-name prod \
  --stage-description "Production stage" \
  --description "Initial deployment" \
  --region $REGION \
  --output json > /dev/null

echo "✅ API deployed to 'prod' stage"
echo ""

API_URL="https://${API_ID}.execute-api.${REGION}.amazonaws.com/prod"

# ========================================
# Save Complete Configuration
# ========================================
cat > messageai-complete-config_AlexHo.txt << EOF
===========================================
MessageAI Complete Configuration - AlexHo
===========================================

COGNITO:
--------
User Pool ID: $USER_POOL_ID
App Client ID: $APP_CLIENT_ID
Region: $REGION

DYNAMODB:
---------
Users Table: $USERS_TABLE
Conversations Table: MessageAI-Conversations_AlexHo
Messages Table: MessageAI-Messages_AlexHo

LAMBDA FUNCTIONS:
-----------------
Signup: messageai-signup_AlexHo
Login: messageai-login_AlexHo

API GATEWAY:
------------
API ID: $API_ID
Base URL: $API_URL

API ENDPOINTS:
--------------
Signup: POST $API_URL/auth/signup
Login:  POST $API_URL/auth/login

USAGE EXAMPLES:
---------------

# Signup
curl -X POST $API_URL/auth/signup \\
  -H "Content-Type: application/json" \\
  -d '{"email":"test@example.com","password":"Test123!","name":"Test User"}'

# Login
curl -X POST $API_URL/auth/login \\
  -H "Content-Type: application/json" \\
  -d '{"email":"test@example.com","password":"Test123!"}'

iOS APP CONFIGURATION:
----------------------
Add this to your NetworkService.swift:

let baseURL = "$API_URL"
let userPoolId = "$USER_POOL_ID"
let appClientId = "$APP_CLIENT_ID"

===========================================
EOF

echo "✅ Complete! All backend infrastructure deployed!"
echo ""
echo "📝 Configuration saved to: messageai-complete-config_AlexHo.txt"
echo ""
echo "🌐 API Base URL: $API_URL"
echo ""
echo "📋 Next Steps:"
echo "  1. Test API endpoints (use curl commands in config file)"
echo "  2. Build iOS authentication screens"
echo "  3. Connect iOS app to API"
echo ""
cat messageai-complete-config_AlexHo.txt

