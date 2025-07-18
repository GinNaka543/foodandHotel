import UIKit

// 画像をドキュメントディレクトリに保存し、ファイルパスを返す
func saveImageToDocuments(_ image: UIImage, fileName: String, quality: CGFloat = 0.8) -> String? {
    // PNG形式で保存を試行
    guard let data = image.pngData() else { 
        print("画像データの変換に失敗")
        return nil 
    }
    
    let fileManager = FileManager.default
    let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
    guard let documentsURL = urls.first else { 
        print("Documentsディレクトリの取得に失敗")
        return nil 
    }
    
    // アプリ専用のサブディレクトリを作成
    let appDirectoryURL = documentsURL.appendingPathComponent("AnirecoImages")
    
    do {
        // ディレクトリが存在しない場合は作成
        if !fileManager.fileExists(atPath: appDirectoryURL.path) {
            print("AnirecoImagesディレクトリを作成: \(appDirectoryURL.path)")
            try fileManager.createDirectory(at: appDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        }
        
        let fileURL = appDirectoryURL.appendingPathComponent(fileName)
        print("保存先パス: \(fileURL.path)")
        
        // 既存ファイルがある場合は削除
        if fileManager.fileExists(atPath: fileURL.path) {
            print("既存ファイルを削除: \(fileURL.path)")
            try fileManager.removeItem(at: fileURL)
        }
        
        try data.write(to: fileURL)
        
        // ファイルが実際に保存されたか確認
        if fileManager.fileExists(atPath: fileURL.path) {
            let relativePath = "AnirecoImages/\(fileName)"
            print("画像保存成功: \(relativePath)")
            print("ファイルサイズ: \(data.count) bytes")
            return relativePath
        } else {
            print("エラー: ファイルが作成されませんでした")
            return nil
        }
    } catch {
        print("画像保存エラー: \(error)")
        print("エラー詳細: \(error.localizedDescription)")
        return nil
    }
}

// JPEG形式で画像を保存
func saveImageToDocumentsAsJPEG(_ image: UIImage, fileName: String, quality: CGFloat = 0.8) -> String? {
    guard let data = image.jpegData(compressionQuality: quality) else { 
        print("JPEG画像データの変換に失敗")
        return nil 
    }
    
    let fileManager = FileManager.default
    let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
    guard let documentsURL = urls.first else { 
        print("Documentsディレクトリの取得に失敗")
        return nil 
    }
    
    // アプリ専用のサブディレクトリを作成
    let appDirectoryURL = documentsURL.appendingPathComponent("AnirecoImages")
    
    do {
        // ディレクトリが存在しない場合は作成
        if !fileManager.fileExists(atPath: appDirectoryURL.path) {
            try fileManager.createDirectory(at: appDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        }
        
        let fileURL = appDirectoryURL.appendingPathComponent(fileName)
        
        // 既存ファイルがある場合は削除
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
        
        try data.write(to: fileURL)
        let relativePath = "AnirecoImages/\(fileName)"
        print("JPEG画像保存成功: \(relativePath)")
        return relativePath
    } catch {
        print("JPEG画像保存エラー: \(error)")
        return nil
    }
}

// ファイルパスからUIImageを取得
func loadImageFromPath(_ path: String?) -> UIImage? {
    guard let path = path else { 
        print("[loadImageFromPath] 画像パスがnil")
        return nil 
    }
    
    print("[loadImageFromPath] 読み込み開始: path=\(path)")
    
    // 相対パスから絶対パスを構築
    let fileManager = FileManager.default
    guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
        print("[loadImageFromPath] Documentsディレクトリの取得に失敗")
        return nil
    }
    
    let absolutePath: String
    if path.hasPrefix("/") {
        // 既存の絶対パスの場合（互換性のため）
        absolutePath = path
        print("[loadImageFromPath] 絶対パスを使用: \(absolutePath)")
    } else {
        // 相対パスの場合
        let fileURL = documentsURL.appendingPathComponent(path)
        absolutePath = fileURL.path
        print("[loadImageFromPath] 相対パスから絶対パスを構築: \(absolutePath)")
    }
    
    // ファイルの存在確認
    if !fileManager.fileExists(atPath: absolutePath) {
        print("[loadImageFromPath] ❌ ファイルが存在しません: \(absolutePath)")
        return nil
    }
    
    let image = UIImage(contentsOfFile: absolutePath)
    if image == nil {
        print("[loadImageFromPath] ❌ 画像読み込み失敗: \(absolutePath) (元のパス: \(path))")
    } else {
        print("[loadImageFromPath] ✅ 画像読み込み成功: \(path)")
    }
    return image
}

// 動画パスからURLを取得
func loadVideoURLFromPath(_ path: String?) -> URL? {
    guard let path = path else {
        print("動画パスがnil")
        return nil
    }
    
    // 相対パスから絶対パスを構築
    let fileManager = FileManager.default
    guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
        print("Documentsディレクトリの取得に失敗")
        return nil
    }
    
    let absoluteURL: URL
    if path.hasPrefix("/") {
        // 既存の絶対パスの場合（互換性のため）
        absoluteURL = URL(fileURLWithPath: path)
    } else {
        // 相対パスの場合
        absoluteURL = documentsURL.appendingPathComponent(path)
    }
    
    // ファイルが存在するかチェック
    if fileManager.fileExists(atPath: absoluteURL.path) {
        return absoluteURL
    } else {
        print("動画ファイルが見つかりません: \(absoluteURL.path) (元のパス: \(path))")
        return nil
    }
}

// 開発用: サンプル画像を生成する関数
func generateSampleImage(size: CGSize = CGSize(width: 200, height: 200), color: UIColor = .systemBlue) -> UIImage {
    let renderer = UIGraphicsImageRenderer(size: size)
    return renderer.image { context in
        color.setFill()
        context.fill(CGRect(origin: .zero, size: size))
        
        // 簡単なパターンを追加
        UIColor.white.setFill()
        context.cgContext.setAlpha(0.3)
        context.fill(CGRect(x: size.width * 0.2, y: size.height * 0.2, width: size.width * 0.6, height: size.height * 0.6))
    }
}

// 開発用: サンプル画像をDocumentsディレクトリに保存
func createSampleImagesIfNeeded() {
    #if DEBUG
    let fileManager = FileManager.default
    let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
    guard let documentsURL = urls.first else { return }
    
    // サンプル画像のファイル名
    let sampleImageNames = [
        "sample_character_1.png",
        "sample_character_2.png", 
        "sample_anime_1.png",
        "sample_artwork_1.png"
    ]
    
    for (index, fileName) in sampleImageNames.enumerated() {
        let fileURL = documentsURL.appendingPathComponent(fileName)
        
        // ファイルが存在しない場合のみ作成
        if !fileManager.fileExists(atPath: fileURL.path) {
            let colors: [UIColor] = [.systemBlue, .systemGreen, .systemOrange, .systemPurple]
            let sampleImage = generateSampleImage(color: colors[index % colors.count])
            
            if let data = sampleImage.pngData() {
                try? data.write(to: fileURL)
                print("サンプル画像作成: \(fileName)")
            }
        }
    }
    #endif
} 