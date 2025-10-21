#!/bin/bash

# Create AWS Cognito User Pool for MessageAI
# This script automates the Cognito setup

echo "🚀 Creating MessageAI Cognito User Pool..."

# Create User Pool
USER_POOL_OUTPUT=$(aws cognito-idp create-user-pool \
  --pool-name MessageAI-UserPool \
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

# Extract User Pool ID
USER_POOL_ID=$(echo $USER_POOL_OUTPUT | grep -o '"Id": "[^"]*' | cut -d'"' -f4)

echo "✅ User Pool Created!"
echo "User Pool ID: $USER_POOL_ID"

# Create App Client
APP_CLIENT_OUTPUT=$(aws cognito-idp create-user-pool-client \
  --user-pool-id $USER_POOL_ID \
  --client-name MessageAI-iOS \
  --no-generate-secret \
  --explicit-auth-flows ALLOW_USER_PASSWORD_AUTH ALLOW_REFRESH_TOKEN_AUTH \
  --region us-east-1 \
  --output json)

# Extract App Client ID
APP_CLIENT_ID=$(echo $APP_CLIENT_OUTPUT | grep -o '"ClientId": "[^"]*' | cut -d'"' -f4)

echo "✅ App Client Created!"
echo "App Client ID: $APP_CLIENT_ID"

# Save to config file
cat > cognito-config.txt << EOF
=================================
MessageAI Cognito Configuration
=================================

User Pool ID: $USER_POOL_ID
App Client ID: $APP_CLIENT_ID
Region: us-east-1

Save these values! You'll need them for the iOS app.

=================================
EOF

echo ""
echo "📝 Configuration saved to: cognito-config.txt"
echo ""
cat cognito-config.txt

