/**
 * Ingest Slang Database into DynamoDB
 * Simpler alternative to Pinecone - uses AWS DynamoDB
 */

const { DynamoDBClient } = require("@aws-sdk/client-dynamodb");
const { DynamoDBDocumentClient, GetCommand, PutCommand, BatchWriteCommand } = require("@aws-sdk/lib-dynamodb");
const fs = require('fs');
const path = require('path');

const client = new DynamoDBClient({ region: "us-east-1" });
const docClient = DynamoDBDocumentClient.from(client);

const SLANG_TABLE = "SlangDatabase_AlexHo";

async function ingestSlangDatabase() {
  console.log('🚀 Starting slang database ingestion into DynamoDB...');
  
  // Load slang database
  const slangData = JSON.parse(
    fs.readFileSync(path.join(__dirname, 'slang-database.json'), 'utf8')
  );
  
  console.log(`📚 Loaded ${slangData.slang_terms.length} slang terms`);
  
  // Batch write to DynamoDB
  const putRequests = slangData.slang_terms.map(slang => ({
    PutRequest: {
      Item: {
        term: slang.term,
        termLower: slang.term.toLowerCase(), // For case-insensitive matching
        definition: slang.definition,
        usage: slang.usage,
        origin: slang.origin,
        category: slang.category,
        year: slang.year,
        examples: JSON.stringify(slang.examples),
        synonyms: JSON.stringify(slang.synonyms),
        updatedAt: new Date().toISOString()
      }
    }
  }));
  
  // DynamoDB batch write allows max 25 items per request
  const batches = [];
  for (let i = 0; i < putRequests.length; i += 25) {
    batches.push(putRequests.slice(i, i + 25));
  }
  
  console.log(`📦 Writing ${batches.length} batches to DynamoDB...`);
  
  for (let i = 0; i < batches.length; i++) {
    console.log(`   Batch ${i + 1}/${batches.length}...`);
    await docClient.send(new BatchWriteCommand({
      RequestItems: {
        [SLANG_TABLE]: batches[i]
      }
    }));
  }
  
  console.log('✅ Successfully ingested all slang terms!');
  console.log(`📊 Total terms: ${slangData.slang_terms.length}`);
  console.log('🎯 Terms now searchable in DynamoDB');
  
  // Verify ingestion
  console.log('\n🧪 Verifying ingestion...');
  const sample = slangData.slang_terms[0];
  const testResult = await docClient.send(new GetCommand({
    TableName: SLANG_TABLE,
    Key: { term: sample.term }
  }));
  
  if (testResult.Item) {
    console.log(`✅ Verification passed! Sample term "${sample.term}" found in database`);
  } else {
    console.log('⚠️  Verification failed - sample term not found');
  }
  
  console.log('\n✨ Ingestion complete! Slang database is ready.');
  console.log('\n📝 Next step: Deploy the Lambda function');
  console.log('   Run: ./deploy-rag-simple.sh');
}

// Run if called directly
if (require.main === module) {
  ingestSlangDatabase()
    .then(() => {
      console.log('\n✅ Done!');
      process.exit(0);
    })
    .catch(error => {
      console.error('\n❌ Error:', error);
      process.exit(1);
    });
}

module.exports = { ingestSlangDatabase };
