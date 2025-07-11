const express = require('express');
const cors = require('cors');
const bodyParser = require('body-parser');
const admin = require('firebase-admin');
require('dotenv').config();
const axios = require('axios');
const cheerio = require('cheerio');

const app = express();
const PORT = process.env.PORT || 5002;

// Middleware
app.use(cors());
app.use(bodyParser.json());
app.use(bodyParser.urlencoded({ extended: true }));

// Firebase Admin初期化
// 開発環境用の設定
let adminApp;
try {
  const serviceAccount = require('./serviceAccountKey.json');
  adminApp = admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
} catch (error) {
  console.log('Firebase Admin SDK初期化エラー:', error.message);
  console.log('開発環境用のダミー設定を使用します');
  // 開発環境用のダミー設定
  adminApp = admin.initializeApp({
    projectId: 'ani-reco'
  });
}

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
    for (const doc of usersSnapshot.docs) {
      const user = { id: doc.id, ...doc.data() };
      // userAnimesから取得
      const animesSnapshot = await db.collection('userAnimes').where('userId', '==', user.id).get();
      user.favoriteAnimes = animesSnapshot.docs.map(a => a.data().title || a.data().animeId);
      // userCharactersから取得
      const charactersSnapshot = await db.collection('userCharacters').where('userId', '==', user.id).get();
      user.favoriteCharacters = charactersSnapshot.docs.map(c => c.data().name || c.data().characterId);
      // ハッシュタグ（userAnimes, userCharacters両方から集約）
      const animeTags = animesSnapshot.docs.map(a => a.data().hashtag).filter(Boolean);
      const characterTags = charactersSnapshot.docs.map(c => c.data().tag).filter(Boolean);
      user.hashtags = Array.from(new Set([...animeTags, ...characterTags]));
      users.push(user);
    }
    res.json(users);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// 特定のアニメ/キャラクター/タグでユーザーを検索
