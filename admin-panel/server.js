const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const path = require('path');
const fs = require('fs').promises;
const admin = require('firebase-admin');

const app = express();
const PORT = process.env.PORT || 3002;

// Firebase初期化
try {
    // サービスアカウントキーがある場合は使用
    if (process.env.FIREBASE_SERVICE_ACCOUNT) {
        const serviceAccount = JSON.parse(process.env.FIREBASE_SERVICE_ACCOUNT);
        admin.initializeApp({
            credential: admin.credential.cert(serviceAccount)
        });
    } else {
        // 開発環境では仮の初期化
        console.log('Firebase service account not found, running in demo mode');
    }
} catch (error) {
    console.log('Firebase initialization failed, running in demo mode:', error.message);
}

// Middleware
app.use(cors());
app.use(bodyParser.json());
app.use(express.static('public'));

// データ保存ディレクトリ
const DATA_DIR = path.join(__dirname, 'data');

// データディレクトリを作成
async function ensureDataDir() {
    try {
        await fs.mkdir(DATA_DIR, { recursive: true });
    } catch (error) {
        console.error('Error creating data directory:', error);
    }
}

// ルートハンドラ
app.get('/', (req, res) => {
    res.sendFile(path.join(__dirname, 'public', 'index.html'));
});

// API: プラン一覧取得
app.get('/api/plans', async (req, res) => {
    try {
        const filePath = path.join(DATA_DIR, 'plans.json');
        const data = await fs.readFile(filePath, 'utf-8').catch(() => '[]');
        res.json(JSON.parse(data));
    } catch (error) {
        res.status(500).json({ error: 'Failed to read plans' });
    }
});

// API: プラン保存
app.post('/api/plans', async (req, res) => {
    try {
        const filePath = path.join(DATA_DIR, 'plans.json');
        const existingData = await fs.readFile(filePath, 'utf-8').catch(() => '[]');
        const plans = JSON.parse(existingData);
        
        const newPlan = {
            id: Date.now().toString(),
            ...req.body,
            createdAt: new Date().toISOString()
        };
        
        plans.push(newPlan);
        await fs.writeFile(filePath, JSON.stringify(plans, null, 2));
        
        res.json(newPlan);
    } catch (error) {
        res.status(500).json({ error: 'Failed to save plan' });
    }
});

// API: プラン削除
app.delete('/api/plans/:id', async (req, res) => {
    try {
        const filePath = path.join(DATA_DIR, 'plans.json');
        const data = await fs.readFile(filePath, 'utf-8').catch(() => '[]');
        const plans = JSON.parse(data);
        
        const filteredPlans = plans.filter(plan => plan.id !== req.params.id);
        await fs.writeFile(filePath, JSON.stringify(filteredPlans, null, 2));
        
        res.json({ success: true });
    } catch (error) {
        res.status(500).json({ error: 'Failed to delete plan' });
    }
});

// API: 統計情報取得
app.get('/api/stats', async (req, res) => {
    try {
        // Firebase統計を追加
        let firebaseStats = {};
        
        if (admin.apps.length > 0) {
            const db = admin.firestore();
            
            // ユーザー数を取得
            const usersSnapshot = await db.collection('users').get();
            const usersCount = usersSnapshot.size;
            
            // キャラクター数を取得
            const charactersSnapshot = await db.collection('userCharacters').get();
            const charactersCount = charactersSnapshot.size;
            
            // アニメ数を取得
            const animesSnapshot = await db.collection('userAnimes').get();
            const animesCount = animesSnapshot.size;
            
            firebaseStats = {
                totalUsers: usersCount,
                totalCharacters: charactersCount,
                totalAnimes: animesCount
            };
        }
        
        // ローカルプラン統計
        const plansPath = path.join(DATA_DIR, 'plans.json');
        const plansData = await fs.readFile(plansPath, 'utf-8').catch(() => '[]');
        const plans = JSON.parse(plansData);
        
        const stats = {
            ...firebaseStats,
            totalPlans: plans.length,
            plansByDuration: {
                halfDay: plans.filter(p => p.duration === '半日').length,
                oneDay: plans.filter(p => p.duration === '1日').length,
                threeDays: plans.filter(p => p.duration === '3日').length
            },
            totalSpots: plans.reduce((acc, plan) => acc + (plan.spots?.length || 0), 0),
            recentPlans: plans.slice(-5).reverse()
        };
        
        res.json(stats);
    } catch (error) {
        res.status(500).json({ error: 'Failed to get stats' });
    }
});

// API: Firebaseユーザー一覧取得
app.get('/api/firebase/users', async (req, res) => {
    try {
        if (admin.apps.length === 0) {
            return res.json({ users: [], message: 'Firebase not connected' });
        }
        
        const db = admin.firestore();
        const usersSnapshot = await db.collection('users').orderBy('updatedAt', 'desc').limit(50).get();
        
        const users = [];
        usersSnapshot.forEach(doc => {
            const data = doc.data();
            users.push({
                id: doc.id,
                username: data.username || 'Unknown',
                birthday: data.birthday ? data.birthday.toDate().toLocaleDateString('ja-JP') : null,
                createdAt: data.createdAt ? data.createdAt.toDate().toLocaleDateString('ja-JP') : null,
                updatedAt: data.updatedAt ? data.updatedAt.toDate().toLocaleDateString('ja-JP') : null,
                platform: data.platform || 'Unknown'
            });
        });
        
        res.json({ users });
    } catch (error) {
        res.status(500).json({ error: 'Failed to fetch Firebase users' });
    }
});

// API: ユーザーのキャラクター取得
app.get('/api/firebase/users/:userId/characters', async (req, res) => {
    try {
        if (admin.apps.length === 0) {
            return res.json({ characters: [], message: 'Firebase not connected' });
        }
        
        const { userId } = req.params;
        const db = admin.firestore();
        const charactersSnapshot = await db.collection('userCharacters')
            .where('userId', '==', userId)
            .orderBy('createdAt', 'desc')
            .get();
        
        const characters = [];
        charactersSnapshot.forEach(doc => {
            const data = doc.data();
            characters.push({
                id: doc.id,
                name: data.name,
                tag: data.tag,
                anime: data.anime,
                createdAt: data.createdAt ? data.createdAt.toDate().toLocaleDateString('ja-JP') : null
            });
        });
        
        res.json({ characters });
    } catch (error) {
        res.status(500).json({ error: 'Failed to fetch user characters' });
    }
});

// API: ユーザーのアニメ取得
app.get('/api/firebase/users/:userId/animes', async (req, res) => {
    try {
        if (admin.apps.length === 0) {
            return res.json({ animes: [], message: 'Firebase not connected' });
        }
        
        const { userId } = req.params;
        const db = admin.firestore();
        const animesSnapshot = await db.collection('userAnimes')
            .where('userId', '==', userId)
            .orderBy('createdAt', 'desc')
            .get();
        
        const animes = [];
        animesSnapshot.forEach(doc => {
            const data = doc.data();
            animes.push({
                id: doc.id,
                title: data.title,
                hashtag: data.hashtag,
                createdAt: data.createdAt ? data.createdAt.toDate().toLocaleDateString('ja-JP') : null
            });
        });
        
        res.json({ animes });
    } catch (error) {
        res.status(500).json({ error: 'Failed to fetch user animes' });
    }
});

// サーバー起動
app.listen(PORT, async () => {
    await ensureDataDir();
    console.log(`管理者画面が起動しました: http://localhost:${PORT}`);
    console.log('ブラウザで上記URLを開いてください');
});