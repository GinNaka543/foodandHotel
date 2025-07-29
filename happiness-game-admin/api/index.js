const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const admin = require('firebase-admin');
require('dotenv').config();
const axios = require('axios');
const cheerio = require('cheerio');
const stripe = require('stripe')(process.env.STRIPE_SECRET_KEY);

const app = express();

// Middleware
app.use(cors({
  origin: process.env.NODE_ENV === 'production' ? 
    ['https://happiness-game-admin.vercel.app', 'https://happiness-game-admin-git-main.vercel.app'] : 
    ['http://localhost:3000', 'http://localhost:3001'],
  credentials: true
}));
app.use(bodyParser.json({ limit: '50mb' }));
app.use(bodyParser.urlencoded({ extended: true, limit: '50mb' }));

// Firebase Admin初期化
let adminApp;
let db;

try {
  let serviceAccount;
  
  console.log('Firebase: Starting initialization...');
  console.log('Firebase: Environment NODE_ENV:', process.env.NODE_ENV);
  console.log('Firebase: Has FIREBASE_SERVICE_ACCOUNT:', !!process.env.FIREBASE_SERVICE_ACCOUNT);
  
  // Vercel環境では環境変数から取得
  if (process.env.FIREBASE_SERVICE_ACCOUNT) {
    console.log('Firebase: 環境変数からサービスアカウントを取得中...');
    try {
      serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
      console.log('Firebase: JSON parse successful');
      console.log('Firebase: Project ID:', serviceAccount.project_id);
      console.log('Firebase: Client Email:', serviceAccount.client_email);
    } catch (parseError) {
      console.error('Firebase: JSON parse failed:', parseError.message);
      console.log('Firebase: Falling back to hardcoded config...');
      // フォールバック用のハードコーデッド設定
      serviceAccount = {
        type: "service_account",
        project_id: "ani-reco",
        private_key_id: "80657e9e259d429ae1fa74777bd127cbe404109c",
        private_key: "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCeQ3dWEMmrTypm\njsgnwAgVDMqffH9jMf8i4fVk6phJ8s2cpTVf2DbDBIWw5aXHXeXCaPqzg5pjziIl\nsHyqCIo1bj9x8dhKUDMiaPezDIh7SR69uGLFhVAvZvUyj8Vq1jL+EW+7ToBSuaCO\n65VwAyIwxsxL7J0mucU86m7duFpSyMCdsLi1o7MrsU3Wchh01AfXESJ1WT4vfqfz\nr7zkEH7I4wl3Tqpxw+i5wHjZ8U9Q58SeeLonl2myYBTof0V1we+OLPJhyNIYuQzZ\nYrR5R6ZntDPpize2LwrqWyTheA0P6N2afIgPowAsmCGUzUQdfynBKDEUQo4fvWId\nzqdKQcQzAgMBAAECggEADNHBLlcAxuAMOq9xFgsvfGkDVqTSern3hR9RbcG04TSK\nJBibuK4+TVCl9Zy8b2gzLqqrN/Q+grwVNwFTL8CuVUKfX/7reqWBZtWizr2Cpp3X\nIB353i78vkI0NUrA/nToP30xFDZ5HXpMv5bkjWSrldDchn/dgOAGUndY0JvYsSDS\nGVhsqiC433lRv6gFy/W3HvtxwiZxdsD1TfvbWUHDiToGPnkbytg1HDB7FNkHWKMy\nTOkeHCaHGebMLlIkoa1P72NJonOU+1ohcZPgwuo2yefS1OzsptPYD+CvNuaAxgik\nFw1oF4Ys/ssCYlokCJtaYeFo8Wx0+QdP+uH9pTtDnQKBgQDSZK9o+plzDfKrbzsj\n5GmYZHE/quboTsFt5kOazVfFG3KdGaSWc/ycom7BlmuYYq17Om0I7+YLYC7IXCp3\nyA61doSXbgDnk8m8ykTC5qFoqYNHcwAkRYwqCEOSP1qWMOXQIYSmqZ7VAGZ3SDc5\nDNEKowapj35DWgMhlB6oPAUKFQKBgQDAkfREJ3p4DBXQSj4knugax7CDAyYimw72\n7TmHkmNUYd5N6YXM6R1Ceas1I1nq1hbYOgvJp4sEjfKaZqb6+FSOhiEbxD7EyWiC\nx/6OpnJdqWzOn8l5ixZuBpYPsxRjxb8S/COjJNodq9gajGj7nxGPo28Ct1vwbKSf\ne4j1Cc4PJwKBgQCv6IUMxfJE01WhZrfQ06pCQ0C41eCIPUjW5V6C8MtAvyk+FvGY\n5dNA90KZU3YUi/S2gmwlu8bgngOffAf57Gf36ucDYXMaLGPRGGETgBdWVdywgYON\n0CRYBF7SyWupBaswMMYjPtDREKubceLSLVgeh54LaTFNiNXzXk+fo8cm3QKBgEoa\nIBf15R+67s33M9CdwY1EmHzhwlQAvRJyGPg9cbGv836hxRYkAllpPmO1Vc2TUrkk\nJRMVQN6gzOFzbQAYfVlW7fikXM8W/fuNgDxeepXmM3OTc1EtH5V5PVePPuJh3vQs\nSH5oGPLgBMm6jE9/V5+hcX9nFZ7//51LSVmZy0xzAoGAXcsv0IovDErbTNrZ7tCt\ntne1saacGrgkxi7X7QRro7aHPPHF66t+O53flXRySA0uvnVxcj2NLrOadbW8FL6T\niCxs8p+fhIhvbA29Y+lOcmX58C59QBgSavHOzH6maypYf8aAsKVx8Sc2SYDwBlyX\nmJUfAabgvf1x0RRsJExjEco=\n-----END PRIVATE KEY-----\n",
        client_email: "firebase-adminsdk-fbsvc@ani-reco.iam.gserviceaccount.com",
        client_id: "101509193145150551213",
        auth_uri: "https://accounts.google.com/o/oauth2/auth",
        token_uri: "https://oauth2.googleapis.com/token",
        auth_provider_x509_cert_url: "https://www.googleapis.com/oauth2/v1/certs",
        client_x509_cert_url: "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-fbsvc%40ani-reco.iam.gserviceaccount.com",
        universe_domain: "googleapis.com"
      };
    }
  } else {
    // フォールバック用のハードコーデッド設定
    console.log('Firebase: ハードコーデッド設定を使用中...');
    serviceAccount = {
      type: "service_account",
      project_id: "ani-reco",
      private_key_id: "80657e9e259d429ae1fa74777bd127cbe404109c",
      private_key: "-----BEGIN PRIVATE KEY-----\nMIIEvQIBADANBgkqhkiG9w0BAQEFAASCBKcwggSjAgEAAoIBAQCeQ3dWEMmrTypm\njsgnwAgVDMqffH9jMf8i4fVk6phJ8s2cpTVf2DbDBIWw5aXHXeXCaPqzg5pjziIl\nsHyqCIo1bj9x8dhKUDMiaPezDIh7SR69uGLFhVAvZvUyj8Vq1jL+EW+7ToBSuaCO\n65VwAyIwxsxL7J0mucU86m7duFpSyMCdsLi1o7MrsU3Wchh01AfXESJ1WT4vfqfz\nr7zkEH7I4wl3Tqpxw+i5wHjZ8U9Q58SeeLonl2myYBTof0V1we+OLPJhyNIYuQzZ\nYrR5R6ZntDPpize2LwrqWyTheA0P6N2afIgPowAsmCGUzUQdfynBKDEUQo4fvWId\nzqdKQcQzAgMBAAECggEADNHBLlcAxuAMOq9xFgsvfGkDVqTSern3hR9RbcG04TSK\nJBibuK4+TVCl9Zy8b2gzLqqrN/Q+grwVNwFTL8CuVUKfX/7reqWBZtWizr2Cpp3X\nIB353i78vkI0NUrA/nToP30xFDZ5HXpMv5bkjWSrldDchn/dgOAGUndY0JvYsSDS\nGVhsqiC433lRv6gFy/W3HvtxwiZxdsD1TfvbWUHDiToGPnkbytg1HDB7FNkHWKMy\nTOkeHCaHGebMLlIkoa1P72NJonOU+1ohcZPgwuo2yefS1OzsptPYD+CvNuaAxgik\nFw1oF4Ys/ssCYlokCJtaYeFo8Wx0+QdP+uH9pTtDnQKBgQDSZK9o+plzDfKrbzsj\n5GmYZHE/quboTsFt5kOazVfFG3KdGaSWc/ycom7BlmuYYq17Om0I7+YLYC7IXCp3\nyA61doSXbgDnk8m8ykTC5qFoqYNHcwAkRYwqCEOSP1qWMOXQIYSmqZ7VAGZ3SDc5\nDNEKowapj35DWgMhlB6oPAUKFQKBgQDAkfREJ3p4DBXQSj4knugax7CDAyYimw72\n7TmHkmNUYd5N6YXM6R1Ceas1I1nq1hbYOgvJp4sEjfKaZqb6+FSOhiEbxD7EyWiC\nx/6OpnJdqWzOn8l5ixZuBpYPsxRjxb8S/COjJNodq9gajGj7nxGPo28Ct1vwbKSf\ne4j1Cc4PJwKBgQCv6IUMxfJE01WhZrfQ06pCQ0C41eCIPUjW5V6C8MtAvyk+FvGY\n5dNA90KZU3YUi/S2gmwlu8bgngOffAf57Gf36ucDYXMaLGPRGGETgBdWVdywgYON\n0CRYBF7SyWupBaswMMYjPtDREKubceLSLVgeh54LaTFNiNXzXk+fo8cm3QKBgEoa\nIBf15R+67s33M9CdwY1EmHzhwlQAvRJyGPg9cbGv836hxRYkAllpPmO1Vc2TUrkk\nJRMVQN6gzOFzbQAYfVlW7fikXM8W/fuNgDxeepXmM3OTc1EtH5V5PVePPuJh3vQs\nSH5oGPLgBMm6jE9/V5+hcX9nFZ7//51LSVmZy0xzAoGAXcsv0IovDErbTNrZ7tCt\ntne1saacGrgkxi7X7QRro7aHPPHF66t+O53flXRySA0uvnVxcj2NLrOadbW8FL6T\niCxs8p+fhIhvbA29Y+lOcmX58C59QBgSavHOzH6maypYf8aAsKVx8Sc2SYDwBlyX\nmJUfAabgvf1x0RRsJExjEco=\n-----END PRIVATE KEY-----\n",
      client_email: "firebase-adminsdk-fbsvc@ani-reco.iam.gserviceaccount.com",
      client_id: "101509193145150551213",
      auth_uri: "https://accounts.google.com/o/oauth2/auth",
      token_uri: "https://oauth2.googleapis.com/token",
      auth_provider_x509_cert_url: "https://www.googleapis.com/oauth2/v1/certs",
      client_x509_cert_url: "https://www.googleapis.com/robot/v1/metadata/x509/firebase-adminsdk-fbsvc%40ani-reco.iam.gserviceaccount.com",
      universe_domain: "googleapis.com"
    };
  }
  
  if (!admin.apps.length) {
    adminApp = admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: serviceAccount.project_id || 'ani-reco'
    });
    console.log('✅ Firebase Admin initialized successfully');
  } else {
    adminApp = admin.app();
    console.log('✅ Firebase Admin app already exists');
  }
  
  db = admin.firestore();
  console.log('✅ Firestore database initialized');
  
} catch (error) {
  console.error('❌ Firebase Admin initialization failed:', error);
  console.error('❌ Error details:', error.stack);
}

