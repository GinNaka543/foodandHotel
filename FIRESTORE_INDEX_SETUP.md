# Firestore インデックス設定手順

## 必要なインデックス

アプリのログに以下のエラーが表示されています：
```
Listen for query at pointTransactions failed: The query requires an index.
```

## 解決方法

### 方法1: 直接リンクを使用（推奨）

以下のリンクをクリックして、自動的にインデックスを作成できます：

[インデックス作成リンク](https://console.firebase.google.com/v1/r/project/ani-reco/firestore/indexes?create_composite=ClJwcm9qZWN0cy9hbmktcmVjby9kYXRhYmFzZXMvKGRlZmF1bHQpL2NvbGxlY3Rpb25Hcm91cHMvcG9pbnRUcmFuc2FjdGlvbnMvaW5kZXhlcy9fEAEaCgoGdXNlcklkEAEaDQoJY3JlYXRlZEF0EAIaDAoIX19uYW1lX18QAg)

### 方法2: 手動で作成

1. [Firebase Console](https://console.firebase.google.com) にログイン
2. プロジェクト「ani-reco」を選択
3. 左メニューから「Firestore Database」を選択
4. 「インデックス」タブをクリック
5. 「インデックスを作成」ボタンをクリック
6. 以下の設定で作成：
   - **コレクションID**: `pointTransactions`
   - **フィールド1**: 
     - フィールドパス: `userId`
     - 順序: 昇順
   - **フィールド2**: 
     - フィールドパス: `createdAt`
     - 順序: 降順
   - **クエリスコープ**: コレクション

## 確認方法

インデックス作成後（数分かかる場合があります）、アプリを再起動して以下のエラーが表示されなくなることを確認：
```
Listen for query at pointTransactions failed
```

## Bundle ID の不一致について

現在のBundle ID: `com.nakajima.HappinessGameSwift`
Firebase期待値: `com.example.HappinessGameSwift`

この不一致は機能には影響しませんが、警告が表示されます。必要に応じて：
1. Firebase ConsoleでGoogleService-Info.plistを再ダウンロード
2. または、現在のBundle IDに合わせて新しいアプリを追加