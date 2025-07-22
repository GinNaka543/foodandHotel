// Direct Firebase test using admin SDK
const admin = require('firebase-admin');

async function testDirectFirebaseSave() {
  try {
    // Use the same serviceAccount as the server
    const serviceAccount = require('./happiness-game-admin/server/serviceAccountKey.json');
    
    // Initialize Firebase Admin if not already initialized
    if (!admin.apps.length) {
      admin.initializeApp({
        credential: admin.credential.cert(serviceAccount)
      });
    }
    
    const db = admin.firestore();
    
    // Test data with streamingUrls
    const testPlan = {
      title: "Direct Firebase Test",
      animeName: "Test Anime",
      duration: "1時間",
      streamingUrls: [
        { name: "Netflix", url: "https://netflix.com/test" },
        { name: "Hulu", url: "https://hulu.com/test" }
      ],
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    };
    
    console.log('🔬 Direct Firebase test - saving data:');
    console.log('streamingUrls:', JSON.stringify(testPlan.streamingUrls, null, 2));
    
    // Save to Firebase
    const docRef = db.collection('visitPlans').doc('direct_test_plan');
    await docRef.set(testPlan);
    
    // Read back from Firebase
    const savedDoc = await docRef.get();
    if (savedDoc.exists) {
      const savedData = savedDoc.data();
      console.log('✅ Direct Firebase save successful!');
      console.log('Retrieved streamingUrls:', savedData.streamingUrls);
      console.log('All fields:', Object.keys(savedData).join(', '));
      
      // Clean up
      await docRef.delete();
      console.log('🗑️ Test document deleted');
    } else {
      console.error('❌ Document not found after save');
    }
    
  } catch (error) {
    console.error('❌ Direct Firebase test failed:', error.message);
    console.error('Stack trace:', error.stack);
  }
}

testDirectFirebaseSave();