// Health check endpoint
app.get('/api/health', (req, res) => {
  try {
    const hasFirebase = !!adminApp;
    const hasDb = !!db;
    res.json({ 
      status: 'OK', 
      timestamp: new Date().toISOString(),
      firebase: hasFirebase,
      database: hasDb,
      projectId: process.env.FIREBASE_PROJECT_ID || 'ani-reco'
    });
  } catch (error) {
    console.error('Health check error:', error);
    res.status(500).json({ 
      status: 'ERROR', 
      error: error.message,
      timestamp: new Date().toISOString() 
    });
  }
});

// Debug test endpoint
app.get('/api/debug/test', (req, res) => {
  try {
    console.log('🧪 Debug test endpoint called');
    console.log('🧪 Firebase adminApp exists:', !!adminApp);
    console.log('🧪 Database exists:', !!db);
    console.log('🧪 Environment variables check:');
    console.log('  - NODE_ENV:', process.env.NODE_ENV);
    console.log('  - Has FIREBASE_SERVICE_ACCOUNT:', !!process.env.FIREBASE_SERVICE_ACCOUNT);
    
    if (process.env.FIREBASE_SERVICE_ACCOUNT) {
      try {
        const testParse = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
        console.log('  - JSON parse test successful, project_id:', testParse.project_id);
      } catch (e) {
        console.log('  - JSON parse test failed:', e.message);
      }
    }
    
    res.json({ 
      status: 'success',
      message: 'API connection working',
      timestamp: new Date().toISOString(),
      environment: process.env.NODE_ENV || 'development',
      firebase: !!adminApp,
      database: !!db,
      hasServiceAccount: !!process.env.FIREBASE_SERVICE_ACCOUNT
    });
  } catch (error) {
    console.error('Debug test error:', error);
    res.status(500).json({ 
      status: 'error', 
      error: error.message,
      timestamp: new Date().toISOString() 
    });
  }
});

