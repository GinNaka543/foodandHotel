# Happiness Game Admin Panel

Happiness Gameアプリのユーザー管理と広告配信を行う管理画面です。

## セットアップ

### 1. Firebase設定

1. [Firebase Console](https://console.firebase.google.com/)でプロジェクトを作成
2. Firestoreデータベースを有効化
3. プロジェクト設定から秘密鍵をダウンロード
4. `server/serviceAccountKey.json`として保存

### 2. サーバーセットアップ

```bash
cd server
npm install
npm run dev
```

### 3. クライアントセットアップ

```bash
cd client
npm install
npm start
```

## 機能

### ユーザー管理
- 全ユーザーの一覧表示
- アニメ、キャラクター、ハッシュタグでのユーザー検索
- ユーザーの好み情報の表示

### 広告管理
- ターゲティング広告の作成
- 広告パフォーマンスの追跡（インプレッション、クリック数、CTR）
- 広告の有効/無効化

### ダッシュボード
- ユーザー統計
- 人気アニメ/キャラクター/ハッシュタグのグラフ表示

## API エンドポイント

### ユーザー関連
- `GET /api/users` - 全ユーザー取得
- `GET /api/users/search` - ユーザー検索

### 広告関連
- `GET /api/advertisements` - 全広告取得
- `POST /api/advertisements` - 広告作成
- `PUT /api/advertisements/:id` - 広告更新
- `DELETE /api/advertisements/:id` - 広告無効化

### 統計
- `GET /api/statistics` - 統計情報取得

## Firebaseコレクション構造

### users
```json
{
  "id": "user_id",
  "username": "ユーザー名",
  "favoriteAnimes": ["アニメ1", "アニメ2"],
  "favoriteCharacters": ["キャラ1", "キャラ2"],
  "hashtags": ["tag1", "tag2"],
  "createdAt": "timestamp",
  "updatedAt": "timestamp"
}
```

### advertisements
```json
{
  "title": "広告タイトル",
  "description": "広告説明",
  "imageURL": "画像URL",
  "linkURL": "リンクURL",
  "targetAnimes": ["アニメ1"],
  "targetCharacters": ["キャラ1"],
  "targetHashtags": ["tag1"],
  "impressions": 0,
  "clicks": 0,
  "isActive": true,
  "createdAt": "timestamp"
}
```

### インデックスコレクション
- `animeIndex` - アニメ別ユーザーインデックス
- `characterIndex` - キャラクター別ユーザーインデックス
- `hashtagIndex` - ハッシュタグ別ユーザーインデックス