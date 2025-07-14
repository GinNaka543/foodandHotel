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
app.use(bodyParser.json({ limit: '50mb' }));
app.use(bodyParser.urlencoded({ extended: true, limit: '50mb' }));

// Debug middleware to log all requests
app.use((req, res, next) => {
  if (req.method === 'POST') {
    if (req.url.includes('/custom-rankings') || req.url.includes('/admin/add-points')) {
      console.log(`=== DEBUG: ${req.url} Request ===`);
      console.log('URL:', req.url);
      console.log('Body:', JSON.stringify(req.body, null, 2));
      console.log('=====================================');
    }
  }
  next();
});

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
      // userVoiceActorsから取得
      try {
        const voiceActorsSnapshot = await db.collection('userVoiceActors').where('userId', '==', user.id).get();
        user.favoriteVoiceActors = voiceActorsSnapshot.docs.map(va => va.data().name || va.data().voiceActorId);
      } catch (error) {
        console.log(`ユーザー ${user.id} の声優データ取得エラー:`, error.message);
        user.favoriteVoiceActors = [];
      }
      // ユーザーポイントを取得
      try {
        const pointsSnapshot = await db.collection('userPoints').doc(user.id).get();
        user.points = pointsSnapshot.exists ? pointsSnapshot.data().points : 0;
      } catch (error) {
        console.log(`ユーザー ${user.id} のポイントデータ取得エラー:`, error.message);
        user.points = 0;
      }
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