// Debug collections endpoint to see Firebase structure
app.get('/api/debug/collections', async (req, res) => {
  try {
    console.log('🔍 Debug collections endpoint called');
    
    if (!db) {
      return res.status(500).json({ error: 'Database not initialized' });
    }

    const collections = ['users', 'userPoints', 'device_subscriptions', 'advertisements', 'favorites', 'user_favorites', 'user_anime', 'user_characters', 'characterRankings', 'animeRankings', 'apple_subscriptions', 'apple_receipts', 'apple_transactions', 'purchases', 'subscriptions'];
    const debug = {};

    for (const collectionName of collections) {
      try {
        const snapshot = await db.collection(collectionName).limit(1).get();
        debug[collectionName] = {
          exists: !snapshot.empty,
          size: snapshot.size,
          sampleData: snapshot.empty ? null : snapshot.docs[0].data()
        };
      } catch (error) {
        debug[collectionName] = { error: error.message };
      }
    }

    res.json({ 
      status: 'success',
      collections: debug,
      timestamp: new Date().toISOString()
    });
  } catch (error) {
    console.error('Debug collections error:', error);
    res.status(500).json({ 
      status: 'error', 
      error: error.message,
      timestamp: new Date().toISOString() 
    });
  }
});

// Get all users with points and favorites
app.get('/api/users', async (req, res) => {
  try {
    console.log('📊 Fetching users with points and favorites from Firestore...');
    
    if (!db) {
      console.error('❌ Database not initialized');
      return res.status(500).json({ error: 'Database not initialized' });
    }
    
    const usersSnapshot = await db.collection('users').get();
    console.log('📊 Users snapshot size:', usersSnapshot.size);
    
    const users = [];
    
    for (const doc of usersSnapshot.docs) {
      const userData = { id: doc.id, ...doc.data() };
      
      // Get user points
      try {
        const pointsDoc = await db.collection('userPoints').doc(doc.id).get();
        userData.points = pointsDoc.exists ? pointsDoc.data().points || 0 : 0;
      } catch (error) {
        console.log('⚠️ Failed to get points for user:', doc.id, error.message);
        userData.points = 0;
      }
      
      // Get user favorites from userCharacters and userAnimes collections
      userData.favorites = {
        characters: [],
        anime: [],
        voiceActors: userData.favoriteVoiceActors || []
      };
      
      // Get user characters
      try {
        const userCharactersSnapshot = await db.collection('userCharacters').where('userId', '==', doc.id).get();
        userCharactersSnapshot.forEach(charDoc => {
          const charData = charDoc.data();
          if (charData.name) {
            userData.favorites.characters.push(charData.name);
          }
        });
      } catch (error) {
        console.log('⚠️ Failed to get characters for user:', doc.id, error.message);
      }
      
      // Get user anime
      try {
        const userAnimesSnapshot = await db.collection('userAnimes').where('userId', '==', doc.id).get();
        userAnimesSnapshot.forEach(animeDoc => {
          const animeData = animeDoc.data();
          if (animeData.title) {
            userData.favorites.anime.push(animeData.title);
          }
        });
      } catch (error) {
        console.log('⚠️ Failed to get anime for user:', doc.id, error.message);
      }
      
      users.push(userData);
    }
    
    console.log('📊 Total users with enriched data:', users.length);
    res.json(users);
  } catch (error) {
    console.error('❌ Error fetching users:', error);
    console.error('❌ Error stack:', error.stack);
    res.status(500).json({ 
      error: 'Failed to fetch users',
      message: error.message,
      code: error.code 
    });
  }
});

