# Xcode In-App Purchase設定確認手順

## クイックチェックリスト

### 1. Signing & Capabilitiesタブを開く
1. Xcodeでプロジェクトを開く
2. 左側のナビゲーターで **HappinessGameSwift** プロジェクトファイル（青いアイコン）をクリック
3. **HappinessGameSwift** ターゲットを選択
4. 上部のタブから **Signing & Capabilities** をクリック

### 2. In-App Purchase確認
**Capabilities** セクションを確認：
- ✅ **In-App Purchase** が表示されている → 有効
- ❌ 表示されていない → 「+ Capability」をクリックして追加

### 3. Team署名確認
**Signing** セクションで以下を確認：

| 項目 | 正しい状態 | 問題がある場合 |
|------|------------|----------------|
| Automatically manage signing | ✅ チェックあり | チェックを入れる |
| Team | 開発者名/会社名が表示 | Noneの場合は選択 |
| Bundle Identifier | com.anireco.happiness.game | 修正が必要 |
| Provisioning Profile | ✅ 緑のチェック | ❌ 赤いエラー |
| Signing Certificate | Apple Development: 名前 | 証明書エラー |

## よくある問題と解決方法

### 1. Teamが選択できない
- Xcode → Settings → Accounts
- 「+」ボタンでApple IDを追加
- Apple Developer Programに登録済みのアカウントを使用

### 2. Provisioning Profileエラー
- 「Try Again」ボタンをクリック
- またはXcodeを再起動

### 3. Bundle Identifierの不一致
- Info.plistと一致させる必要あり
- 現在は: com.anireco.happiness.game

## 確認完了チェック
- [ ] In-App Purchase capabilityが追加されている
- [ ] Teamが正しく選択されている
- [ ] すべての項目に緑のチェック✅
- [ ] Bundle IDがcom.anireco.happiness.game