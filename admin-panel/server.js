const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');
const path = require('path');
const fs = require('fs').promises;

const app = express();
const PORT = process.env.PORT || 3001;

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
        const plansPath = path.join(DATA_DIR, 'plans.json');
        const plansData = await fs.readFile(plansPath, 'utf-8').catch(() => '[]');
        const plans = JSON.parse(plansData);
        
        const stats = {
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

// サーバー起動
app.listen(PORT, async () => {
    await ensureDataDir();
    console.log(`管理者画面が起動しました: http://localhost:${PORT}`);
    console.log('ブラウザで上記URLを開いてください');
});