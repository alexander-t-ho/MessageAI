/**
 * Test the simplified RAG locally
 */

const { handler } = require('./rag-slang-simple');

async function test() {
  console.log('🧪 Testing RAG slang detection...\n');
  
  const testMessages = [
    "Bro got major rizz no cap",
    "That party was bussin fr fr",
    "She's slaying, periodt",
    "Lowkey vibing with this",
    "This hits different ngl"
  ];
  
  for (const message of testMessages) {
    console.log(`\n📝 Testing: "${message}"`);
    console.log('─'.repeat(60));
    
    const event = {
      body: JSON.stringify({ message })
    };
    
    try {
      const result = await handler(event);
      const response = JSON.parse(result.body);
      
      if (response.success) {
        console.log('✅ Success!');
        console.log('From cache:', response.fromCache);
        
        if (response.result.hasContext) {
          console.log(`\nFound ${response.result.hints.length} slang terms:`);
          response.result.hints.forEach((hint, i) => {
            console.log(`\n${i + 1}. "${hint.phrase}"`);
            console.log(`   Means: ${hint.actualMeaning}`);
            console.log(`   Context: ${hint.explanation}`);
          });
        } else {
          console.log('No slang detected');
        }
        
        if (response.retrievedTerms) {
          console.log('\nRetrieved from DB:', response.retrievedTerms.join(', '));
        }
      } else {
        console.log('❌ Error:', response.error);
      }
    } catch (error) {
      console.log('❌ Test failed:', error.message);
    }
  }
  
  console.log('\n\n✅ All tests complete!');
}

test().catch(console.error);
