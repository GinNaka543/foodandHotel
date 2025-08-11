# GitHub Secrets セットアップガイド

iOS アプリのビルドに必要な GoogleService-Info.plist ファイルを GitHub Secrets に追加する手順です。

## 手順

### 1. GitHubリポジトリの設定ページを開く
1. GitHub で `Happiness game` リポジトリを開く
2. **Settings** タブをクリック
3. 左側のメニューから **Secrets and variables** → **Actions** を選択

### 2. 新しいシークレットを追加

#### シークレット: GOOGLE_SERVICE_INFO_BASE64
1. **New repository secret** ボタンをクリック
2. **Name** フィールドに: `GOOGLE_SERVICE_INFO_BASE64`
3. **Value** フィールドに: `~/Desktop/GoogleService-Info-base64.txt` の内容をコピー＆ペースト
4. **Add secret** をクリック

## Base64 エンコード済みファイルの場所
- `~/Desktop/GoogleService-Info-base64.txt`

## 確認方法
GitHub Actions が実行される際に、これらのシークレットから GoogleService-Info.plist ファイルが自動的に復元されます。

## セキュリティ注意事項
- Base64 エンコード済みファイルも機密情報です
- 使用後は削除することを推奨します
- GitHub Secrets に追加後、ローカルのBase64ファイルは削除して構いません

## トラブルシューティング
もしビルドエラーが続く場合は：
1. シークレット名が正しいか確認
2. Base64 エンコードが正しく行われているか確認
3. GitHub Actions のログを確認