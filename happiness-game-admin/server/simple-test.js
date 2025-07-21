const admin = require('firebase-admin');
const express = require('express');
const cors = require('cors');

// Initialize Firebase Admin SDK
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();
const app = express();
const PORT = 5004;

app.use(cors());
app.use(express.json());

// Simple test endpoint
app.get('/api/test', (req, res) => {
  res.json({ message: 'Server working', timestamp: new Date() });
});

// Simple subscriptions endpoint
app.get('/api/subscriptions', async (req, res) => {
  try {
    console.log('Getting users...');
    const usersSnapshot = await db.collection('users').get();
    console.log(`Found ${usersSnapshot.size} users`);
    
    const subscriptions = [];
    
    for (const userDoc of usersSnapshot.docs) {
      const userData = userDoc.data();
      const userId = userDoc.id;
      
      const subscription = {
        userId: userId,
        deviceId: null, // Always show as 未設定 for now
        currentUserId: userId,
        username: userData.username || '未設定',
        firstInstallDate: Math.floor(Date.now() / 1000) - 86400,
        hasPaid: false,
        paymentDate: null,
        amount: null,
        createdAt: Math.floor(Date.now() / 1000) - 86400,
        lastSeenAt: Math.floor(Date.now() / 1000)
      };
      
      subscriptions.push(subscription);
    }
    
    console.log(`Returning ${subscriptions.length} subscriptions`);
    res.json(subscriptions);
  } catch (error) {
    console.error('Error:', error);
    res.status(500).json({ error: error.message });
  }
});

app.listen(PORT, () => {
  console.log(`Simple test server is running on port ${PORT}`);
});