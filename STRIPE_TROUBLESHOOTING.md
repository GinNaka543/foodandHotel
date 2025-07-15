# Stripe iOS SDK トラブルシューティング

## ✅ 完了した作業

1. **Pod インストール完了**
   - Stripe SDK (v24.16.2) が正常にインストールされました
   - Firebase も最新版 (v12.0.0) にアップデートされました

2. **本番実装完了**
   - StripePaymentManagerを本番用に更新
   - Payment Sheetを使った決済フローを実装
   - 日本の決済環境に最適化

## 🔧 Xcodeでのトラブルシューティング

### FirebaseCoreInternalエラーの解決方法

1. **Xcodeでワークスペースを開く**
   ```
   HappinessGameSwift.xcworkspace
   ```

2. **プロジェクトをクリーン**
   - メニュー: Product → Clean Build Folder (Shift+Cmd+K)

3. **DerivedDataを削除**
   - Xcode → Settings → Locations
   - DerivedData パスの横の矢印をクリック
   - プロジェクトフォルダを削除

4. **再ビルド**
   - Product → Build (Cmd+B)

### それでもエラーが続く場合

1. **Podsを再インストール**
   ```bash
   cd "/Users/nakajimaginsei/Desktop/Happiness game"
   rm -rf Pods Podfile.lock
   pod install
   ```

2. **Xcodeを再起動**

## 📱 アプリでのテスト手順

1. **シミュレーターまたは実機で実行**
   - iPhone 16 Pro などのシミュレーターを選択
   - Run (Cmd+R)

2. **ポイント購入をテスト**
   - ホーム画面 → ポイント表示をタップ
   - 「購入」ボタンをタップ
   - ポイントパッケージを選択
   - 「購入する」をタップ
   - Stripe Payment Sheetが表示される

3. **テストカード情報**
   - カード番号: 4242 4242 4242 4242
   - 有効期限: 任意の未来の日付
   - CVC: 任意の3桁
   - 郵便番号: 任意の5桁

## ⚠️ 注意事項

- 本番環境のAPIキーが設定されているため、実際の決済が発生します
- テスト環境で使用する場合は、Stripeダッシュボードでテストモードのキーに切り替えてください
- サーバーが10.101.9.168:5002で実行中であることを確認してください

## 🚀 次のステップ

1. Xcodeでビルドエラーを解決
2. アプリを実行してStripe決済をテスト
3. Firebaseコンソールでインデックスを作成（エラーが出た場合）