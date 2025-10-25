/**
 * Slang Ingestion with LangChain
 * Loads slang database into Pinecone vector store
 */

const { PineconeStore } = require("@langchain/community/vectorstores/pinecone");
const { OpenAIEmbeddings } = require("@langchain/openai");
const { Document } = require("@langchain/core/documents");
const { PineconeClient } = require("@pinecone-database/pinecone");
const fs = require('fs');
const path = require('path');

async function ingestSlangDatabase() {
  console.log("🚀 Starting slang database ingestion with LangChain...");
  
  // Load slang database
  const slangData = JSON.parse(
    fs.readFileSync(path.join(__dirname, 'slang-database.json'), 'utf8')
  );
  
  console.log(`📚 Loaded ${slangData.slang_terms.length} slang terms`);
  
  // Initialize Pinecone
  const pinecone = new PineconeClient();
  await pinecone.init({
    apiKey: process.env.PINECONE_API_KEY,
    environment: process.env.PINECONE_ENV || "us-east-1-aws"
  });
  
  console.log("✅ Pinecone initialized");
  
  // Create documents for LangChain
  const documents = slangData.slang_terms.map(slang => {
    // Create rich text for embedding
    const pageContent = `
Term: ${slang.term}
Definition: ${slang.definition}
Usage: ${slang.usage}
Origin: ${slang.origin}
Category: ${slang.category}
Examples: ${slang.examples.join(', ')}
Synonyms: ${slang.synonyms.join(', ')}
    `.trim();
    
    return new Document({
      pageContent,
      metadata: {
        term: slang.term,
        definition: slang.definition,
        usage: slang.usage,
        origin: slang.origin,
        category: slang.category,
        year: slang.year,
        examples: JSON.stringify(slang.examples),
        synonyms: JSON.stringify(slang.synonyms)
      }
    });
  });
  
  console.log(`📄 Created ${documents.length} documents`);
  
  // Initialize embeddings
  const embeddings = new OpenAIEmbeddings({
    openAIApiKey: process.env.OPENAI_API_KEY,
    modelName: "text-embedding-ada-002"
  });
  
  console.log("🔢 Generating embeddings and uploading to Pinecone...");
  console.log("⏳ This may take a minute...");
  
  // Upload to Pinecone (LangChain handles batching and embedding generation)
  await PineconeStore.fromDocuments(
    documents,
    embeddings,
    {
      pineconeIndex: pinecone.Index("slang-rag"),
      namespace: "slang"
    }
  );
  
  console.log("✅ Successfully ingested slang database!");
  console.log(`📊 Total terms: ${documents.length}`);
  console.log("🎯 Terms now searchable via semantic similarity");
  
  // Test a query
  console.log("\n🧪 Testing retrieval...");
  const vectorStore = await PineconeStore.fromExistingIndex(
    embeddings,
    {
      pineconeIndex: pinecone.Index("slang-rag"),
      namespace: "slang"
    }
  );
  
  const results = await vectorStore.similaritySearch("got rizz", 3);
  console.log("📝 Test query 'got rizz' returned:");
  results.forEach((doc, i) => {
    console.log(`  ${i + 1}. ${doc.metadata.term} (${doc.metadata.category})`);
  });
  
  console.log("\n✨ Ingestion complete! RAG pipeline is ready.");
}

// Run ingestion
if (require.main === module) {
  ingestSlangDatabase()
    .then(() => {
      console.log("✅ Done!");
      process.exit(0);
    })
    .catch(error => {
      console.error("❌ Error:", error);
      process.exit(1);
    });
}

module.exports = { ingestSlangDatabase };