// Get user by ID
app.get('/api/users/:id', async (req, res) => {
  try {
    const doc = await db.collection('users').doc(req.params.id).get();
    if (!doc.exists) {
      return res.status(404).json({ error: 'User not found' });
    }
    res.json({ id: doc.id, ...doc.data() });
  } catch (error) {
    console.error('Error fetching user:', error);
    res.status(500).json({ error: 'Failed to fetch user' });
  }
});

// Subscription management endpoints
app.get('/api/subscriptions', async (req, res) => {
  try {
    const subscriptionsSnapshot = await db.collection('device_subscriptions').get();
    const subscriptions = [];
    subscriptionsSnapshot.forEach(doc => {
      subscriptions.push({ id: doc.id, ...doc.data() });
    });
    res.json(subscriptions);
  } catch (error) {
    console.error('Error fetching subscriptions:', error);
    res.status(500).json({ error: 'Failed to fetch subscriptions' });
  }
});

// Points management endpoints
app.get('/api/points', async (req, res) => {
  try {
    const pointsSnapshot = await db.collection('userPoints').get();
    const pointsData = [];
    pointsSnapshot.forEach(doc => {
      pointsData.push({ id: doc.id, ...doc.data() });
    });
    res.json(pointsData);
  } catch (error) {
    console.error('Error fetching points data:', error);
    res.status(500).json({ error: 'Failed to fetch points data' });
  }
});

