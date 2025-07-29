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
      
      // デバイスベースのサブスクリプションデータを取得
      const deviceSubscriptionsSnapshot = await db.collection('device_subscriptions').get();
      const subscriptions = [];
      const processedDevices = new Set();
      
      // device_subscriptionsからデータを処理
      for (const doc of deviceSubscriptionsSnapshot.docs) {
        const subscription = { ...doc.data() };
        processedDevices.add(doc.id);
        
        // currentUserIdを使用してユーザー名とプレミアムステータスを取得
        if (subscription.currentUserId) {
          try {
            const userDoc = await db.collection('users').doc(subscription.currentUserId).get();
            if (userDoc.exists) {
              const userData = userDoc.data();
              subscription.username = userData.username || userData.displayName || '未設定';
              
              // プレミアムユーザー情報を取得
              try {
                const premiumDoc = await db.collection('premiumUsers').doc(subscription.currentUserId).get();
                if (premiumDoc.exists) {
                  const premiumData = premiumDoc.data();
                  subscription.isPremiumUser = premiumData.isPremium || false;
                  subscription.premiumPurchaseDate = premiumData.purchaseDate ? premiumData.purchaseDate.seconds : null;
                } else {
                  subscription.isPremiumUser = false;
                }
              } catch (premiumError) {
                console.log(`プレミアムユーザー情報取得エラー ${subscription.currentUserId}:`, premiumError.message);
                subscription.isPremiumUser = false;
              }
            }
          } catch (error) {
            console.log(`ユーザー ${subscription.currentUserId} の情報取得エラー:`, error.message);
          }
        }
        
        // deviceIdをプライマリIDとして使用
        subscription.userId = subscription.deviceId || doc.id;
        
        subscriptions.push(subscription);
      }
      
      // 移行期間のため、古いsubscriptionsコレクションからもデータを取得
      const oldSubscriptionsSnapshot = await db.collection('subscriptions').get();
      for (const doc of oldSubscriptionsSnapshot.docs) {
        const oldSub = doc.data();
        
        // deviceIdが既に処理されている場合はスキップ
        if (oldSub.deviceId && processedDevices.has(oldSub.deviceId)) {
          continue;
        }
        
        // ユーザー名とプレミアムステータスを取得
        const userId = oldSub.userId || doc.id;
        try {
          const userDoc = await db.collection('users').doc(userId).get();
          if (userDoc.exists) {
            const userData = userDoc.data();
            oldSub.username = userData.username || userData.displayName || '未設定';
            oldSub.deviceId = userData.deviceId || 'legacy-' + userId.substring(0, 8);
            
            // プレミアムユーザー情報を取得
            try {
              const premiumDoc = await db.collection('premiumUsers').doc(userId).get();
              if (premiumDoc.exists) {
                const premiumData = premiumDoc.data();
                oldSub.isPremiumUser = premiumData.isPremium || false;
                oldSub.premiumPurchaseDate = premiumData.purchaseDate ? premiumData.purchaseDate.seconds : null;
              } else {
                oldSub.isPremiumUser = false;
              }
            } catch (premiumError) {
              console.log(`プレミアムユーザー情報取得エラー ${userId}:`, premiumError.message);
              oldSub.isPremiumUser = false;
            }
          }
        } catch (error) {
          console.log(`ユーザー ${userId} の情報取得エラー:`, error.message);
        }
        
        // 古いデータもdeviceIdベースの形式に変換
        const subscription = {
          userId: oldSub.deviceId || userId,
          deviceId: oldSub.deviceId || null,
          currentUserId: userId,
          username: oldSub.username || '未設定',
          firstInstallDate: oldSub.firstInstallDate || oldSub.createdAt,
          hasPaid: oldSub.hasPaid || false,
          paymentDate: oldSub.paymentDate,
          amount: oldSub.amount,
          createdAt: oldSub.createdAt,
          lastSeenAt: oldSub.updatedAt || oldSub.createdAt,
          isPremiumUser: oldSub.isPremiumUser || false,
          premiumPurchaseDate: oldSub.premiumPurchaseDate || null
        };
        
        subscriptions.push(subscription);
      }
      
      // サブスクリプションレコードがないユーザーも表示
      const usersSnapshot = await db.collection('users').get();
      const processedUserIds = new Set(subscriptions.map(s => s.currentUserId || s.userId));
      
      for (const userDoc of usersSnapshot.docs) {
        const userData = userDoc.data();
        const userId = userDoc.id;
        
        if (processedUserIds.has(userId)) {
          continue;
        }
        
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
          }
        } catch (premiumError) {
          console.log(`プレミアムユーザー情報取得エラー ${userId}:`, premiumError.message);
        }
        
        const subscription = {
          userId: userId,
          deviceId: userData.deviceId || null,
          currentUserId: userId,
          username: userData.username || userData.displayName || '未設定',
          firstInstallDate,
          hasPaid: userData.hasPaidSubscription || false,
          paymentDate: userData.subscriptionDate?.seconds || userData.subscriptionDate || null,
          amount: userData.hasPaidSubscription ? 500 : null,
          createdAt,
          lastSeenAt,
          isPremiumUser,
          premiumPurchaseDate
        };
        
        subscriptions.push(subscription);
      }
      
      // 初回インストール日でソート（新しい順）
      subscriptions.sort((a, b) => (b.firstInstallDate || 0) - (a.firstInstallDate || 0));
      
      console.log(`🔥 Returning ${subscriptions.length} subscription records`);
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