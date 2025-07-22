const admin = require('firebase-admin');
require('dotenv').config();

// Firebase Admin初期化
let adminApp;
try {
  const serviceAccount = require('./serviceAccountKey.json');
  adminApp = admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  }, 'migration');
} catch (error) {
  console.log('Firebase Admin SDK初期化エラー:', error.message);
  process.exit(1);
}

const db = adminApp.firestore();

async function migrateVoiceActors() {
  console.log('🎭 声優データ移行開始...');
  
  try {
    // userCharactersからvoiceActorデータを取得
    const charactersSnapshot = await db.collection('userCharacters').get();
    console.log(`📚 userCharactersコレクション: ${charactersSnapshot.docs.length}件`);
    
    const voiceActorsByUser = new Map();
    
    charactersSnapshot.docs.forEach(doc => {
      const data = doc.data();
      if (data.voiceActor && data.voiceActor.trim() && data.userId) {
        const userId = data.userId;
        const voiceActor = data.voiceActor.trim();
        
        if (!voiceActorsByUser.has(userId)) {
          voiceActorsByUser.set(userId, new Set());
        }
        voiceActorsByUser.get(userId).add(voiceActor);
        
        console.log(`👤 ユーザー ${userId}: 声優 "${voiceActor}" を追加`);
      }
    });
    
    console.log(`🎭 ${voiceActorsByUser.size}人のユーザーから声優データを発見`);
    
    // userVoiceActorsコレクションに保存
    let totalSaved = 0;
    for (const [userId, voiceActors] of voiceActorsByUser) {
      console.log(`💾 ユーザー ${userId} の声優データ保存中...`);
      
      for (const [index, voiceActor] of Array.from(voiceActors).entries()) {
        const voiceActorRef = db.collection('userVoiceActors').doc(`${userId}_${index}`);
        const voiceActorData = {
          userId: userId,
          voiceActorId: voiceActor + '_' + Date.now(),
          name: voiceActor,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
          updatedAt: admin.firestore.FieldValue.serverTimestamp()
        };
        
        await voiceActorRef.set(voiceActorData);
        console.log(`✅ 保存完了: ユーザー ${userId} -> 声優 "${voiceActor}"`);
        totalSaved++;
      }
    }
    
    console.log(`🎉 移行完了! 合計 ${totalSaved}件の声優データを移行しました`);
    
  } catch (error) {
    console.error('❌ 移行エラー:', error);
  }
  
  process.exit(0);
}

migrateVoiceActors();