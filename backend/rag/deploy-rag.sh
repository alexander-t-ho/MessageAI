#!/bin/bash

# Deploy RAG Pipeline with LangChain
# Prerequisites: Pinecone account, API keys in Secrets Manager

REGION="us-east-1"
ACCOUNT_ID="971422717446"
LAMBDA_ROLE="MessageAI-AI-Role_AlexHo"
FUNCTION_NAME="rag-slang_AlexHo"

echo "🚀 Deploying RAG Pipeline with LangChain..."

# Install dependencies if not already installed
if [ ! -d "node_modules" ]; then
  echo "📦 Installing dependencies..."
  npm install
fi

# Create deployment package
echo "📦 Creating deployment package..."
rm -f rag-slang.zip
zip -q -r rag-slang.zip rag-slang-langchain.js node_modules/

# Check if Lambda exists
LAMBDA_EXISTS=$(aws lambda get-function --function-name $FUNCTION_NAME --region $REGION 2>&1)

if echo "$LAMBDA_EXISTS" | grep -q "ResourceNotFoundException"; then
  echo "🆕 Creating new Lambda function..."
  
  aws lambda create-function \
    --function-name $FUNCTION_NAME \
    --runtime nodejs20.x \
    --role arn:aws:iam::$ACCOUNT_ID:role/$LAMBDA_ROLE \
    --handler rag-slang-langchain.handler \
    --zip-file fileb://rag-slang.zip \
    --timeout 30 \
    --memory-size 1024 \
    --environment Variables="{
      AWS_REGION=$REGION,
      LANGCHAIN_TRACING_V2=true
    }" \
    --region $REGION \
    --no-cli-pager
else
  echo "🔄 Updating existing Lambda function..."
  
  aws lambda update-function-code \
    --function-name $FUNCTION_NAME \
    --zip-file fileb://rag-slang.zip \
    --region $REGION \
    --no-cli-pager
  
  echo "⏳ Waiting for update to complete..."
  sleep 3
  
  aws lambda update-function-configuration \
    --function-name $FUNCTION_NAME \
    --timeout 30 \
    --memory-size 1024 \
    --environment Variables="{
      AWS_REGION=$REGION,
      LANGCHAIN_TRACING_V2=true
    }" \
    --region $REGION \
    --no-cli-pager
fi

# Clean up
rm -f rag-slang.zip

echo ""
echo "✅ RAG Lambda deployed successfully!"
echo ""
echo "📝 Next steps:"
echo ""
echo "1. Ensure secrets exist in Secrets Manager:"
echo "   - pinecone-credentials-alexho"
echo "   - claude-api-key-alexho"
echo "   - openai-api-key-alexho"
echo ""
echo "2. Run ingestion to populate vector database:"
echo "   npm run ingest"
echo ""
echo "3. Test the Lambda:"
echo "   aws lambda invoke --function-name $FUNCTION_NAME \\"
echo "     --payload '{\"body\":\"{\\\"message\\\":\\\"Bro got rizz\\\"}\"}' \\"
echo "     response.json && cat response.json"
echo ""
echo "4. Add WebSocket route for real-time queries"
echo ""
echo "📊 Lambda Details:"
echo "   Name: $FUNCTION_NAME"
echo "   Region: $REGION"
echo "   Runtime: Node.js 20.x"
echo "   Memory: 1024 MB"
echo "   Timeout: 30 seconds"
echo "   LangSmith: Enabled"