// Add points to user
app.post('/api/admin/add-points', async (req, res) => {
  try {
    const { userId, points, reason } = req.body;
    
    if (!userId || points === undefined) {
      return res.status(400).json({ error: 'userId and points are required' });
    }

    const userPointsRef = db.collection('userPoints').doc(userId);
    const doc = await userPointsRef.get();
    
    let currentPoints = 0;
    if (doc.exists) {
      currentPoints = doc.data().points || 0;
    }
    
    const newPoints = currentPoints + parseInt(points);
    
    await userPointsRef.set({
      points: newPoints,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
      history: admin.firestore.FieldValue.arrayUnion({
        points: parseInt(points),
        reason: reason || 'Admin adjustment',
        timestamp: admin.firestore.FieldValue.serverTimestamp()
      })
    }, { merge: true });

    res.json({ 
      success: true, 
      userId, 
      previousPoints: currentPoints,
      addedPoints: parseInt(points),
      newTotal: newPoints 
    });
  } catch (error) {
    console.error('Error adding points:', error);
    res.status(500).json({ error: 'Failed to add points' });
  }
});

// Advertisement management endpoints
app.get('/api/advertisements', async (req, res) => {
  try {
    const adsSnapshot = await db.collection('advertisements').orderBy('createdAt', 'desc').get();
    const ads = [];
    adsSnapshot.forEach(doc => {
      ads.push({ id: doc.id, ...doc.data() });
    });
    res.json(ads);
  } catch (error) {
    console.error('Error fetching advertisements:', error);
    res.status(500).json({ error: 'Failed to fetch advertisements' });
  }
});

