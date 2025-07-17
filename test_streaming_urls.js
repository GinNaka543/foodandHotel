const fetch = require('node-fetch');

async function testStreamingUrls() {
  const testData = {
    title: "Test Plan with Streaming URLs",
    animeName: "Test Anime",
    duration: "2時間",
    description: "Test plan to verify streaming URLs are saved",
    spots: [],
    price: 100,
    tags: [],
    imageUrl: "",
    thumbnailUrl: "",
    numberOfDays: 1,
    streamingUrls: [
      { name: "Netflix", url: "https://netflix.com/test" },
      { name: "Amazon Prime Video", url: "https://amazon.com/test" }
    ]
  };

  console.log('📤 Sending data to server:');
  console.log('streamingUrls:', JSON.stringify(testData.streamingUrls, null, 2));

  try {
    const response = await fetch('http://localhost:5002/api/travel-plans', {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(testData),
    });

    if (response.ok) {
      const result = await response.json();
      console.log('✅ Plan created successfully!');
      console.log('Plan ID:', result.id);
      console.log('Returned streamingUrls:', result.streamingUrls);
      
      // Verify by fetching the plan back
      const fetchResponse = await fetch(`http://localhost:5002/api/travel-plans`);
      const plans = await fetchResponse.json();
      const createdPlan = plans.find(p => p.id === result.id);
      
      if (createdPlan) {
        console.log('🔍 Verified from server:');
        console.log('streamingUrls in Firebase:', createdPlan.streamingUrls);
      }
    } else {
      const error = await response.text();
      console.error('❌ Request failed:', error);
    }
  } catch (error) {
    console.error('❌ Error:', error.message);
  }
}

testStreamingUrls();