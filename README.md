# Happiness Game Swift

Flutterアプリから移行したiOSネイティブアプリ（Swift + SwiftUI）

## 機能

- **タイトル画面**: BGM付きのスタート画面
- **ホーム画面**: 幸福度メーター、名言ガチャ、クエスト表示
- **メモリー画面**: 画像のアップロード・管理機能
- **ビデオ画面**: 動画のアップロード・再生機能
- **プロフィール画面**: ユーザー情報と設定

## 技術スタック

- **SwiftUI**: モダンなUIフレームワーク
- **Firebase**: 認証、データベース、ストレージ
- **AVFoundation**: 音声・動画処理
- **PhotosUI**: 画像・動画選択
- **Core Data**: ローカルデータ管理

## セットアップ手順

### 1. Xcodeプロジェクトの作成

1. Xcodeを開く
2. "Create a new Xcode project"を選択
3. "App"テンプレートを選択
4. プロジェクト名: `HappinessGameSwift`
5. Interface: `SwiftUI`
6. Language: `Swift`
7. 保存場所: このディレクトリを選択

### 2. ファイルの配置

作成したSwiftファイルをXcodeプロジェクトに追加：

- `HappinessGameSwiftApp.swift` → 既存のAppファイルを置き換え
- `TitleScreen.swift` → 新規追加
- `HomeScreen.swift` → 新規追加
- `MemoryScreen.swift` → 新規追加
- `VideoGalleryScreen.swift` → 新規追加
- `AddPhotoView.swift` → 新規追加
- `AddVideoView.swift` → 新規追加
- `ProfileScreen.swift` → 新規追加

### 3. Firebase設定

1. Firebase Consoleでプロジェクトを作成
2. iOSアプリを追加
3. `GoogleService-Info.plist`をダウンロード
4. Xcodeプロジェクトに追加

### 4. CocoaPods設定

1. ターミナルでプロジェクトディレクトリに移動
2. `pod init`を実行
3. `Podfile`の内容を更新
4. `pod install`を実行
5. `.xcworkspace`ファイルを開く

### 5. 権限設定

`Info.plist`に以下を追加：

```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>写真と動画をアップロードするために使用します</string>
<key>NSCameraUsageDescription</key>
<string>写真と動画を撮影するために使用します</string>
<key>NSMicrophoneUsageDescription</key>
<string>動画撮影時に音声を録音するために使用します</string>
```

### 6. アセット追加

`Assets.xcassets`に以下を追加：
- `title.png` - タイトル画面の画像
- `titlemusic.mp3` - BGMファイル

## ビルドと実行

1. Xcodeで`.xcworkspace`ファイルを開く
2. シミュレータまたは実機を選択
3. `Cmd + R`でビルド・実行

## 移行完了

これでFlutterアプリからSwiftUIアプリへの移行が完了しました。Xcode 16.4との互換性問題も解決され、ネイティブパフォーマンスでアプリが動作します。

## 今後の拡張

- Core Dataによるローカルデータ管理の実装
- Firebase連携の完全実装
- プッシュ通知機能
- アニメーションの追加
- ダークモード対応 