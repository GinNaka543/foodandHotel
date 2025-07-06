const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const admin = require('firebase-admin');
require('dotenv').config();

const app = express();
const PORT = process.env.PORT || 5000;

// Middleware
app.use(cors());
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// Firebase Admin初期化
// 注意: Firebase Admin SDKの秘密鍵JSONファイルが必要です
// Firebase Consoleからダウンロードして、serviceAccountKey.jsonとして保存してください
const serviceAccount = require('./serviceAccountKey.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

// ルート
app.get('/', (req, res) => {
  res.json({ message: 'Happiness Game Admin API' });
});

// すべてのユーザーを取得
app.get('/api/users', async (req, res) => {
  try {
    const usersSnapshot = await db.collection('users').get();
    const users = [];
    usersSnapshot.forEach(doc => {
      users.push({ id: doc.id, ...doc.data() });
    });
    res.json(users);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// 特定のアニメ/キャラクター/タグでユーザーを検索
app.get('/api/users/search', async (req, res) => {
  try {
    const { anime, character, hashtag } = req.query;
    let users = new Set();

    if (anime) {
      const animeDoc = await db.collection('animeIndex').doc(anime).get();
      if (animeDoc.exists) {
        const data = animeDoc.data();
        data.users.forEach(userId => users.add(userId));
      }
    }

    if (character) {
      const characterDoc = await db.collection('characterIndex').doc(character).get();
      if (characterDoc.exists) {
        const data = characterDoc.data();
        data.users.forEach(userId => users.add(userId));
      }
    }

    if (hashtag) {
      const hashtagDoc = await db.collection('hashtagIndex').doc(hashtag).get();
      if (hashtagDoc.exists) {
        const data = hashtagDoc.data();
        data.users.forEach(userId => users.add(userId));
      }
    }

    // ユーザー詳細を取得
    const userDetails = [];
    for (const userId of users) {
      const userDoc = await db.collection('users').doc(userId).get();
      if (userDoc.exists) {
        userDetails.push({ id: userDoc.id, ...userDoc.data() });
      }
    }

    res.json(userDetails);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// 広告を作成
app.post('/api/advertisements', async (req, res) => {
  try {
    const {
      title,
      description,
      imageURL,
      linkURL,
      targetAnimes,
      targetCharacters,
      targetHashtags,
      expiresAt
    } = req.body;

    const advertisement = {
      title,
      description,
      imageURL,
      linkURL,
      targetAnimes: targetAnimes || [],
      targetCharacters: targetCharacters || [],
      targetHashtags: targetHashtags || [],
      impressions: 0,
      clicks: 0,
      isActive: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: expiresAt ? new Date(expiresAt) : null
    };

    const docRef = await db.collection('advertisements').add(advertisement);
    res.json({ id: docRef.id, ...advertisement });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// すべての広告を取得
app.get('/api/advertisements', async (req, res) => {
  try {
    const adsSnapshot = await db.collection('advertisements').get();
    const ads = [];
    adsSnapshot.forEach(doc => {
      ads.push({ id: doc.id, ...doc.data() });
    });
    res.json(ads);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// 広告を更新
app.put('/api/advertisements/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const updateData = req.body;
    
    await db.collection('advertisements').doc(id).update({
      ...updateData,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    res.json({ message: 'Advertisement updated successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// 広告を削除（非アクティブ化）
app.delete('/api/advertisements/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    await db.collection('advertisements').doc(id).update({
      isActive: false,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    res.json({ message: 'Advertisement deactivated successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// 統計情報を取得
app.get('/api/statistics', async (req, res) => {
  try {
    const usersSnapshot = await db.collection('users').get();
    const adsSnapshot = await db.collection('advertisements').get();
    
    // アニメ別ユーザー数
    const animeStats = {};
    const characterStats = {};
    const hashtagStats = {};
    
    usersSnapshot.forEach(doc => {
      const user = doc.data();
      
      (user.favoriteAnimes || []).forEach(anime => {
        animeStats[anime] = (animeStats[anime] || 0) + 1;
      });
      
      (user.favoriteCharacters || []).forEach(character => {
        characterStats[character] = (characterStats[character] || 0) + 1;
      });
      
      (user.hashtags || []).forEach(hashtag => {
        hashtagStats[hashtag] = (hashtagStats[hashtag] || 0) + 1;
      });
    });
    
    res.json({
      totalUsers: usersSnapshot.size,
      totalAds: adsSnapshot.size,
      animeStats,
      characterStats,
      hashtagStats
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});