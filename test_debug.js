const fetch = require('node-fetch');

async function testDebugEndpoint() {
  try {
    const response = await fetch('http://localhost:5002/api/debug/test');
    if (response.ok) {
      const result = await response.json();
      console.log('Debug endpoint response:', result);
    } else {
      console.error('Debug endpoint failed');
    }
  } catch (error) {
    console.error('Error:', error.message);
  }
}

testDebugEndpoint();