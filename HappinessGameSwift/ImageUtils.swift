import UIKit

// 画像をドキュメントディレクトリに保存し、ファイルパスを返す
func saveImageToDocuments(_ image: UIImage, fileName: String) -> String? {
    guard let data = image.pngData() else { return nil }
    let fileManager = FileManager.default
    let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
    guard let documentsURL = urls.first else { return nil }
    let fileURL = documentsURL.appendingPathComponent(fileName)
    do {
        try data.write(to: fileURL)
        return fileURL.path
    } catch {
        print("画像保存エラー: \(error)")
        return nil
    }
}

// ファイルパスからUIImageを取得
func loadImageFromPath(_ path: String?) -> UIImage? {
    guard let path = path else { return nil }
    return UIImage(contentsOfFile: path)
} 