// Travel plans endpoints
app.get('/api/travel-plans', async (req, res) => {
  try {
    const plansSnapshot = await db.collection('visit_plans').get();
    const plans = [];
    plansSnapshot.forEach(doc => {
      plans.push({ id: doc.id, ...doc.data() });
    });
    res.json(plans);
  } catch (error) {
    console.error('Error fetching travel plans:', error);
    res.status(500).json({ error: 'Failed to fetch travel plans' });
  }
});

// Custom rankings endpoints
app.get('/api/custom-rankings', async (req, res) => {
  try {
    const rankingsSnapshot = await db.collection('characterRankings').get();
    const rankings = [];
    rankingsSnapshot.forEach(doc => {
      rankings.push({ id: doc.id, ...doc.data() });
    });
    res.json(rankings);
  } catch (error) {
    console.error('Error fetching custom rankings:', error);
    res.status(500).json({ error: 'Failed to fetch custom rankings' });
  }
});

// GitHub repositories endpoints
app.get('/api/github-repositories', async (req, res) => {
  try {
    const reposSnapshot = await db.collection('githubRepositories').get();
    const repos = [];
    reposSnapshot.forEach(doc => {
      repos.push({ id: doc.id, ...doc.data() });
    });
    res.json(repos);
  } catch (error) {
    console.error('Error fetching GitHub repositories:', error);
    res.status(500).json({ error: 'Failed to fetch GitHub repositories' });
  }
});

// Apple subscriptions endpoints
app.get('/api/apple-subscriptions', async (req, res) => {
  try {
    console.log('📱 Fetching Apple subscriptions...');
    
    if (!db) {
      console.error('❌ Database not initialized');
      return res.status(500).json({ error: 'Database not initialized' });
    }
    
    const subscriptions = [];
    
    // Try different possible collection names for Apple subscriptions
    const possibleCollections = ['apple_subscriptions', 'subscriptions', 'purchases', 'apple_receipts'];
    
    for (const collectionName of possibleCollections) {
      try {
        const snapshot = await db.collection(collectionName).get();
        if (!snapshot.empty) {
          console.log(`📱 Found ${snapshot.size} documents in ${collectionName}`);
          snapshot.forEach(doc => {
            subscriptions.push({ 
              id: doc.id, 
              collection: collectionName,
              ...doc.data() 
            });
          });
        }
      } catch (error) {
        console.log(`⚠️ Collection ${collectionName} not found or error:`, error.message);
      }
    }
    
    console.log('📱 Total Apple subscriptions found:', subscriptions.length);
    res.json(subscriptions);
  } catch (error) {
    console.error('❌ Error fetching Apple subscriptions:', error);
    res.status(500).json({ 
      error: 'Failed to fetch Apple subscriptions',
      message: error.message 
    });
  }
});

