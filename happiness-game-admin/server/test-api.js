const admin = require('firebase-admin');

// Initialize Firebase Admin SDK if not already initialized
if (!admin.apps.length) {
  const serviceAccount = require('./serviceAccountKey.json');
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
}

const db = admin.firestore();

async function testAPI() {
  try {
    console.log('=== Simulating /api/subscriptions endpoint ===\n');
    
    // Get users
    const usersSnapshot = await db.collection('users').get();
    console.log(`Found ${usersSnapshot.size} users\n`);
    
    const subscriptions = [];
    
    for (const userDoc of usersSnapshot.docs) {
      const userData = userDoc.data();
      const userId = userDoc.id;
      
      console.log(`Processing user: ${userData.username} (${userId})`);
      
      // Create subscription record from user data
      const subscription = {
        userId: userData.deviceId || 'user-' + userId.substring(0, 8),
        deviceId: userData.deviceId || 'user-' + userId.substring(0, 8),
        currentUserId: userId,
        username: userData.username || '未設定',
        firstInstallDate: Math.floor(Date.now() / 1000) - 86400, // 1 day ago as default
        hasPaid: false,
        paymentDate: null,
        amount: null,
        createdAt: Math.floor(Date.now() / 1000) - 86400,
        lastSeenAt: Math.floor(Date.now() / 1000)
      };
      
      // Handle Firestore timestamp if present
      if (userData.createdAt) {
        if (userData.createdAt.seconds) {
          subscription.firstInstallDate = userData.createdAt.seconds;
          subscription.createdAt = userData.createdAt.seconds;
        } else if (typeof userData.createdAt === 'number') {
          subscription.firstInstallDate = userData.createdAt;
          subscription.createdAt = userData.createdAt;
        }
      }
      
      subscriptions.push(subscription);
      console.log(`  Created subscription record for ${userData.username}`);
    }
    
    console.log(`\nTotal subscriptions created: ${subscriptions.length}`);
    console.log('\nSample subscription data:');
    console.log(JSON.stringify(subscriptions[0], null, 2));
    
    return subscriptions;
    
  } catch (error) {
    console.error('Error in testAPI:', error);
    return [];
  }
}

testAPI().then(result => {
  console.log('\n=== Test completed ===');
  process.exit(0);
});