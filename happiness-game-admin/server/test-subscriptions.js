const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function testSubscriptions() {
  try {
    console.log('\n=== Testing Users Collection ===');
    const usersSnapshot = await db.collection('users').get();
    console.log(`Found ${usersSnapshot.size} users`);
    
    usersSnapshot.forEach(doc => {
      const data = doc.data();
      console.log(`\nUser: ${doc.id}`);
      console.log(`  Username: ${data.username}`);
      console.log(`  DeviceId: ${data.deviceId || 'NOT SET'}`);
      console.log(`  CreatedAt: ${data.createdAt}`);
    });
    
    console.log('\n=== Testing Subscriptions Collection ===');
    const subscriptionsSnapshot = await db.collection('subscriptions').get();
    console.log(`Found ${subscriptionsSnapshot.size} subscription records`);
    
    subscriptionsSnapshot.forEach(doc => {
      const data = doc.data();
      console.log(`\nSubscription: ${doc.id}`);
      console.log(`  UserId: ${data.userId}`);
      console.log(`  DeviceId: ${data.deviceId || 'NOT SET'}`);
      console.log(`  HasPaid: ${data.hasPaid}`);
    });
    
    console.log('\n=== Testing Device Subscriptions Collection ===');
    const deviceSubsSnapshot = await db.collection('device_subscriptions').get();
    console.log(`Found ${deviceSubsSnapshot.size} device subscription records`);
    
    deviceSubsSnapshot.forEach(doc => {
      const data = doc.data();
      console.log(`\nDevice Subscription: ${doc.id}`);
      console.log(`  CurrentUserId: ${data.currentUserId}`);
      console.log(`  HasPaid: ${data.hasPaid}`);
    });
    
  } catch (error) {
    console.error('Error:', error);
  }
  
  process.exit(0);
}

testSubscriptions();