// Apple subscription statistics
app.get('/api/apple-subscriptions/stats', async (req, res) => {
  try {
    console.log('📱 Fetching Apple subscription statistics...');
    
    if (!db) {
      console.error('❌ Database not initialized');
      return res.status(500).json({ error: 'Database not initialized' });
    }

    let totalRevenue = 0;
    let activeSubscriptions = 0;
    let expiredSubscriptions = 0;
    let totalTransactions = 0;
    const productStats = {};
    
    // Check multiple possible collections
    const possibleCollections = ['apple_subscriptions', 'subscriptions', 'purchases', 'apple_receipts'];
    
    for (const collectionName of possibleCollections) {
      try {
        const snapshot = await db.collection(collectionName).get();
        snapshot.forEach(doc => {
          const data = doc.data();
          totalTransactions++;
          
          // Extract revenue information
          if (data.price || data.amount || data.revenue) {
            const amount = data.price || data.amount || data.revenue || 0;
            totalRevenue += parseFloat(amount) || 0;
          }
          
          // Check subscription status
          if (data.status === 'active' || data.isActive === true) {
            activeSubscriptions++;
          } else if (data.status === 'expired' || data.isActive === false) {
            expiredSubscriptions++;
          }
          
          // Product statistics
          const productId = data.productId || data.product_id || data.sku || 'unknown';
          productStats[productId] = (productStats[productId] || 0) + 1;
        });
      } catch (error) {
        console.log(`⚠️ Error processing ${collectionName}:`, error.message);
      }
    }

    const stats = {
      totalRevenue,
      activeSubscriptions,
      expiredSubscriptions,
      totalTransactions,
      productStats,
      timestamp: new Date().toISOString()
    };

    console.log('📱 Apple subscription stats:', stats);
    res.json(stats);
  } catch (error) {
    console.error('❌ Error fetching Apple subscription stats:', error);
    res.status(500).json({ 
      error: 'Failed to fetch Apple subscription statistics',
      message: error.message 
    });
  }
});

// Statistics endpoint
app.get('/api/statistics', async (req, res) => {
  try {
    console.log('📊 Fetching statistics data...');
    
    if (!db) {
      console.error('❌ Database not initialized');
      return res.status(500).json({ error: 'Database not initialized' });
    }

    // Get user count
    const usersSnapshot = await db.collection('users').get();
    const totalUsers = usersSnapshot.size;

    // Get subscription count
    const subscriptionsSnapshot = await db.collection('device_subscriptions').get();
    const totalSubscriptions = subscriptionsSnapshot.size;

    // Get points data
    const pointsSnapshot = await db.collection('userPoints').get();
    let totalPoints = 0;
    pointsSnapshot.forEach(doc => {
      const data = doc.data();
      totalPoints += data.points || 0;
    });

    // Get advertisements count
    const adsSnapshot = await db.collection('advertisements').get();
    const totalAds = adsSnapshot.size;

    // Get favorites statistics from userCharacters, userAnimes and users data
    const animeStats = {};
    const characterStats = {};
    const voiceActorStats = {};

    // Get character statistics from userCharacters collection
    const userCharactersSnapshot = await db.collection('userCharacters').get();
    userCharactersSnapshot.forEach(doc => {
      const data = doc.data();
      if (data.name) {
        characterStats[data.name] = (characterStats[data.name] || 0) + 1;
      }
    });

    // Get anime statistics from userAnimes collection
    const userAnimesSnapshot = await db.collection('userAnimes').get();
    userAnimesSnapshot.forEach(doc => {
      const data = doc.data();
      if (data.title) {
        animeStats[data.title] = (animeStats[data.title] || 0) + 1;
      }
    });

    // Get character rankings data (additional source)
    const characterRankingsSnapshot = await db.collection('characterRankings').get();
    characterRankingsSnapshot.forEach(doc => {
      const data = doc.data();
      if (data.characterName) {
        characterStats[data.characterName] = (characterStats[data.characterName] || 0) + 1;
      }
    });

    // Get voice actor statistics from users data
    usersSnapshot.forEach(doc => {
      const data = doc.data();
      
      // Count favorite voice actors
      if (data.favoriteVoiceActors && Array.isArray(data.favoriteVoiceActors)) {
        data.favoriteVoiceActors.forEach(va => {
          if (va) {
            voiceActorStats[va] = (voiceActorStats[va] || 0) + 1;
          }
        });
      }
    });

    const statistics = {
      totalUsers,
      totalSubscriptions,
      totalPoints,
      totalAds,
      animeStats,
      characterStats,
      voiceActorStats,
      hashtagStats: {}, // Placeholder for hashtag stats
      timestamp: new Date().toISOString()
    };

    console.log('📊 Statistics:', statistics);
    res.json(statistics);
  } catch (error) {
    console.error('❌ Error fetching statistics:', error);
    res.status(500).json({ 
      error: 'Failed to fetch statistics',
      message: error.message 
    });
  }
});

