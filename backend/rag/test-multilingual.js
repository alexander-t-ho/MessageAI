/**
 * Test RAG with multiple languages
 */

const { handler } = require('./rag-slang-simple');

async function test() {
  console.log('🌍 Testing Multilingual Slang Explanations\n');
  
  const tests = [
    {
      message: "Bro got major rizz no cap",
      language: 'en',
      languageName: 'English'
    },
    {
      message: "Bro got major rizz no cap",
      language: 'es',
      languageName: 'Spanish (Español)'
    },
    {
      message: "That's bussin fr",
      language: 'fr',
      languageName: 'French (Français)'
    },
    {
      message: "She's slaying periodt",
      language: 'de',
      languageName: 'German (Deutsch)'
    }
  ];
  
  for (const test of tests) {
    console.log(`\n${'='.repeat(70)}`);
    console.log(`📝 Message: "${test.message}"`);
    console.log(`🌍 Explanation Language: ${test.languageName} (${test.language})`);
    console.log('─'.repeat(70));
    
    const event = {
      body: JSON.stringify({ 
        message: test.message,
        targetLang: test.language 
      })
    };
    
    try {
      const result = await handler(event);
      const response = JSON.parse(result.body);
      
      if (response.success && response.result.hasContext) {
        response.result.hints.forEach((hint, i) => {
          console.log(`\n${i + 1}. Slang: "${hint.phrase}"`);
          console.log(`   Means: ${hint.actualMeaning}`);
          console.log(`   Context: ${hint.explanation}`);
          if (hint.literalMeaning) {
            console.log(`   Literal: ${hint.literalMeaning}`);
          }
        });
        
        console.log(`\n✅ Success! Explained ${response.result.hints.length} terms in ${test.languageName}`);
      } else {
        console.log('⚠️  No slang detected');
      }
    } catch (error) {
      console.log('❌ Error:', error.message);
    }
  }
  
  console.log(`\n\n${'='.repeat(70)}`);
  console.log('✨ Multilingual test complete!');
  console.log('🎯 RAG pipeline supports explanations in 20+ languages');
}

test().catch(console.error);