// 特定のアニメ/キャラクター/声優/タグでユーザーを検索
app.get('/api/users/search', async (req, res) => {
  try {
    const { all, anime, character, voiceActor, hashtag } = req.query;
    console.log('検索条件:', { all, anime, character, voiceActor, hashtag });
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
      // userVoiceActorsから取得
      try {
        const voiceActorsSnapshot = await db.collection('userVoiceActors').where('userId', '==', user.id).get();
        user.favoriteVoiceActors = voiceActorsSnapshot.docs.map(va => va.data().name || va.data().voiceActorId);
      } catch (error) {
        console.log(`ユーザー ${user.id} の声優データ取得エラー:`, error.message);
        user.favoriteVoiceActors = [];
      }
      // ハッシュタグ（userAnimes, userCharacters両方から集約）
      const animeTags = animesSnapshot.docs.map(a => a.data().hashtag).filter(Boolean);
      const characterTags = charactersSnapshot.docs.map(c => c.data().tag).filter(Boolean);
      user.hashtags = Array.from(new Set([...animeTags, ...characterTags]));
      // デバッグ出力
      console.log('ユーザー:', user.username || user.id);
      console.log('  favoriteAnimes:', user.favoriteAnimes);
      console.log('  favoriteCharacters:', user.favoriteCharacters);
      console.log('  favoriteVoiceActors:', user.favoriteVoiceActors);
      console.log('  hashtags:', user.hashtags);
      // 検索条件に合致するか
      let match = true;
      
      // 全てで検索（ユーザー名、キャラクター、アニメ、声優、ハッシュタグを含む）
      if (all) {
        const searchTerm = all.toLowerCase();
        const userMatch = 
          (user.username && user.username.toLowerCase().includes(searchTerm)) ||
          (user.favoriteAnimes && user.favoriteAnimes.some(anime => anime && anime.toLowerCase().includes(searchTerm))) ||
          (user.favoriteCharacters && user.favoriteCharacters.some(char => char && char.toLowerCase().includes(searchTerm))) ||
          (user.favoriteVoiceActors && user.favoriteVoiceActors.some(va => va && va.toLowerCase().includes(searchTerm))) ||
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
      if (voiceActor) {
        const vaStr = (user.favoriteVoiceActors || []).filter(v => !!v).join(' ').toLowerCase();
        if (!vaStr.includes(voiceActor.toLowerCase())) match = false;
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
      targetVoiceActors,
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
          (targetVoiceActors && targetVoiceActors.length > 0) ||
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
          
          // 同じ声優をターゲットにしている広告があるかチェック
          if (targetVoiceActors && targetVoiceActors.length > 0 && ad.targetVoiceActors && ad.targetVoiceActors.length > 0) {
            const duplicateVA = targetVoiceActors.find(va => ad.targetVoiceActors.includes(va));
            if (duplicateVA) {
              return res.status(400).json({ 
                error: `既に「${duplicateVA}」をターゲットにしたビジットページの広告が存在します。1つのターゲットに対して1つの広告のみ作成可能です。` 
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
      targetVoiceActors: targetVoiceActors || [],
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
        updateData.targetAnimes !== undefined && updateData.targetCharacters !== undefined && 
        updateData.targetVoiceActors !== undefined && updateData.targetHashtags !== undefined) {
      
      const { targetAnimes, targetCharacters, targetVoiceActors, targetHashtags } = updateData;
      
      // ターゲット広告の場合のみチェック
      if ((targetAnimes && targetAnimes.length > 0) || 
          (targetCharacters && targetCharacters.length > 0) || 
          (targetVoiceActors && targetVoiceActors.length > 0) ||
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
          
          // 同じ声優をターゲットにしている広告があるかチェック
          if (targetVoiceActors && targetVoiceActors.length > 0 && ad.targetVoiceActors && ad.targetVoiceActors.length > 0) {
            const duplicateVA = targetVoiceActors.find(va => ad.targetVoiceActors.includes(va));
            if (duplicateVA) {
              return res.status(400).json({ 
                error: `既に「${duplicateVA}」をターゲットにしたビジットページの広告が存在します。1つのターゲットに対して1つの広告のみ作成可能です。` 
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

// 類似度を計算する関数（Levenshtein距離）
function levenshteinDistance(str1, str2) {
  const matrix = [];
  for (let i = 0; i <= str2.length; i++) {
    matrix[i] = [i];
  }
  for (let j = 0; j <= str1.length; j++) {
    matrix[0][j] = j;
  }
  for (let i = 1; i <= str2.length; i++) {
    for (let j = 1; j <= str1.length; j++) {
      if (str2.charAt(i - 1) === str1.charAt(j - 1)) {
        matrix[i][j] = matrix[i - 1][j - 1];
      } else {
        matrix[i][j] = Math.min(
          matrix[i - 1][j - 1] + 1,
          matrix[i][j - 1] + 1,
          matrix[i - 1][j] + 1
        );
      }
    }
  }
  return matrix[str2.length][str1.length];
}

// 類似名をグループ化する関数
function groupSimilarNames(names, threshold = 0.8) {
  const groups = {};
  const processed = new Set();
  
  names.forEach(name => {
    if (processed.has(name)) return;
    
    const group = [name];
    processed.add(name);
    
    names.forEach(otherName => {
      if (processed.has(otherName) || name === otherName) return;
      
      const distance = levenshteinDistance(name.toLowerCase(), otherName.toLowerCase());
      const similarity = 1 - distance / Math.max(name.length, otherName.length);
      
      if (similarity >= threshold) {
        group.push(otherName);
        processed.add(otherName);
      }
    });
    
    // 最も短い名前を代表名とする（通常は正しい名前）
    const representative = group.reduce((shortest, current) => 
      current.length < shortest.length ? current : shortest
    );
    
    groups[representative] = group;
  });
  
  return groups;
}

// シンプルなテストエンドポイント
app.get('/api/debug/test', (req, res) => {
  console.log('🧪 テストエンドポイントがアクセスされました');
  res.json({ 
    message: 'テスト成功', 
    timestamp: new Date().toISOString(),
    server: 'running'
  });
});

// デバッグ用：指定コレクションの内容を確認
app.get('/api/debug/collections', async (req, res) => {
  try {
    console.log('🔍 デバッグ: コレクション確認開始');
    
    const result = {};
    
    // 主要なコレクションを手動で確認
    const collectionNames = ['users', 'userAnimes', 'userCharacters', 'userVoiceActors', 'advertisements', 'customRankings'];
    
    for (const collectionName of collectionNames) {
      try {
        console.log(`🔍 ${collectionName}コレクション確認中...`);
        const snapshot = await db.collection(collectionName).get();
        result[collectionName] = {
          count: snapshot.docs.length,
          samples: snapshot.docs.slice(0, 3).map(doc => ({
            id: doc.id,
            data: doc.data()
          }))
        };
        console.log(`🔍 ${collectionName}: ${snapshot.docs.length}件`);
      } catch (collectionError) {
        console.error(`🔍 ${collectionName}エラー:`, collectionError);
        result[collectionName] = {
          error: collectionError.message,
          count: 0,
          samples: []
        };
      }
    }
    
    console.log('🔍 コレクション詳細:', result);
    res.json(result);
  } catch (error) {
    console.error('🔍 デバッグエラー:', error);
    res.status(500).json({ error: error.message, stack: error.stack });
  }
});

// 統計情報を取得
app.get('/api/statistics', async (req, res) => {
  try {
    console.log('📊 統計情報取得開始');
    const usersSnapshot = await db.collection('users').get();
    const adsSnapshot = await db.collection('advertisements').get();
    
    // 全てのアニメとキャラクターの名前を収集
    const allAnimeNames = [];
    const allCharacterNames = [];
    const allVoiceActors = [];
    const allHashtags = [];
    
    // userAnimesとuserCharactersから全データを取得
    console.log('📊 userAnimesから取得中...');
    const animesSnapshot = await db.collection('userAnimes').get();
    console.log(`📊 userAnimesコレクション: ${animesSnapshot.docs.length}件のドキュメント`);
    
    animesSnapshot.docs.forEach((doc, index) => {
      const data = doc.data();
      console.log(`📊 userAnimes[${index}]:`, {
        docId: doc.id,
        title: data.title,
        hashtag: data.hashtag,
        userId: data.userId,
        allFields: Object.keys(data)
      });
      
      if (data.title && data.title.trim()) {
        allAnimeNames.push(data.title.trim());
        console.log(`📊 アニメ名追加: "${data.title.trim()}"`);
      } else {
        console.log('📊 アニメ名なし:', data.title);
      }
      
      if (data.hashtag && data.hashtag.trim()) {
        allHashtags.push(data.hashtag.trim());
      }
    });
    
    console.log('📊 userCharactersから取得中...');
    const charactersSnapshot = await db.collection('userCharacters').get();
    console.log(`📊 userCharactersコレクション: ${charactersSnapshot.docs.length}件のドキュメント`);
    
    charactersSnapshot.docs.forEach((doc, index) => {
      const data = doc.data();
      console.log(`📊 userCharacters[${index}]:`, {
        docId: doc.id,
        name: data.name,
        tag: data.tag,
        userId: data.userId,
        allFields: Object.keys(data)
      });
      
      if (data.name && data.name.trim()) {
        allCharacterNames.push(data.name.trim());
        console.log(`📊 キャラ名追加: "${data.name.trim()}"`);
      } else {
        console.log('📊 キャラ名なし:', data.name);
      }
      
      if (data.tag && data.tag.trim()) {
        allHashtags.push(data.tag.trim());
      }
    });
    
    console.log('📊 userVoiceActorsから取得中...');
    try {
      const voiceActorsSnapshot = await db.collection('userVoiceActors').get();
      console.log(`📊 userVoiceActorsコレクション: ${voiceActorsSnapshot.docs.length}件のドキュメント`);
      
      voiceActorsSnapshot.docs.forEach((doc, index) => {
        const data = doc.data();
        console.log(`📊 userVoiceActors[${index}]:`, {
          docId: doc.id,
          name: data.name,
          userId: data.userId,
          allFields: Object.keys(data)
        });
        
        if (data.name && data.name.trim()) {
          allVoiceActors.push(data.name.trim());
          console.log(`📊 声優名追加: "${data.name.trim()}"`);
        } else {
          console.log('📊 声優名なし:', data.name);
        }
      });
    } catch (error) {
      console.log('📊 userVoiceActorsコレクション取得エラー:', error.message);
      console.log('📊 声優データなしで続行');
    }
    
    console.log(`📊 収集完了: アニメ${allAnimeNames.length}件, キャラクター${allCharacterNames.length}件, 声優${allVoiceActors.length}件, ハッシュタグ${allHashtags.length}件`);
    console.log('📊 全アニメ名リスト:', allAnimeNames);
    console.log('📊 全キャラ名リスト:', allCharacterNames);
    console.log('📊 全声優名リスト:', allVoiceActors);
    console.log('📊 全ハッシュタグリスト:', allHashtags);
    
    // 重複除去前後の確認
    const uniqueAnimeNames = [...new Set(allAnimeNames)];
    const uniqueCharacterNames = [...new Set(allCharacterNames)];
    const uniqueVoiceActors = [...new Set(allVoiceActors)];
    console.log('📊 重複除去後アニメ名:', uniqueAnimeNames);
    console.log('📊 重複除去後キャラ名:', uniqueCharacterNames);
    console.log('📊 重複除去後声優名:', uniqueVoiceActors);
    
    // 類似名をグループ化
    const animeGroups = groupSimilarNames(uniqueAnimeNames);
    const characterGroups = groupSimilarNames(uniqueCharacterNames);
    const voiceActorGroups = groupSimilarNames(uniqueVoiceActors);
    
    console.log('📊 アニメグループ化結果:', animeGroups);
    console.log('📊 キャラグループ化結果:', characterGroups);
    console.log('📊 声優グループ化結果:', voiceActorGroups);
    
    // 統計を集計
    const animeStats = {};
    const characterStats = {};
    const voiceActorStats = {};
    const hashtagStats = {};
    
    // アニメ統計
    Object.entries(animeGroups).forEach(([representative, variants]) => {
      let count = 0;
      console.log(`📊 アニメ処理中: 代表名="${representative}", バリエーション:`, variants);
      variants.forEach(variant => {
        const variantCount = allAnimeNames.filter(name => name === variant).length;
        count += variantCount;
        console.log(`📊   - "${variant}": ${variantCount}件`);
      });
      if (count > 0) {
        animeStats[representative] = count;
        console.log(`📊 アニメ統計追加: "${representative}" = ${count}件`);
      }
    });
    
    // キャラクター統計
    Object.entries(characterGroups).forEach(([representative, variants]) => {
      let count = 0;
      console.log(`📊 キャラ処理中: 代表名="${representative}", バリエーション:`, variants);
      variants.forEach(variant => {
        const variantCount = allCharacterNames.filter(name => name === variant).length;
        count += variantCount;
        console.log(`📊   - "${variant}": ${variantCount}件`);
      });
      if (count > 0) {
        characterStats[representative] = count;
        console.log(`📊 キャラ統計追加: "${representative}" = ${count}件`);
      }
    });
    
    // 声優統計
    Object.entries(voiceActorGroups).forEach(([representative, variants]) => {
      let count = 0;
      console.log(`📊 声優処理中: 代表名="${representative}", バリエーション:`, variants);
      variants.forEach(variant => {
        const variantCount = allVoiceActors.filter(name => name === variant).length;
        count += variantCount;
        console.log(`📊   - "${variant}": ${variantCount}件`);
      });
      if (count > 0) {
        voiceActorStats[representative] = count;
        console.log(`📊 声優統計追加: "${representative}" = ${count}件`);
      }
    });
    
    // ハッシュタグ統計
    allHashtags.forEach(tag => {
      const formattedTag = tag.startsWith('#') ? tag : `#${tag}`;
      hashtagStats[formattedTag] = (hashtagStats[formattedTag] || 0) + 1;
    });
    
    // データがない場合の対処
    if (Object.keys(animeStats).length === 0 && Object.keys(characterStats).length === 0) {
      console.log('📊 データなし - サンプルデータを返す');
      return res.json({
        totalUsers: usersSnapshot.size,
        totalAds: adsSnapshot.size,
        animeStats: {
          'データなし': 0
        },
        characterStats: {
          'データなし': 0
        },
        voiceActorStats: {
          'データなし': 0
        },
        hashtagStats: {
          '#データなし': 0
        }
      });
    }
    
    console.log('📊 最終統計結果:');
    console.log('📊 animeStats:', animeStats);
    console.log('📊 characterStats:', characterStats);
    console.log('📊 voiceActorStats:', voiceActorStats);
    console.log('📊 hashtagStats:', hashtagStats);
    console.log('📊 統計サマリー:', {
      animeCount: Object.keys(animeStats).length,
      characterCount: Object.keys(characterStats).length,
      voiceActorCount: Object.keys(voiceActorStats).length,
      hashtagCount: Object.keys(hashtagStats).length
    });
    
    res.json({
      totalUsers: usersSnapshot.size,
      totalAds: adsSnapshot.size,
      animeStats,
      characterStats,
      voiceActorStats,
      hashtagStats
    });
  } catch (error) {
    console.error('📊 統計取得エラー:', error);
    res.status(500).json({ error: error.message });
  }
});


// カスタムランキング管理API
// カスタムランキング一覧取得
app.get('/api/custom-rankings', async (req, res) => {
  try {
    const rankingsSnapshot = await db.collection('customRankings').get();
    const rankings = [];
    
    for (const doc of rankingsSnapshot.docs) {
      const rankingData = doc.data();
      
      // 各ランキングのアイテムを取得
      const itemsSnapshot = await db.collection('customRankings')
        .doc(doc.id)
        .collection('items')
        .orderBy('rank')
        .get();
      
      const items = itemsSnapshot.docs.map(itemDoc => ({
        id: itemDoc.id,
        ...itemDoc.data()
      }));
      
      rankings.push({
        id: doc.id,
        ...rankingData,
        items: items
      });
    }
    
    res.json(rankings);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// カスタムランキング作成
app.post('/api/custom-rankings', async (req, res) => {
  try {
    const { title, displayProbability, isActive, imageURL } = req.body;
    
    const newRanking = {
      title,
      displayProbability,
      isActive,
      imageURL: imageURL || null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };
    
    const docRef = await db.collection('customRankings').add(newRanking);
    res.json({ id: docRef.id, ...newRanking });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// カスタムランキング更新
app.put('/api/custom-rankings/:id', async (req, res) => {
  try {
    const { id } = req.params;
    const updates = {
      ...req.body,
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };
    
    await db.collection('customRankings').doc(id).update(updates);
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// カスタムランキング削除
app.delete('/api/custom-rankings/:id', async (req, res) => {
  try {
    const { id } = req.params;
    
    // アイテムも含めて削除
    const itemsSnapshot = await db.collection('customRankings')
      .doc(id)
      .collection('items')
      .get();
    
    const batch = db.batch();
    
    // アイテムを削除
    itemsSnapshot.docs.forEach(doc => {
      batch.delete(doc.ref);
    });
    
    // ランキング本体を削除
    batch.delete(db.collection('customRankings').doc(id));
    
    await batch.commit();
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// カスタムランキングアイテム追加
app.post('/api/custom-rankings/:rankingId/items', async (req, res) => {
  try {
    const { rankingId } = req.params;
    const { rank, characterId, characterName, characterImagePath, githubImageUrl } = req.body;
    
    console.log('Received ranking item data:', { rank, characterId, characterName, characterImagePath, githubImageUrl });
    console.log('githubImageUrl value:', githubImageUrl);
    console.log('githubImageUrl type:', typeof githubImageUrl);
    
    // 既存の同じランクのアイテムを削除
    const existingItemSnapshot = await db.collection('customRankings')
      .doc(rankingId)
      .collection('items')
      .where('rank', '==', rank)
      .get();
    
    const batch = db.batch();
    
    // 既存アイテム削除
    existingItemSnapshot.docs.forEach(doc => {
      batch.delete(doc.ref);
    });
    
    // 新しいアイテム追加
    const newItemRef = db.collection('customRankings')
      .doc(rankingId)
      .collection('items')
      .doc();
    
    const itemData = {
      rank,
      characterId: characterId || null,
      characterName,
      characterImageURL: characterImagePath || null,  // レガシーデータ用
      customImageURL: githubImageUrl || null,         // GitHub URL用
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    };
    
    console.log('Saving item data:', itemData);
    console.log('itemData.characterImageURL:', itemData.characterImageURL);
    console.log('itemData.customImageURL:', itemData.customImageURL);
    batch.set(newItemRef, itemData);
    
    await batch.commit();
    
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// カスタムランキングアイテム削除
app.delete('/api/custom-rankings/:rankingId/items/:rank', async (req, res) => {
  try {
    const { rankingId, rank } = req.params;
    
    const itemSnapshot = await db.collection('customRankings')
      .doc(rankingId)
      .collection('items')
      .where('rank', '==', parseInt(rank))
      .get();
    
    const batch = db.batch();
    itemSnapshot.docs.forEach(doc => {
      batch.delete(doc.ref);
    });
    
    await batch.commit();
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// キャラクター一覧取得
app.get('/api/characters', async (req, res) => {
  try {
    const charactersSnapshot = await db.collection('userCharacters').get();
    const charactersMap = new Map();
    
    charactersSnapshot.docs.forEach(doc => {
      const data = doc.data();
      if (data.name && !charactersMap.has(data.name)) {
        charactersMap.set(data.name, {
          id: doc.id,
          name: data.name,
          tag: data.tag || '',
          imageIdentifier: data.imageIdentifier || null
        });
      }
    });
    
    const characters = Array.from(charactersMap.values());
    res.json(characters);
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

// GitHub画像アップロード処理
async function uploadImageToGitHub(base64Data, fileName, folderPath) {
  try {
    // リポジトリ設定を取得
    const settingsDoc = await db.collection('githubSettings').doc('repositories').get();
    if (!settingsDoc.exists) {
      throw new Error('GitHubリポジトリ設定が見つかりません');
    }
    
    const data = settingsDoc.data();
    const repositories = data.repositories || [];
    const activeRepo = repositories.find(r => r.id === data.activeRepoId);
    
    if (!activeRepo) {
      throw new Error('アクティブなリポジトリが見つかりません');
    }
    
    const path = `${folderPath}/${fileName}.jpg`;
    const url = `https://api.github.com/repos/${activeRepo.owner}/${activeRepo.name}/contents/${path}`;
    
    const response = await axios.put(url, {
      message: `Upload character ranking image: ${fileName}`,
      content: base64Data,
      branch: activeRepo.branch
    }, {
      headers: {
        'Authorization': `Bearer ${activeRepo.token}`,
        'Content-Type': 'application/json'
      }
    });
    
    if (response.status === 201 || response.status === 200) {
      return {
        url: `https://raw.githubusercontent.com/${activeRepo.owner}/${activeRepo.name}/${activeRepo.branch}/${path}`,
        path: path
      };
    } else {
      throw new Error(`GitHub API エラー: ${response.status}`);
    }
  } catch (error) {
    throw new Error(`画像アップロードエラー: ${error.message}`);
  }
}

// 管理者用ポイント追加API
app.post('/api/admin/add-points', async (req, res) => {
  try {
    const { userId, amount, type, description } = req.body;
    
    if (!userId || !amount || !description) {
      return res.status(400).json({ error: '必須フィールドが不足しています' });
    }
    
    if (amount <= 0) {
      return res.status(400).json({ error: 'ポイント数は正の数である必要があります' });
    }
    
    // ユーザーの現在のポイントを取得
    const userPointsRef = db.collection('userPoints').doc(userId);
    const userPointsDoc = await userPointsRef.get();
    
    let currentPoints = 0;
    if (userPointsDoc.exists) {
      currentPoints = userPointsDoc.data().points || 0;
    }
    
    // ポイントを更新
    const newPoints = currentPoints + amount;
    const pointsData = {
      userId: userId,
      points: newPoints,
      totalEarned: admin.firestore.FieldValue.increment(amount),
      lastUpdated: admin.firestore.FieldValue.serverTimestamp()
    };
    
    if (!userPointsDoc.exists) {
      pointsData.createdAt = admin.firestore.FieldValue.serverTimestamp();
      pointsData.totalEarned = amount;
      pointsData.totalSpent = 0;
    }
    
    await userPointsRef.set(pointsData, { merge: true });
    
    // 取引履歴を記録
    const transactionRef = db.collection('pointTransactions').doc();
    await transactionRef.set({
      id: transactionRef.id,
      userId: userId,
      amount: amount,
      type: type || 'admin_grant',
      description: description,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    console.log(`管理者がユーザー ${userId} に ${amount} ポイントを付与しました`);
    
    res.json({ 
      success: true, 
      newPoints: newPoints,
      message: `${amount}ポイントを追加しました` 
    });
    
  } catch (error) {
    console.error('ポイント追加エラー:', error);
    res.status(500).json({ error: error.message });
  }
});

// ユーザーのポイント情報を取得
app.get('/api/users/:userId/points', async (req, res) => {
  try {
    const { userId } = req.params;
    
    const userPointsDoc = await db.collection('userPoints').doc(userId).get();
    
    if (!userPointsDoc.exists) {
      return res.json({ points: 0, transactions: [] });
    }
    
    const pointsData = userPointsDoc.data();
    
    // 取引履歴も取得
    const transactionsSnapshot = await db.collection('pointTransactions')
      .where('userId', '==', userId)
      .orderBy('createdAt', 'desc')
      .limit(20)
      .get();
    
    const transactions = transactionsSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
      createdAt: doc.data().createdAt?.toDate()
    }));
    
    res.json({
      points: pointsData.points || 0,
      transactions: transactions
    });
    
  } catch (error) {
    console.error('ポイント情報取得エラー:', error);
    res.status(500).json({ error: error.message });
  }
});

// キャラクターランキングAPI
app.get('/api/character-rankings', async (req, res) => {
  try {
    const rankingsSnapshot = await db.collection('characterRankings').get();
    const rankings = rankingsSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));
    res.json(rankings);
  } catch (error) {
    console.error('ランキング取得エラー:', error);
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/character-rankings', async (req, res) => {
  try {
    const { characterId, rank, characterName, characterImagePath, imageFile, externalLink } = req.body;
    
    // 既存の同じランクのランキングを削除
    const existingSnapshot = await db.collection('characterRankings')
      .where('rank', '==', rank)
      .get();
    
    const batch = db.batch();
    existingSnapshot.docs.forEach(doc => {
      batch.delete(doc.ref);
    });
    
    // 新しいランキングを追加
    const newRankingRef = db.collection('characterRankings').doc();
    const rankingData = {
      characterId,
      rank,
      characterName,
      characterImagePath,
      externalLink: externalLink || '',
      updatedAt: admin.firestore.FieldValue.serverTimestamp()
    };
    
    batch.set(newRankingRef, rankingData);
    await batch.commit();
    
    res.json({ success: true, id: newRankingRef.id });
  } catch (error) {
    console.error('ランキング設定エラー:', error);
    res.status(500).json({ error: error.message });
  }
});

app.delete('/api/character-rankings/:rank', async (req, res) => {
  try {
    const rank = parseInt(req.params.rank);
    
    const snapshot = await db.collection('characterRankings')
      .where('rank', '==', rank)
      .get();
    
    const batch = db.batch();
    snapshot.docs.forEach(doc => {
      batch.delete(doc.ref);
    });
    
    await batch.commit();
    res.json({ success: true });
  } catch (error) {
    console.error('ランキング削除エラー:', error);
    res.status(500).json({ error: error.message });
  }
});

app.post('/api/character-rankings/update-link', async (req, res) => {
  try {
    const { rank, externalLink } = req.body;
    
    const snapshot = await db.collection('characterRankings')
      .where('rank', '==', rank)
      .get();
    
    if (snapshot.empty) {
      return res.status(404).json({ error: 'ランキングが見つかりません' });
    }
    
    const batch = db.batch();
    snapshot.docs.forEach(doc => {
      batch.update(doc.ref, {
        externalLink: externalLink || '',
        updatedAt: admin.firestore.FieldValue.serverTimestamp()
      });
    });
    
    await batch.commit();
    res.json({ success: true });
  } catch (error) {
    console.error('リンク更新エラー:', error);
    res.status(500).json({ error: error.message });
  }
});

app.listen(PORT, () => {
  console.log(`Server is running on port ${PORT}`);
});