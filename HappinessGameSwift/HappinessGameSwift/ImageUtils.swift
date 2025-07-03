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
    
    let fileURL = documentsURL.appendingPathComponent(fileName)
    
    do {
        // 既存ファイルがある場合は削除
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
        
        try data.write(to: fileURL)
        print("画像保存成功: \(fileURL.path)")
        return fileURL.path
    } catch {
        print("画像保存エラー: \(error)")
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
    
    let fileURL = documentsURL.appendingPathComponent(fileName)
    
    do {
        // 既存ファイルがある場合は削除
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
        }
        
        try data.write(to: fileURL)
        print("JPEG画像保存成功: \(fileURL.path)")
        return fileURL.path
    } catch {
        print("JPEG画像保存エラー: \(error)")
        return nil
    }
}

// ファイルパスからUIImageを取得
func loadImageFromPath(_ path: String?) -> UIImage? {
    guard let path = path else { 
        print("画像パスがnil")
        return nil 
    }
    
    let image = UIImage(contentsOfFile: path)
    if image == nil {
        print("画像読み込み失敗: \(path)")
    }
    return image
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