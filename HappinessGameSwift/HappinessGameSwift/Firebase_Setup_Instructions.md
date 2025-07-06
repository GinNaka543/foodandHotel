# Firebase セットアップ手順

## 1. Firebase SDKのインストール

### Swift Package Managerを使用する場合：

1. Xcodeでプロジェクトを開く
2. File → Add Package Dependencies...
3. URLに以下を入力：
   ```
   https://github.com/firebase/firebase-ios-sdk
   ```
4. 以下のパッケージを選択：
   - FirebaseCore
   - FirebaseFirestore
   - FirebaseAuth

### CocoaPodsを使用する場合：

1. Podfileを作成（ない場合）:
   ```bash
   cd /path/to/HappinessGameSwift
   pod init
   ```

2. Podfileに以下を追加：
   ```ruby
   pod 'Firebase/Core'
   pod 'Firebase/Firestore'
   pod 'Firebase/Auth'
   ```

3. インストール：
   ```bash
   pod install
   ```

## 2. Firebase プロジェクトの設定

1. [Firebase Console](https://console.firebase.google.com/)にアクセス
2. 新しいプロジェクトを作成
3. iOSアプリを追加
4. `GoogleService-Info.plist`をダウンロード
5. XcodeプロジェクトにGoogleService-Info.plistを追加

## 3. AppDelegateの設定

AppDelegate.swiftまたはApp.swiftに以下を追加：

```swift
import FirebaseCore

// SwiftUIアプリの場合
@main
struct HappinessGameSwiftApp: App {
    init() {
        FirebaseApp.configure()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

## 4. Firestoreの設定

1. Firebase ConsoleでFirestoreを有効化
2. セキュリティルールを設定（開発用）：
   ```
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /{document=**} {
         allow read, write: if true;
       }
     }
   }
   ```

## 5. FirebaseManagerのコメントを解除

`FirebaseManager.swift`のコメントアウトされたコードを有効化します。

## 6. 管理画面用の秘密鍵

1. Firebase Console → プロジェクト設定 → サービスアカウント
2. 「秘密鍵を生成」をクリック
3. ダウンロードしたJSONファイルを`happiness-game-admin/server/serviceAccountKey.json`として保存

## 注意事項

- 本番環境では適切なセキュリティルールを設定してください
- GoogleService-Info.plistとserviceAccountKey.jsonはGitにコミットしないでください