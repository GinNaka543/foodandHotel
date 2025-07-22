const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function migrateSubscriptions() {
  console.log('Starting subscription migration...');
  
  try {
    // Get all users
    const usersSnapshot = await db.collection('users').get();
    console.log(`Found ${usersSnapshot.size} users to process`);
    
    // Also check for existing subscriptions to migrate
    const subscriptionsSnapshot = await db.collection('subscriptions').get();
    console.log(`Found ${subscriptionsSnapshot.size} subscription records`);
    
    let migrated = 0;
    let skipped = 0;
    
    // First, migrate users with deviceId
    for (const userDoc of usersSnapshot.docs) {
      const userData = userDoc.data();
      const userId = userDoc.id;
      
      // Skip if no device ID
      if (!userData.deviceId) {
        console.log(`User ${userId} (${userData.username}) - no deviceId yet`);
        skipped++;
        continue;
      }
      
      // Check if device subscription already exists
      const deviceSubDoc = await db.collection('device_subscriptions').doc(userData.deviceId).get();
      if (deviceSubDoc.exists) {
        console.log(`Device subscription already exists for ${userData.deviceId}`);
        continue;
      }
      
      // Create device subscription document
      const deviceSubscriptionData = {
        deviceId: userData.deviceId,
        currentUserId: userId,
        firstInstallDate: userData.createdAt || Date.now() / 1000,
        hasPaid: userData.hasPaidSubscription || false,
        createdAt: Date.now() / 1000,
        lastSeenAt: userData.updatedAt || Date.now() / 1000
      };
      
      // Check if user has subscription data
      const subDoc = await db.collection('subscriptions').doc(userId).get();
      if (subDoc.exists) {
        const subData = subDoc.data();
        deviceSubscriptionData.hasPaid = subData.hasPaid || false;
        deviceSubscriptionData.paymentDate = subData.paymentDate;
        deviceSubscriptionData.amount = subData.amount;
        deviceSubscriptionData.firstInstallDate = subData.firstInstallDate || deviceSubscriptionData.firstInstallDate;
      }
      
      // Save to device_subscriptions
      await db.collection('device_subscriptions').doc(userData.deviceId).set(deviceSubscriptionData);
      console.log(`Migrated user ${userId} with device ${userData.deviceId}`);
      migrated++;
    }
    
    console.log(`\nMigration complete!`);
    console.log(`- Migrated: ${migrated} users`);
    console.log(`- Skipped: ${skipped} users (no deviceId)`);
    
  } catch (error) {
    console.error('Migration error:', error);
  }
  
  process.exit(0);
}

// Run migration
migrateSubscriptions();