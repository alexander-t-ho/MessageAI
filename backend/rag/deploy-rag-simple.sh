#!/bin/bash

# Deploy Simplified RAG with DynamoDB (No Pinecone needed!)

REGION="us-east-1"
ACCOUNT_ID="971422717446"
LAMBDA_ROLE="MessageAI-WebSocket-Role_AlexHo"  # Use existing role
FUNCTION_NAME="rag-slang_AlexHo"

echo "🚀 Deploying Simplified RAG Pipeline with DynamoDB..."

# Create deployment package (smaller - no Pinecone/OpenAI needed!)
echo "📦 Creating deployment package..."
rm -f rag-slang-simple.zip
zip -q rag-slang-simple.zip rag-slang-simple.js
cd node_modules && zip -q -r ../rag-slang-simple.zip @aws-sdk && cd ..

# Check if Lambda exists
LAMBDA_EXISTS=$(aws lambda get-function --function-name $FUNCTION_NAME --region $REGION 2>&1)

if echo "$LAMBDA_EXISTS" | grep -q "ResourceNotFoundException"; then
  echo "🆕 Creating new Lambda function..."
  
  aws lambda create-function \
    --function-name $FUNCTION_NAME \
    --runtime nodejs20.x \
    --role arn:aws:iam::$ACCOUNT_ID:role/$LAMBDA_ROLE \
    --handler rag-slang-simple.handler \
    --zip-file fileb://rag-slang-simple.zip \
    --timeout 30 \
    --memory-size 512 \
    --region $REGION \
    --no-cli-pager
else
  echo "🔄 Updating existing Lambda function..."
  
  aws lambda update-function-code \
    --function-name $FUNCTION_NAME \
    --zip-file fileb://rag-slang-simple.zip \
    --region $REGION \
    --no-cli-pager
  
  sleep 3
  
  aws lambda update-function-configuration \
    --function-name $FUNCTION_NAME \
    --timeout 30 \
    --memory-size 512 \
    --region $REGION \
    --no-cli-pager
fi

# Clean up
rm -f rag-slang-simple.zip

echo ""
echo "✅ RAG Lambda deployed successfully!"
echo ""
echo "📊 Lambda Details:"
echo "   Name: $FUNCTION_NAME"
echo "   Runtime: Node.js 20.x"
echo "   Handler: rag-slang-simple.handler"
echo "   Memory: 512 MB"
echo "   Database: DynamoDB (SlangDatabase_AlexHo)"
echo ""
echo "🧪 Test the Lambda:"
echo '   aws lambda invoke --function-name '$FUNCTION_NAME' \'
echo '     --payload '"'"'{"body":"{\"message\":\"Bro got rizz\"}"}'"'"' \'
echo '     response.json && cat response.json'
echo ""
echo "✨ Next: Integrate with WebSocket for real-time queries"
