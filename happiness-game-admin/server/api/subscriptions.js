const admin = require('firebase-admin');

// Firebase Admin初期化
if (admin.apps.length === 0) {
  try {
    let serviceAccount;
    
    if (process.env.FIREBASE_SERVICE_ACCOUNT) {
      serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
    } else {
      throw new Error('FIREBASE_SERVICE_ACCOUNT environment variable not found');
    }
    
    admin.initializeApp({
      credential: admin.credential.cert(serviceAccount),
      projectId: serviceAccount.project_id || 'ani-reco'
    });
  } catch (error) {
    console.error('Firebase Admin SDK initialization error:', error.message);
    throw error;
  }
}

const db = admin.firestore();

module.exports = async function handler(req, res) {
  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.status(200).end();
    return;
  }

  if (req.method === 'GET') {
    try {
      console.log('🔥 /api/subscriptions endpoint called');
      
      const subscriptions = [];
      const processedUserIds = new Set();
      
      // まずusersコレクションから全ユーザーを取得
      const usersSnapshot = await db.collection('users').get();
      console.log(`🔥 Found ${usersSnapshot.size} users in users collection`);
      
      // 各ユーザーの情報を処理
      for (const userDoc of usersSnapshot.docs) {
        const userData = userDoc.data();
        const userId = userDoc.id;
        
        console.log(`🔍 Processing user ${userId}:`, {
          username: userData.username,
          hasPaidSubscription: userData.hasPaidSubscription,
          deviceId: userData.deviceId
        });
        
        // 初回インストール日時を取得
        let firstInstallDate = Math.floor(Date.now() / 1000) - 86400;
        let createdAt = firstInstallDate;
        let lastSeenAt = Math.floor(Date.now() / 1000);
        
        if (userData.createdAt) {
          if (userData.createdAt.seconds) {
            firstInstallDate = userData.createdAt.seconds;
            createdAt = userData.createdAt.seconds;
          } else if (typeof userData.createdAt === 'number') {
            firstInstallDate = userData.createdAt;
            createdAt = userData.createdAt;
          }
        }
        
        if (userData.updatedAt?.seconds) {
          lastSeenAt = userData.updatedAt.seconds;
        } else if (userData.lastLoginAt?.seconds) {
          lastSeenAt = userData.lastLoginAt.seconds;
        }
        
        // プレミアムユーザー情報を取得
        let isPremiumUser = false;
        let premiumPurchaseDate = null;
        try {
          const premiumDoc = await db.collection('premiumUsers').doc(userId).get();
          if (premiumDoc.exists) {
            const premiumData = premiumDoc.data();
            isPremiumUser = premiumData.isPremium || false;
            premiumPurchaseDate = premiumData.purchaseDate ? premiumData.purchaseDate.seconds : null;
            console.log(`🔍 Premium status for ${userId}: ${isPremiumUser}`);
          }
        } catch (premiumError) {
          console.log(`プレミアムユーザー情報取得エラー ${userId}:`, premiumError.message);
        }
        
        // hasPaidはuserデータまたはpremiumUsersデータのいずれかがtrueならtrue
        const hasPaid = userData.hasPaidSubscription || isPremiumUser || false;
        
        const subscription = {
          userId: userId,
          deviceId: userData.deviceId || userId,  // deviceIdがない場合はuserIdを使用
          currentUserId: userId,
          username: userData.username || userData.displayName || '未設定',
          firstInstallDate,
          hasPaid,
          paymentDate: userData.subscriptionDate?.seconds || userData.subscriptionDate || premiumPurchaseDate || null,
          amount: hasPaid ? 600 : null,
          createdAt,
          lastSeenAt,
          isPremiumUser,
          premiumPurchaseDate
        };
        
        subscriptions.push(subscription);
        processedUserIds.add(userId);
      }
      
      // device_subscriptionsコレクションがある場合は追加で取得（エラーは無視）
      try {
        const deviceSubscriptionsSnapshot = await db.collection('device_subscriptions').get();
        console.log(`🔥 Found ${deviceSubscriptionsSnapshot.size} device_subscriptions`);
        
        for (const doc of deviceSubscriptionsSnapshot.docs) {
          const deviceData = doc.data();
          const deviceId = doc.id;
          
          // 既に処理済みのユーザーはスキップ
          if (deviceData.currentUserId && processedUserIds.has(deviceData.currentUserId)) {
            continue;
          }
          
          // デバイス情報から新しいサブスクリプションレコードを作成
          if (deviceData.currentUserId) {
            const existingIndex = subscriptions.findIndex(s => s.currentUserId === deviceData.currentUserId);
            if (existingIndex >= 0) {
              // 既存のレコードを更新
              subscriptions[existingIndex].deviceId = deviceId;
              if (deviceData.hasPaid) {
                subscriptions[existingIndex].hasPaid = true;
              }
            }
          }
        }
      } catch (deviceError) {
        console.log('device_subscriptions取得エラー（無視）:', deviceError.message);
      }
      
      // 初回インストール日でソート（新しい順）
      subscriptions.sort((a, b) => (b.firstInstallDate || 0) - (a.firstInstallDate || 0));
      
      console.log(`🔥 Returning ${subscriptions.length} subscription records`);
      console.log(`🔥 Premium users: ${subscriptions.filter(s => s.isPremiumUser).length}`);
      console.log(`🔥 Paid users: ${subscriptions.filter(s => s.hasPaid).length}`);
      
      res.json(subscriptions);
    } catch (error) {
      console.error('サブスクリプション取得エラー:', error);
      res.status(500).json({ error: error.message });
    }
  } else if (req.method === 'POST') {
    // サブスクリプションステータスのトグル
    try {
      const { userId, hasPaid } = req.body;
      
      if (!userId) {
        return res.status(400).json({ error: 'デバイスIDが必要です' });
      }
      
      // デバイスIDでサブスクリプション情報を更新
      const subscriptionRef = db.collection('device_subscriptions').doc(userId);
      const subscriptionDoc = await subscriptionRef.get();
      
      if (!subscriptionDoc.exists) {
        return res.status(404).json({ error: 'デバイスが見つかりません' });
      }
      
      const subscriptionData = {
        hasPaid,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      };
      
      if (hasPaid) {
        subscriptionData.paymentDate = Math.floor(Date.now() / 1000);
        subscriptionData.amount = 500;
      } else {
        subscriptionData.paymentDate = null;
        subscriptionData.amount = null;
      }
      
      await subscriptionRef.update(subscriptionData);
      
      // 現在のユーザーデータも更新
      const currentUserId = subscriptionDoc.data().currentUserId;
      if (currentUserId) {
        const userRef = db.collection('users').doc(currentUserId);
        const userDoc = await userRef.get();
        if (userDoc.exists) {
          await userRef.update({
            hasPaidSubscription: hasPaid,
            subscriptionUpdatedAt: admin.firestore.FieldValue.serverTimestamp()
          });
        }
      }
      
      res.json({ 
        success: true, 
        message: `デバイス ${userId} のサブスクリプションステータスを更新しました`,
        hasPaid 
      });
    } catch (error) {
      console.error('サブスクリプショントグルエラー:', error);
      res.status(500).json({ error: error.message });
    }
  } else {
    res.status(405).json({ error: 'Method not allowed' });
  }
}