// Subscription statistics endpoint
app.get('/api/subscriptions/stats', async (req, res) => {
  try {
    console.log('📊 Fetching subscription statistics...');
    
    if (!db) {
      console.error('❌ Database not initialized');
      return res.status(500).json({ error: 'Database not initialized' });
    }

    // Get all subscription-related data
    const deviceSubscriptionsSnapshot = await db.collection('device_subscriptions').get();
    const subscriptionsSnapshot = await db.collection('subscriptions').get();
    const usersSnapshot = await db.collection('users').get();
    
    let activeSubscriptions = 0;
    let inactiveSubscriptions = 0;
    let paidSubscriptions = 0;
    const uniqueDeviceIds = new Set();
    const uniqueUserIds = new Set();
    const deviceTypes = {};
    
    // Process device_subscriptions collection
    deviceSubscriptionsSnapshot.forEach(doc => {
      const data = doc.data();
      
      // Count unique devices
      if (data.deviceId && data.deviceId !== 'null' && !data.deviceId.startsWith('legacy-')) {
        uniqueDeviceIds.add(data.deviceId);
      }
      
      // Count unique users
      if (data.currentUserId) {
        uniqueUserIds.add(data.currentUserId);
      }
      
      // Count paid subscriptions
      if (data.hasPaid === true) {
        paidSubscriptions++;
      }
      
      // Count active/inactive
      if (data.active === true || data.hasPaid === true) {
        activeSubscriptions++;
      } else {
        inactiveSubscriptions++;
      }
      
      // Count device platforms
      const deviceType = data.platform || 'iOS'; // Default to iOS
      deviceTypes[deviceType] = (deviceTypes[deviceType] || 0) + 1;
    });
    
    // Also process old subscriptions collection
    subscriptionsSnapshot.forEach(doc => {
      const data = doc.data();
      if (data.userId && !uniqueUserIds.has(data.userId)) {
        uniqueUserIds.add(data.userId);
      }
    });
    
    // Count actual unique devices from users collection
    usersSnapshot.forEach(doc => {
      const data = doc.data();
      if (data.deviceId && data.deviceId !== 'null' && !data.deviceId.startsWith('legacy-')) {
        uniqueDeviceIds.add(data.deviceId);
      }
    });

    const stats = {
      total: Math.max(deviceSubscriptionsSnapshot.size, uniqueUserIds.size),
      active: activeSubscriptions,
      inactive: inactiveSubscriptions,
      paid: paidSubscriptions,
      uniqueDevices: uniqueDeviceIds.size,
      uniqueUsers: uniqueUserIds.size,
      deviceTypes,
      timestamp: new Date().toISOString()
    };

    console.log('📊 Subscription stats:', stats);
    console.log('📊 Unique device IDs:', Array.from(uniqueDeviceIds));
    res.json(stats);
  } catch (error) {
    console.error('❌ Error fetching subscription stats:', error);
    res.status(500).json({ 
      error: 'Failed to fetch subscription statistics',
      message: error.message 
    });
  }
});

// Error handling middleware
app.use((error, req, res, next) => {
  console.error('Unhandled error:', error);
  res.status(500).json({ error: 'Internal server error' });
});

// Export the Express API for Vercel
module.exports = app;