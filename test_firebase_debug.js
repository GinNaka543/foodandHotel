const fetch = require('node-fetch');

async function checkFirebaseData() {
  try {
    // First, let's check what fields are actually in the Firebase data
    const response = await fetch('http://localhost:5002/api/debug/collections');
    if (response.ok) {
      const result = await response.json();
      console.log('Firebase collections debug info:');
      console.log(JSON.stringify(result, null, 2));
    } else {
      console.error('Debug collections endpoint failed');
    }
  } catch (error) {
    console.error('Error:', error.message);
  }
}

checkFirebaseData();