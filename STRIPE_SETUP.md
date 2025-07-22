# Stripe iOS SDK セットアップ手順

## 1. Pod インストール

ターミナルで以下を実行してください：

```bash
cd "/Users/nakajimaginsei/Desktop/Happiness game"
pod install
```

## 2. プロジェクトを開く

インストール後は必ず `.xcworkspace` ファイルを開いてください：
- ❌ HappinessGameSwift.xcodeproj （使わない）
- ✅ HappinessGameSwift.xcworkspace （こちらを使う）

## 3. 実装済みの機能

### ✅ Stripe Payment Sheet
- 本物の決済画面が表示されます
- クレジットカード、デビットカードに対応
- 日本円（JPY）での決済

### ✅ 決済フロー
1. ユーザーがポイントパッケージを選択
2. サーバーでPayment Intentを作成
3. Stripe Payment Sheetで決済画面表示
4. 決済完了後、自動的にポイント追加

### ✅ セキュリティ
- Secret Keyはサーバー側のみで保管
- クライアントはPublishable Keyのみ使用
- 決済情報は全てStripeが安全に処理

## 4. テスト用カード番号

開発中は以下のテストカードが使用できます：
- カード番号: 4242 4242 4242 4242
- 有効期限: 任意の未来の日付
- CVC: 任意の3桁の数字
- 郵便番号: 任意の5桁の数字

## 5. 本番環境での注意点

- 現在は本番用のキーが設定されています
- 実際の決済が発生します
- テストは慎重に行ってください

## 6. Firebase インデックス

コンソールに表示されるエラーメッセージのリンクから、Firebaseコンソールでインデックスを作成してください。