# セキュリティ注意事項

## ⚠️ 重要: GitHubに公開してはいけないファイル

以下のファイルは**絶対に**GitHubに公開しないでください：

### 🔴 削除済み（Gitから除外済み）
- `GoogleService-Info.plist` - Firebase設定ファイル
- `HappinessGameSwift/GoogleService-Info.plist` - Firebase設定ファイル
- `happiness-game-admin/api/serviceAccountKey.json` - Firebaseサービスアカウントキー
- `happiness-game-admin/server/serviceAccountKey.json` - Firebaseサービスアカウントキー
- `happiness-game-admin/server/ani-reco-firebase-adminsdk-*.json` - Firebase Admin SDK認証情報

### 🟡 .gitignoreで除外済み
- すべての `.env` ファイル（環境変数）
- `node_modules/` ディレクトリ
- `build/` ディレクトリ
- `.vercel/` ディレクトリ
- ログファイル（`*.log`）

## セキュリティチェックリスト

プッシュ前に必ず確認：

1. [ ] `git status` で機密ファイルが含まれていないか確認
2. [ ] `.env` ファイルが追跡されていないか確認
3. [ ] Firebase関連の設定ファイルが除外されているか確認
4. [ ] 個人情報（メールアドレス、電話番号等）が含まれていないか確認

## もし誤って公開してしまった場合

1. **即座に**該当ファイルを削除
2. Firebaseコンソールで新しいキーを生成
3. `git filter-branch` または `BFG Repo-Cleaner` で履歴から完全に削除
4. すべてのサービスアカウントキーを無効化して再発行

## 安全な開発のために

- 環境変数は `.env.example` ファイルにテンプレートを記載
- 本番環境の認証情報は環境変数として管理
- ローカル開発では別の認証情報を使用