app.get('/api/users/search', async (req, res) => {
  try {
    const { all, anime, character, hashtag } = req.query;
    console.log('検索条件:', { all, anime, character, hashtag });
    const usersSnapshot = await db.collection('users').get();
    const users = [];
    for (const doc of usersSnapshot.docs) {
      const user = { id: doc.id, ...doc.data() };
      // userAnimesから取得
      const animesSnapshot = await db.collection('userAnimes').where('userId', '==', user.id).get();
      user.favoriteAnimes = animesSnapshot.docs.map(a => a.data().title || a.data().animeId);
      // userCharactersから取得
      const charactersSnapshot = await db.collection('userCharacters').where('userId', '==', user.id).get();
      user.favoriteCharacters = charactersSnapshot.docs.map(c => c.data().name || c.data().characterId);
      // ハッシュタグ（userAnimes, userCharacters両方から集約）
      const animeTags = animesSnapshot.docs.map(a => a.data().hashtag).filter(Boolean);
      const characterTags = charactersSnapshot.docs.map(c => c.data().tag).filter(Boolean);
      user.hashtags = Array.from(new Set([...animeTags, ...characterTags]));
      // デバッグ出力
      console.log('ユーザー:', user.username || user.id);
      console.log('  favoriteAnimes:', user.favoriteAnimes);
      console.log('  favoriteCharacters:', user.favoriteCharacters);
      console.log('  hashtags:', user.hashtags);
      // 検索条件に合致するか
      let match = true;
      
      // 全てで検索（ユーザー名、キャラクター、アニメ、ハッシュタグを含む）
      if (all) {
        const searchTerm = all.toLowerCase();
        const userMatch = 
          (user.username && user.username.toLowerCase().includes(searchTerm)) ||
          (user.favoriteAnimes && user.favoriteAnimes.some(anime => anime && anime.toLowerCase().includes(searchTerm))) ||
          (user.favoriteCharacters && user.favoriteCharacters.some(char => char && char.toLowerCase().includes(searchTerm))) ||
          (user.hashtags && user.hashtags.some(tag => tag && tag.toLowerCase().includes(searchTerm)));
        
        if (!userMatch) match = false;
      }
      
      if (anime) {
        const animeStr = (user.favoriteAnimes || []).filter(a => !!a && isNaN(a)).join(' ').toLowerCase();
        if (!animeStr.includes(anime.toLowerCase())) match = false;
      }
      if (character) {
        const charStr = (user.favoriteCharacters || []).filter(c => !!c && isNaN(c)).join(' ').toLowerCase();
        if (!charStr.includes(character.toLowerCase())) match = false;
      }
      if (hashtag) {
        const tagStr = (user.hashtags || []).filter(h => !!h).join(' ').toLowerCase();
        if (!tagStr.includes(hashtag.toLowerCase())) match = false;
      }
      console.log('  match:', match);
      if (match) users.push(user);
    }
    res.json(users);
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
      expiresAt,
      placements,
      displayRate,
      priority
    } = req.body;

    // 既存の広告を取得して重複をチェック
    const existingAdsSnapshot = await db.collection('advertisements').where('isActive', '==', true).get();
    const existingAds = [];
    existingAdsSnapshot.forEach(doc => {
      existingAds.push({ id: doc.id, ...doc.data() });
    });

    // ビジットページのターゲット広告の重複チェック
    if (placements && placements.includes('visit')) {
      // ターゲット広告の場合
      if ((targetAnimes && targetAnimes.length > 0) || 
          (targetCharacters && targetCharacters.length > 0) || 
          (targetHashtags && targetHashtags.length > 0)) {
        
        for (const ad of existingAds) {
          if (!ad.placements || !ad.placements.includes('visit')) continue;
          
          // 同じアニメをターゲットにしている広告があるかチェック
          if (targetAnimes && targetAnimes.length > 0 && ad.targetAnimes && ad.targetAnimes.length > 0) {
            const duplicateAnime = targetAnimes.find(anime => ad.targetAnimes.includes(anime));
            if (duplicateAnime) {
              return res.status(400).json({ 
                error: `既に「${duplicateAnime}」をターゲットにしたビジットページの広告が存在します。1つのターゲットに対して1つの広告のみ作成可能です。` 
              });
            }
          }
          
          // 同じキャラクターをターゲットにしている広告があるかチェック
          if (targetCharacters && targetCharacters.length > 0 && ad.targetCharacters && ad.targetCharacters.length > 0) {
            const duplicateChar = targetCharacters.find(char => ad.targetCharacters.includes(char));
            if (duplicateChar) {
              return res.status(400).json({ 
                error: `既に「${duplicateChar}」をターゲットにしたビジットページの広告が存在します。1つのターゲットに対して1つの広告のみ作成可能です。` 
              });
            }
          }
          
          // 同じハッシュタグをターゲットにしている広告があるかチェック
          if (targetHashtags && targetHashtags.length > 0 && ad.targetHashtags && ad.targetHashtags.length > 0) {
            const duplicateTag = targetHashtags.find(tag => ad.targetHashtags.includes(tag));
            if (duplicateTag) {
              return res.status(400).json({ 
                error: `既に「#${duplicateTag}」をターゲットにしたビジットページの広告が存在します。1つのターゲットに対して1つの広告のみ作成可能です。` 
              });
            }
          }
        }
      }
    }

    const advertisement = {
      title,
      description,
      imageURL,
      linkURL,
      targetAnimes: targetAnimes || [],
      targetCharacters: targetCharacters || [],
      targetHashtags: targetHashtags || [],
      placements: placements || [],
      displayRate: displayRate || 100,
      priority: priority || 5,
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
    
    // ビジットページのターゲット広告の重複チェック（更新時）
    if (updateData.placements && updateData.placements.includes('visit') && 
        updateData.targetAnimes !== undefined && updateData.targetCharacters !== undefined && updateData.targetHashtags !== undefined) {
      
      const { targetAnimes, targetCharacters, targetHashtags } = updateData;
      
      // ターゲット広告の場合のみチェック
      if ((targetAnimes && targetAnimes.length > 0) || 
          (targetCharacters && targetCharacters.length > 0) || 
          (targetHashtags && targetHashtags.length > 0)) {
        
        // 既存の広告を取得（自分自身を除く）
        const existingAdsSnapshot = await db.collection('advertisements')
          .where('isActive', '==', true)
          .get();
        
        for (const doc of existingAdsSnapshot.docs) {
          if (doc.id === id) continue; // 自分自身はスキップ
          
          const ad = doc.data();
          if (!ad.placements || !ad.placements.includes('visit')) continue;
          
          // 同じアニメをターゲットにしている広告があるかチェック
          if (targetAnimes && targetAnimes.length > 0 && ad.targetAnimes && ad.targetAnimes.length > 0) {
            const duplicateAnime = targetAnimes.find(anime => ad.targetAnimes.includes(anime));
            if (duplicateAnime) {
              return res.status(400).json({ 
                error: `既に「${duplicateAnime}」をターゲットにしたビジットページの広告が存在します。1つのターゲットに対して1つの広告のみ作成可能です。` 
              });
            }
          }
          
          // 同じキャラクターをターゲットにしている広告があるかチェック
          if (targetCharacters && targetCharacters.length > 0 && ad.targetCharacters && ad.targetCharacters.length > 0) {
            const duplicateChar = targetCharacters.find(char => ad.targetCharacters.includes(char));
            if (duplicateChar) {
              return res.status(400).json({ 
                error: `既に「${duplicateChar}」をターゲットにしたビジットページの広告が存在します。1つのターゲットに対して1つの広告のみ作成可能です。` 
              });
            }
          }
          
          // 同じハッシュタグをターゲットにしている広告があるかチェック
          if (targetHashtags && targetHashtags.length > 0 && ad.targetHashtags && ad.targetHashtags.length > 0) {
            const duplicateTag = targetHashtags.find(tag => ad.targetHashtags.includes(tag));
            if (duplicateTag) {
              return res.status(400).json({ 
                error: `既に「#${duplicateTag}」をターゲットにしたビジットページの広告が存在します。1つのターゲットに対して1つの広告のみ作成可能です。` 
              });
            }
          }
        }
      }
    }
    
    await db.collection('advertisements').doc(id).update({
      ...updateData,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    res.json({ message: 'Advertisement updated successfully' });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// 広告を削除（非アクティブ化 or 完全削除）
app.delete('/api/advertisements/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const force = req.query.force === 'true';
    if (force) {
      await db.collection('advertisements').doc(id).delete();
      res.json({ message: 'Advertisement deleted permanently' });
    } else {
      await db.collection('advertisements').doc(id).update({
        isActive: false,
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
      res.json({ message: 'Advertisement deactivated successfully' });
    }
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// 画像抽出API
app.get('/api/extract-image', async (req, res) => {
  const { url } = req.query;
  if (!url) return res.status(400).json({ error: 'url is required' });
  try {
    const response = await axios.get(url, { headers: { 'User-Agent': 'Mozilla/5.0' } });
    const html = response.data;
    const $ = cheerio.load(html);
    // 1. OGP画像
    let imgUrl = $('meta[property="og:image"]').attr('content');
    // 2. imgタグ
    if (!imgUrl) {
      imgUrl = $('img').first().attr('src');
    }
    // 3. imgurの相対パス対応
    if (imgUrl && imgUrl.startsWith('//')) {
      imgUrl = 'https:' + imgUrl;
    }
    if (imgUrl && !/^https?:/.test(imgUrl)) {
      // 相対パスの場合は元URLから解決
      const u = new URL(url);
      imgUrl = u.origin + (imgUrl.startsWith('/') ? imgUrl : '/' + imgUrl);
    }
    if (imgUrl) {
      res.json({ imageUrl: imgUrl });
    } else {
      res.status(404).json({ error: 'No image found' });
    }
  } catch (e) {
    res.status(500).json({ error: 'Failed to fetch or parse HTML' });
  }
});

// GitHubリポジトリ管理のエンドポイント
// リポジトリ一覧を取得
app.get('/api/github-repositories', async (req, res) => {
  try {
    const settingsDoc = await db.collection('githubSettings').doc('repositories').get();
    if (!settingsDoc.exists) {
      return res.json({ repositories: [], activeRepoId: null });
    }
    const data = settingsDoc.data();
    res.json({
      repositories: data.repositories || [],
      activeRepoId: data.activeRepoId || null
    });
  } catch (error) {
    console.error('リポジトリ取得エラー:', error);
    res.status(500).json({ error: error.message });
  }
});

// 新規リポジトリを追加
app.post('/api/github-repositories', async (req, res) => {
  try {
    const { owner, name, token, branch, basePath } = req.body;
    
    if (!owner || !name || !token) {
      return res.status(400).json({ error: '必須フィールドが不足しています' });
    }

    const newRepo = {
      id: Date.now().toString(),
      owner,
      name,
      token,
      branch: branch || 'main',
      basePath: basePath || 'visit-plans',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      isActive: true,
      currentSize: 0,
      maxSize: 10737418240, // 10GB
      imageCount: 0
    };

    const settingsRef = db.collection('githubSettings').doc('repositories');
    const settingsDoc = await settingsRef.get();
    
    if (settingsDoc.exists) {
      const data = settingsDoc.data();
      const repositories = data.repositories || [];
      repositories.push(newRepo);
      
      await settingsRef.update({
        repositories,
        activeRepoId: data.activeRepoId || newRepo.id
      });
    } else {
      await settingsRef.set({
        repositories: [newRepo],
        activeRepoId: newRepo.id
      });
    }

    res.json({ success: true, repository: newRepo });
  } catch (error) {
    console.error('リポジトリ追加エラー:', error);
    res.status(500).json({ error: error.message });
  }
});

// リポジトリを更新
app.put('/api/github-repositories/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const { owner, name, token, branch, basePath } = req.body;
    
    const settingsRef = db.collection('githubSettings').doc('repositories');
    const settingsDoc = await settingsRef.get();
    
    if (!settingsDoc.exists) {
      return res.status(404).json({ error: 'リポジトリ設定が見つかりません' });
    }
    
    const data = settingsDoc.data();
    const repositories = data.repositories || [];
    const repoIndex = repositories.findIndex(r => r.id === id);
    
    if (repoIndex === -1) {
      return res.status(404).json({ error: 'リポジトリが見つかりません' });
    }
    
    repositories[repoIndex] = {
      ...repositories[repoIndex],
      owner,
      name,
      token,
      branch,
      basePath
    };
    
    await settingsRef.update({ repositories });
    res.json({ success: true, repository: repositories[repoIndex] });
  } catch (error) {
    console.error('リポジトリ更新エラー:', error);
    res.status(500).json({ error: error.message });
  }
});

// リポジトリを削除
app.delete('/api/github-repositories/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    const settingsRef = db.collection('githubSettings').doc('repositories');
    const settingsDoc = await settingsRef.get();
    
    if (!settingsDoc.exists) {
      return res.status(404).json({ error: 'リポジトリ設定が見つかりません' });
    }
    
    const data = settingsDoc.data();
    const repositories = data.repositories || [];
    const filteredRepos = repositories.filter(r => r.id !== id);
    
    if (data.activeRepoId === id && filteredRepos.length > 0) {
      // 削除されたリポジトリがアクティブだった場合、別のリポジトリをアクティブに
      data.activeRepoId = filteredRepos[0].id;
    }
    
    await settingsRef.update({
      repositories: filteredRepos,
      activeRepoId: data.activeRepoId === id ? (filteredRepos[0]?.id || null) : data.activeRepoId
    });
    
    res.json({ success: true });
  } catch (error) {
    console.error('リポジトリ削除エラー:', error);
    res.status(500).json({ error: error.message });
  }
});

// アクティブリポジトリを切り替え
app.post('/api/github-repositories/:id/activate', async (req, res) => {
  try {
    const { id } = req.params;
    
    const settingsRef = db.collection('githubSettings').doc('repositories');
    await settingsRef.update({ activeRepoId: id });
    
    res.json({ success: true });
  } catch (error) {
    console.error('アクティブ化エラー:', error);
    res.status(500).json({ error: error.message });
  }
});

// リポジトリ容量を更新
app.post('/api/github-repositories/refresh-capacity', async (req, res) => {
  try {
    const settingsDoc = await db.collection('githubSettings').doc('repositories').get();
    if (!settingsDoc.exists) {
      return res.status(404).json({ error: 'リポジトリ設定が見つかりません' });
    }
    
    const data = settingsDoc.data();
    const repositories = data.repositories || [];
    
    // 各リポジトリの容量をGitHub APIから取得
    const updatedRepos = await Promise.all(repositories.map(async (repo) => {
      try {
        const response = await axios.get(
          `https://api.github.com/repos/${repo.owner}/${repo.name}`,
          {
            headers: {
              'Authorization': `Bearer ${repo.token}`,
              'Accept': 'application/vnd.github.v3+json'
            }
          }
        );
        
        return {
          ...repo,
          currentSize: response.data.size * 1024, // KBをバイトに変換
          usagePercentage: (response.data.size * 1024 / repo.maxSize) * 100
        };
      } catch (error) {
        console.error(`リポジトリ ${repo.owner}/${repo.name} の容量取得エラー:`, error.message);
        return repo;
      }
    }));
    
    await db.collection('githubSettings').doc('repositories').update({
      repositories: updatedRepos,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp()
    });
    
    res.json({ success: true, repositories: updatedRepos });
  } catch (error) {
    console.error('容量更新エラー:', error);
    res.status(500).json({ error: error.message });
  }
});

// 統計情報を取得
app.get('/api/statistics', async (req, res) => {
  try {
    // 開発環境用のダミーデータ
    const usersSnapshot = await db.collection('users').get();
    const adsSnapshot = await db.collection('advertisements').get();
    const animeStats = {
      'アニメ1': 2,
      'アニメ2': 2,
      'アニメ3': 2
    };
    const characterStats = {
      'キャラクター1': 1,
      'キャラクター2': 1
    };
    const hashtagStats = {
      '#ハッシュタグ1': 1,
      '#ハッシュタグ2': 1
    };
    
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