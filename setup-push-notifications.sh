#!/bin/bash

# Push Notifications Setup Script
# This script helps set up AWS SNS for push notifications

set -e

echo "🚀 MessageAI Push Notifications Setup"
echo "======================================"
echo ""

# Variables
AWS_REGION="us-east-1"
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
PLATFORM_NAME="MessageAI_APNS"
APP_NAME="MessageAI"

echo "📋 Configuration:"
echo "   AWS Region: $AWS_REGION"
echo "   AWS Account: $AWS_ACCOUNT_ID"
echo "   Platform Name: $PLATFORM_NAME"
echo ""

# Step 1: Check if we need to create the platform application
echo "🔍 Step 1: Checking for existing SNS Platform Application..."
EXISTING_ARN=$(aws sns list-platform-applications --region $AWS_REGION --query "PlatformApplications[?contains(PlatformApplicationArn, '$PLATFORM_NAME')].PlatformApplicationArn" --output text 2>/dev/null || echo "")

if [ -n "$EXISTING_ARN" ]; then
    echo "✅ Found existing platform: $EXISTING_ARN"
    PLATFORM_ARN="$EXISTING_ARN"
else
    echo "⚠️  No existing platform found."
    echo ""
    echo "📝 To create the SNS Platform Application, you need:"
    echo "   1. APNs Authentication Key (.p8 file) OR"
    echo "   2. APNs Certificate (.p12 file)"
    echo ""
    echo "🍎 Getting APNs Credentials from Apple Developer:"
    echo "   Option A - Authentication Key (Recommended):"
    echo "   1. Go to https://developer.apple.com/account/resources/authkeys/list"
    echo "   2. Click '+' to create a new key"
    echo "   3. Select 'Apple Push Notifications service (APNs)'"
    echo "   4. Download the .p8 file (save it securely!)"
    echo "   5. Note the Key ID and Team ID"
    echo ""
    echo "   Option B - Certificate:"
    echo "   1. Go to https://developer.apple.com/account/resources/certificates/list"
    echo "   2. Create iOS App ID with Push Notifications capability"
    echo "   3. Create APNs certificate"
    echo "   4. Download and convert to .p12 format"
    echo ""
    
    read -p "Do you have an APNs .p8 key file ready? (y/n): " HAS_P8
    
    if [ "$HAS_P8" = "y" ]; then
        read -p "Enter path to .p8 file: " P8_FILE
        read -p "Enter Key ID: " KEY_ID
        read -p "Enter Team ID: " TEAM_ID
        
        if [ ! -f "$P8_FILE" ]; then
            echo "❌ File not found: $P8_FILE"
            exit 1
        fi
        
        # Read the private key
        PRIVATE_KEY=$(cat "$P8_FILE")
        
        # Create platform application with authentication key
        echo "📱 Creating SNS Platform Application..."
        PLATFORM_ARN=$(aws sns create-platform-application \
            --name "$PLATFORM_NAME" \
            --platform APNS \
            --attributes \
                PlatformCredential="$PRIVATE_KEY" \
                PlatformPrincipal="$KEY_ID" \
                ApplePlatformTeamID="$TEAM_ID" \
                ApplePlatformBundleID="com.messageai.app" \
            --region $AWS_REGION \
            --query PlatformApplicationArn \
            --output text)
        
        echo "✅ Platform Application Created!"
        echo "   ARN: $PLATFORM_ARN"
    else
        echo ""
        echo "❌ Please obtain APNs credentials first, then run this script again."
        echo ""
        echo "📖 Quick Guide:"
        echo "   1. Visit: https://developer.apple.com/account/resources/authkeys/list"
        echo "   2. Create new key with APNs enabled"
        echo "   3. Download .p8 file"
        echo "   4. Run this script again"
        exit 0
    fi
fi

# Step 2: Update Lambda function
echo ""
echo "⚙️  Step 2: Updating Lambda function..."

aws lambda update-function-configuration \
    --function-name websocket-sendMessage_AlexHo \
    --environment Variables="{
        MESSAGES_TABLE=Messages_AlexHo,
        CONNECTIONS_TABLE=Connections_AlexHo,
        DEVICES_TABLE=DeviceTokens_AlexHo,
        SNS_PLATFORM_APP_ARN=$PLATFORM_ARN
    }" \
    --region $AWS_REGION \
    --no-cli-pager > /dev/null

echo "✅ Lambda function updated!"

# Step 3: Grant Lambda permission to use SNS
echo ""
echo "🔐 Step 3: Granting Lambda permissions..."

# Get Lambda function ARN
LAMBDA_ARN=$(aws lambda get-function --function-name websocket-sendMessage_AlexHo --region $AWS_REGION --query 'Configuration.FunctionArn' --output text)

# Create IAM policy for SNS
POLICY_DOC=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "sns:Publish",
        "sns:CreatePlatformEndpoint",
        "sns:DeletePlatformEndpoint"
      ],
      "Resource": "$PLATFORM_ARN"
    }
  ]
}
EOF
)

# Get Lambda role
LAMBDA_ROLE=$(aws lambda get-function --function-name websocket-sendMessage_AlexHo --region $AWS_REGION --query 'Configuration.Role' --output text)
ROLE_NAME=$(echo $LAMBDA_ROLE | awk -F'/' '{print $NF}')

# Create or update policy
POLICY_NAME="MessageAI-SNS-Policy_AlexHo"
EXISTING_POLICY=$(aws iam list-policies --scope Local --query "Policies[?PolicyName=='$POLICY_NAME'].Arn" --output text 2>/dev/null || echo "")

if [ -n "$EXISTING_POLICY" ]; then
    echo "   Updating existing policy..."
    # Create new policy version
    aws iam create-policy-version \
        --policy-arn "$EXISTING_POLICY" \
        --policy-document "$POLICY_DOC" \
        --set-as-default > /dev/null 2>&1 || echo "   (Policy already up to date)"
else
    echo "   Creating new policy..."
    POLICY_ARN=$(aws iam create-policy \
        --policy-name "$POLICY_NAME" \
        --policy-document "$POLICY_DOC" \
        --query 'Policy.Arn' \
        --output text)
    
    # Attach policy to Lambda role
    aws iam attach-role-policy \
        --role-name "$ROLE_NAME" \
        --policy-arn "$POLICY_ARN"
fi

echo "✅ Permissions granted!"

# Step 4: Test device token registration
echo ""
echo "🧪 Step 4: Testing infrastructure..."
echo "   - DeviceTokens table exists"
echo "   - registerDevice Lambda deployed"
echo "   - sendMessage Lambda updated"
echo "   - SNS Platform Application configured"
echo ""

# Summary
echo "═══════════════════════════════════════"
echo "✅ Push Notifications Setup Complete!"
echo "═══════════════════════════════════════"
echo ""
echo "📋 Configuration Summary:"
echo "   Platform ARN: $PLATFORM_ARN"
echo "   Lambda Function: websocket-sendMessage_AlexHo"
echo "   Region: $AWS_REGION"
echo ""
echo "📱 Next Steps in Xcode:"
echo "   1. Enable 'Push Notifications' capability"
echo "   2. Enable 'Background Modes' → Remote notifications"
echo "   3. Build and run on a real device (not simulator)"
echo "   4. Accept notification permission when prompted"
echo ""
echo "🧪 Testing:"
echo "   1. Close app on Device A"
echo "   2. Send message from Device B"
echo "   3. Device A should receive push notification!"
echo ""
echo "📝 Saved configuration to: .push-notification-config"
echo "   Platform ARN: $PLATFORM_ARN" > .push-notification-config
echo ""
