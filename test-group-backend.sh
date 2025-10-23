#!/bin/bash

# Test Group Chat Backend Setup
set -e

API_ID="bnbr75tld0"
REGION="us-east-1"

echo "🔍 Testing Group Chat Backend Setup..."
echo ""

echo "1️⃣ Checking Lambda functions..."
aws lambda get-function --function-name websocket-groupCreated_AlexHo --region $REGION --query 'Configuration.FunctionName' --output text 2>/dev/null && echo "   ✅ websocket-groupCreated_AlexHo exists" || echo "   ❌ websocket-groupCreated_AlexHo MISSING"
aws lambda get-function --function-name websocket-groupUpdate_AlexHo --region $REGION --query 'Configuration.FunctionName' --output text 2>/dev/null && echo "   ✅ websocket-groupUpdate_AlexHo exists" || echo "   ❌ websocket-groupUpdate_AlexHo MISSING"
echo ""

echo "2️⃣ Checking API Gateway Routes..."
aws apigatewayv2 get-routes --api-id $API_ID --region $REGION --no-cli-pager | grep -o '"RouteKey": "[^"]*"' | grep -E "(groupCreated|groupUpdate)" && echo "   ✅ Routes configured" || echo "   ❌ Routes MISSING"
echo ""

echo "3️⃣ Checking Integrations..."
aws apigatewayv2 get-integrations --api-id $API_ID --region $REGION --no-cli-pager | grep -o '"IntegrationUri": "[^"]*groupCreated[^"]*"' && echo "   ✅ groupCreated integration configured" || echo "   ❌ groupCreated integration MISSING"
aws apigatewayv2 get-integrations --api-id $API_ID --region $REGION --no-cli-pager | grep -o '"IntegrationUri": "[^"]*groupUpdate[^"]*"' && echo "   ✅ groupUpdate integration configured" || echo "   ❌ groupUpdate integration MISSING"
echo ""

echo "4️⃣ Recent CloudWatch Logs (last 5 min)..."
echo "   groupCreated Lambda:"
aws logs tail /aws/lambda/websocket-groupCreated_AlexHo --since 5m --format short --region $REGION 2>/dev/null | tail -10 || echo "   (No recent logs)"
echo ""
echo "   groupUpdate Lambda:"
aws logs tail /aws/lambda/websocket-groupUpdate_AlexHo --since 5m --format short --region $REGION 2>/dev/null | tail -10 || echo "   (No recent logs)"
echo ""

echo "✅ Test Complete!"

