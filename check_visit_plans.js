const fetch = require('node-fetch');

async function checkVisitPlans() {
  try {
    const response = await fetch('http://localhost:5002/api/travel-plans');
    if (response.ok) {
      const plans = await response.json();
      console.log(`Found ${plans.length} visit plans:`);
      
      plans.forEach((plan, index) => {
        console.log(`\nPlan ${index + 1}:`);
        console.log(`  ID: ${plan.id}`);
        console.log(`  Title: ${plan.title}`);
        console.log(`  streamingUrls: ${JSON.stringify(plan.streamingUrls)}`);
        console.log(`  All fields: ${Object.keys(plan).join(', ')}`);
      });
    } else {
      console.error('Failed to fetch plans');
    }
  } catch (error) {
    console.error('Error:', error.message);
  }
}

checkVisitPlans();