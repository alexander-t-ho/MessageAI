/**
 * Create Pinecone Index
 * Run this once to set up the vector database
 */

const { PineconeClient } = require('@pinecone-database/pinecone');

async function createPineconeIndex() {
  console.log('🚀 Creating Pinecone index...');
  
  const pinecone = new PineconeClient();
  await pinecone.init({
    apiKey: 'pcsk_6vRtax_3DvXDyPkzAByGwZQfLA1AfJU8ZtQQps8Y2uWpS41pMbkBKHxhNVnimZhxJQdpg7',
    environment: 'us-east-1-aws'
  });
  
  console.log('✅ Pinecone client initialized');
  
  try {
    // Check if index already exists
    const indexes = await pinecone.listIndexes();
    const indexExists = indexes.indexes?.some(idx => idx.name === 'slang-rag');
    
    if (indexExists) {
      console.log('✅ Index "slang-rag" already exists');
      return;
    }
    
    // Create new index
    console.log('📊 Creating new index "slang-rag"...');
    await pinecone.createIndex({
      createRequest: {
        name: 'slang-rag',
        dimension: 1536, // OpenAI ada-002 embedding size
        metric: 'cosine'
      }
    });
    
    console.log('⏳ Waiting for index to be ready...');
    
    // Wait for index to be ready
    let ready = false;
    let attempts = 0;
    while (!ready && attempts < 30) {
      await new Promise(resolve => setTimeout(resolve, 2000));
      const description = await pinecone.describeIndex('slang-rag');
      ready = description.status?.ready;
      attempts++;
      console.log(`   Status: ${description.status?.state || 'checking...'}`);
    }
    
    if (ready) {
      console.log('✅ Index created and ready!');
      console.log('📝 Index details:');
      const description = await pinecone.describeIndex('slang-rag');
      console.log('   Name:', description.name);
      console.log('   Dimension:', description.dimension);
      console.log('   Metric:', description.metric);
      console.log('   Host:', description.host);
    } else {
      console.log('⚠️  Index creation timeout - check Pinecone dashboard');
    }
    
  } catch (error) {
    console.error('❌ Error creating index:', error.message);
    throw error;
  }
}

// Run if called directly
if (require.main === module) {
  createPineconeIndex()
    .then(() => {
      console.log('\n✨ Pinecone setup complete!');
      process.exit(0);
    })
    .catch(error => {
      console.error('\n❌ Setup failed:', error);
      process.exit(1);
    });
}

module.exports = { createPineconeIndex };
