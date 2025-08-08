import UIKit

// 画像をキャラクター専用フォルダーに保存
func saveImageToCharacterFolder(_ image: UIImage, characterId: String, fileName: String, quality: CGFloat = 0.8) -> String? {
    guard let data = image.pngData() else { 
        return nil 
    }
    
    let fileManager = FileManager.default
    let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
    guard let documentsURL = urls.first else { 
        return nil 
    }
    
    // キャラクター専用のartworksフォルダーを作成
    let characterArtworksURL = documentsURL.appendingPathComponent("AnirecoImages/characters/\(characterId)/artworks")
    
    do {
        // ディレクトリが存在しない場合は作成
        if !fileManager.fileExists(atPath: characterArtworksURL.path) {
            try fileManager.createDirectory(at: characterArtworksURL, withIntermediateDirectories: true, attributes: nil)
        }
        
        var fileURL = characterArtworksURL.appendingPathComponent(fileName)
        
        // 既存ファイルがある場合は削除
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
        
        try data.write(to: fileURL)
        
        // iCloudバックアップを有効にする
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = false
        try fileURL.setResourceValues(resourceValues)
        
        // ファイルが実際に保存されたか確認
        if fileManager.fileExists(atPath: fileURL.path) {
            let relativePath = "AnirecoImages/characters/\(characterId)/artworks/\(fileName)"
            return relativePath
        } else {
            return nil
        }
    } catch {
        return nil
    }
}

// 画像をアニメ専用フォルダーに保存
func saveImageToAnimeFolder(_ image: UIImage, animeId: String, fileName: String, quality: CGFloat = 0.8) -> String? {
    guard let data = image.pngData() else { 
        return nil 
    }
    
    let fileManager = FileManager.default
    let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
    guard let documentsURL = urls.first else { 
        return nil 
    }
    
    // アニメ専用のartworksフォルダーを作成
    let animeArtworksURL = documentsURL.appendingPathComponent("AnirecoImages/anime/\(animeId)/artworks")
    
    do {
        // ディレクトリが存在しない場合は作成
        if !fileManager.fileExists(atPath: animeArtworksURL.path) {
            try fileManager.createDirectory(at: animeArtworksURL, withIntermediateDirectories: true, attributes: nil)
        }
        
        var fileURL = animeArtworksURL.appendingPathComponent(fileName)
        
        // 既存ファイルがある場合は削除
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
        
        try data.write(to: fileURL)
        
        // iCloudバックアップを有効にする
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = false
        try fileURL.setResourceValues(resourceValues)
        
        // ファイルが実際に保存されたか確認
        if fileManager.fileExists(atPath: fileURL.path) {
            let relativePath = "AnirecoImages/anime/\(animeId)/artworks/\(fileName)"
            return relativePath
        } else {
            return nil
        }
    } catch {
        return nil
    }
}

