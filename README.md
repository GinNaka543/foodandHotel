# Happiness Game - マルチプラットフォーム・キャラクター管理システム

## 📱 プロジェクト概要

Happiness Gameは、アニメ・ゲームキャラクターの情報管理を目的とした2つのアプリケーションから構成されるプロジェクトです。

### 1. **iOS ネイティブアプリ（SwiftUI）**
App Storeで配信予定の本格的なキャラクター管理アプリ

### 2. **Web アプリ（HTML/CSS/JavaScript）**
ブラウザで動作するシンプルなキャラクター管理アプリ

---

## 🎯 iOS アプリ - HappinessGameSwift

### 主要機能

#### 📊 キャラクター管理
- **基本情報管理**: 名前、誕生日、タグ、画像
- **詳細情報**: 年齢、身長、声優、趣味、職業など20項目以上
- **カスタムフィールド**: ユーザー定義の項目追加
- **ランキングシステム**: 8つの属性（可愛い、美しい、クール等）でスコア付け
- **並び替え機能**: ドラッグ&ドロップで表示順変更

#### 🎬 アニメ作品管理
- **作品情報**: タイトル、放送日、ハッシュタグ、サムネイル
- **聖地情報**: アニメの舞台となった場所の記録
- **訪問プラン**: 聖地巡礼の計画作成・管理

#### 🎨 メディア管理
- **アートワーク**: キャラクターイラストのギャラリー
- **動画**: キャラクター関連動画の保存・再生
- **BGM**: キャラクターテーマ曲の管理

#### 💰 課金システム
- **40日間無料トライアル**: 新規ユーザー向け
- **ポイントシステム**: アプリ内通貨での支払い
- **プレミアム機能**: 無制限のキャラクター登録

#### 🌐 多言語対応
- 日本語、英語、中国語、韓国語、スペイン語、フランス語、ドイツ語、イタリア語、ポルトガル語

### 技術スタック

```
フロントエンド:
├── SwiftUI - UIフレームワーク
├── UIKit - 一部の機能で使用
├── PhotosUI - 画像選択
├── AVKit - 動画再生
└── StoreKit - App内課金

バックエンド・データ:
├── Firebase
│   ├── Authentication - ユーザー認証
│   ├── Firestore - データベース
│   ├── Storage - 画像・動画保存
│   └── Functions - サーバーレス関数
├── UserDefaults - ローカル設定保存
└── CoreData - オフラインデータキャッシュ（予定）

最適化:
├── MemoryPressureManager - メモリ管理
├── ImageCache - 画像キャッシュ
├── DataMigrationManager - データ移行
└── PerformanceMonitor - パフォーマンス監視
```

### アーキテクチャ

```
HappinessGameSwift/
├── Models/           # データモデル
│   ├── Character.swift
│   ├── Anime.swift
│   └── VisitPlan.swift
├── Views/           # SwiftUI Views
│   ├── CharaScreen.swift
│   ├── AnimeScreen.swift
│   └── VisitScreen.swift
├── ViewModels/      # ビジネスロジック
├── Services/        # API・データサービス
│   ├── FirebaseManager.swift
│   └── ImageOptimizer.swift
└── Utilities/       # ヘルパー関数
```

---

## 🌐 Web アプリ - HTML/CSS/JavaScript版

### 主要機能

#### 基本機能
- **キャラクター登録**: 名前、タグ、誕生日、画像
- **検索機能**: キャラクター名やタグで検索
- **詳細表示**: キャラクター情報の閲覧・編集

#### 詳細画面のタブ構成
1. **ArtWork**: アートワーク表示（開発中）
2. **Video**: 動画表示（開発中）
3. **About**: キャラクター詳細情報の編集
   - 出演作品、年齢、聖地
   - カスタムフィールドの追加・編集・削除
4. **Visit**: 外部リンク（開発中）

### 技術仕様

```
フロントエンド:
├── HTML5 - セマンティックマークアップ
├── CSS3 - レスポンシブデザイン
└── JavaScript (ES6+) - クラスベースアーキテクチャ

データ管理:
├── LocalStorage - ブラウザ内データ永続化
├── Base64 - 画像データの保存
└── JSON - データ構造
```

### ファイル構成

```
web/
├── index.html       # メインHTMLファイル
├── styles.css       # スタイルシート
├── app.js          # メインJavaScript
└── assets/         # 画像ファイル
```

---

## 🔥 Firebase バックエンド構成

### APIサーバー（Node.js/Express）

#### happiness-game-api
```javascript
主要エンドポイント:
├── /api/create-payment-intent  # 決済処理
├── /api/subscriptions          # サブスクリプション管理
├── /api/users                  # ユーザー管理
└── /api/points                 # ポイント管理
```

#### happiness-game-admin
管理者向けダッシュボード（Node.js/Express）
- ユーザー管理
- 広告配置管理
- 統計情報表示

### データベース構造（Firestore）

```
collections/
├── users/              # ユーザー情報
├── characters/         # キャラクターデータ
├── anime/              # アニメ作品
├── visitPlans/         # 聖地巡礼プラン
├── userPoints/         # ポイント残高
└── device_subscriptions/ # デバイス別課金状態
```

---

## 🚀 セットアップ

### iOS アプリ

```bash
# 依存関係のインストール
cd "Happiness game"
pod install

# Xcodeで開く
open HappinessGameSwift.xcworkspace

# ビルド＆実行
Command + R
```

### Web アプリ

```bash
# ローカルサーバーで実行（Python）
python -m http.server 8000

# ブラウザで開く
open http://localhost:8000
```

### バックエンド

```bash
# APIサーバー起動
cd happiness-game-api
npm install
npm start

# 管理画面起動
cd happiness-game-admin
npm install
npm run dev
```

---

## 📈 開発状況

### ✅ 実装済み機能
- ユーザー認証システム
- キャラクター・アニメCRUD操作
- 画像・動画管理
- 40日間無料トライアル
- 多言語対応
- メモリ最適化

### 🚧 開発中機能
- オフライン対応（CoreData統合）
- 音声メモ機能
- AIによるキャラクター推薦

### 📋 今後の予定
- Apple Watch対応
- ウィジェット機能
- ソーシャル共有機能

---

## 🔧 トラブルシューティング

### よくある問題と解決方法

#### メモリ不足エラー
- 画像の自動圧縮機能が有効になっているか確認
- キャッシュクリア: Settings > Clear Cache

#### Firebase接続エラー
- GoogleService-Info.plistが正しく配置されているか確認
- ネットワーク接続を確認

#### ビルドエラー
```bash
# クリーンビルド
Command + Shift + K
# DerivedDataの削除
rm -rf ~/Library/Developer/Xcode/DerivedData
```

---

## 📄 ライセンス
プライベートプロジェクト

## 👥 貢献者
- 開発者: 中島銀星

## 📞 サポート
問題が発生した場合は、GitHubのIssuesで報告してください。