// 画像をドキュメントディレクトリに保存し、ファイルパスを返す（旧バージョン、互換性のため）
func saveImageToDocuments(_ image: UIImage, fileName: String, quality: CGFloat = 0.8) -> String? {
    // PNG形式で保存を試行
    guard let data = image.pngData() else { 
        return nil 
    }
    
    let fileManager = FileManager.default
    let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
    guard let documentsURL = urls.first else { 
        return nil 
    }
    
    // アプリ専用のサブディレクトリを作成
    let appDirectoryURL = documentsURL.appendingPathComponent("AnirecoImages")
    
    do {
        // ディレクトリが存在しない場合は作成
        if !fileManager.fileExists(atPath: appDirectoryURL.path) {
            try fileManager.createDirectory(at: appDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        }
        
        var fileURL = appDirectoryURL.appendingPathComponent(fileName)
        
        // 既存ファイルがある場合は削除
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
        
        try data.write(to: fileURL)
        
        // iCloudバックアップを有効にする
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = false
        try fileURL.setResourceValues(resourceValues)
        
        // ファイルが実際に保存されたか確認
        if fileManager.fileExists(atPath: fileURL.path) {
            let relativePath = "AnirecoImages/\(fileName)"
            return relativePath
        } else {
            return nil
        }
    } catch {
        return nil
    }
}

// JPEG形式で画像をキャラクターフォルダーに保存
func saveImageToCharacterFolderAsJPEG(_ image: UIImage, characterId: String, fileName: String, quality: CGFloat = 0.8) -> String? {
    guard let data = image.jpegData(compressionQuality: quality) else { 
        return nil 
    }
    
    let fileManager = FileManager.default
    let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
    guard let documentsURL = urls.first else { 
        return nil 
    }
    
    // キャラクター専用のartworksフォルダーを作成
    let characterArtworksURL = documentsURL.appendingPathComponent("AnirecoImages/characters/\(characterId)/artworks")
    
    do {
        // ディレクトリが存在しない場合は作成
        if !fileManager.fileExists(atPath: characterArtworksURL.path) {
            try fileManager.createDirectory(at: characterArtworksURL, withIntermediateDirectories: true, attributes: nil)
        }
        
        var fileURL = characterArtworksURL.appendingPathComponent(fileName)
        
        // 既存ファイルがある場合は削除
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
        
        try data.write(to: fileURL)
        
        // iCloudバックアップを有効にする
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = false
        try fileURL.setResourceValues(resourceValues)
        
        let relativePath = "AnirecoImages/characters/\(characterId)/artworks/\(fileName)"
        return relativePath
    } catch {
        return nil
    }
}

// JPEG形式で画像をアニメフォルダーに保存
func saveImageToAnimeFolderAsJPEG(_ image: UIImage, animeId: String, fileName: String, quality: CGFloat = 0.8) -> String? {
    guard let data = image.jpegData(compressionQuality: quality) else { 
        return nil 
    }
    
    let fileManager = FileManager.default
    let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
    guard let documentsURL = urls.first else { 
        return nil 
    }
    
    // アニメ専用のartworksフォルダーを作成
    let animeArtworksURL = documentsURL.appendingPathComponent("AnirecoImages/anime/\(animeId)/artworks")
    
    do {
        // ディレクトリが存在しない場合は作成
        if !fileManager.fileExists(atPath: animeArtworksURL.path) {
            try fileManager.createDirectory(at: animeArtworksURL, withIntermediateDirectories: true, attributes: nil)
        }
        
        var fileURL = animeArtworksURL.appendingPathComponent(fileName)
        
        // 既存ファイルがある場合は削除
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
        
        try data.write(to: fileURL)
        
        // iCloudバックアップを有効にする
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = false
        try fileURL.setResourceValues(resourceValues)
        
        let relativePath = "AnirecoImages/anime/\(animeId)/artworks/\(fileName)"
        return relativePath
    } catch {
        return nil
    }
}

// JPEG形式で画像を保存（旧バージョン、互換性のため）
func saveImageToDocumentsAsJPEG(_ image: UIImage, fileName: String, quality: CGFloat = 0.8) -> String? {
    guard let data = image.jpegData(compressionQuality: quality) else { 
        return nil 
    }
    
    let fileManager = FileManager.default
    let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
    guard let documentsURL = urls.first else { 
        return nil 
    }
    
    // アプリ専用のサブディレクトリを作成
    let appDirectoryURL = documentsURL.appendingPathComponent("AnirecoImages")
    
    do {
        // ディレクトリが存在しない場合は作成
        if !fileManager.fileExists(atPath: appDirectoryURL.path) {
            try fileManager.createDirectory(at: appDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        }
        
        var fileURL = appDirectoryURL.appendingPathComponent(fileName)
        
        // 既存ファイルがある場合は削除
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
        
        try data.write(to: fileURL)
        
        // iCloudバックアップを有効にする
        var resourceValues = URLResourceValues()
        resourceValues.isExcludedFromBackup = false
        try fileURL.setResourceValues(resourceValues)
        
        let relativePath = "AnirecoImages/\(fileName)"
        return relativePath
    } catch {
        return nil
    }
}

// ファイルパスからUIImageを取得
func loadImageFromPath(_ path: String?) -> UIImage? {
    guard let path = path else { 
        return nil 
    }
    
    
    // 相対パスから絶対パスを構築
    let fileManager = FileManager.default
    guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
        return nil
    }
    
    let absolutePath: String
    if path.hasPrefix("/") {
        // 既存の絶対パスの場合（互換性のため）
        absolutePath = path
    } else {
        // 相対パスの場合
        let fileURL = documentsURL.appendingPathComponent(path)
        absolutePath = fileURL.path
    }
    
    // ファイルの存在確認
    if !fileManager.fileExists(atPath: absolutePath) {
        return nil
    }
    
    let image = UIImage(contentsOfFile: absolutePath)
    if image == nil {
    } else {
    }
    return image
}

// 動画パスからURLを取得
func loadVideoURLFromPath(_ path: String?) -> URL? {
    guard let path = path else {
        return nil
    }
    
    // 相対パスから絶対パスを構築
    let fileManager = FileManager.default
    guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
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
    // 本番環境では何もしない
} 