import Foundation
import SwiftUI

class ImageExtractor {
    static let shared = ImageExtractor()
    private init() {}
    
    // GitHubのblob URLをraw URLに変換する
    func convertGitHubURLToRaw(_ urlString: String) -> String? {
        // GitHubのblobページURLパターン: https://github.com/user/repo/blob/branch/path
        // これをraw URLに変換: https://raw.githubusercontent.com/user/repo/branch/path
        
        print("🔍 [ImageExtractor] GitHub URL変換チェック: \(urlString)")
        
        if urlString.contains("github.com") && urlString.contains("/blob/") {
            let rawURL = urlString
                .replacingOccurrences(of: "github.com", with: "raw.githubusercontent.com")
                .replacingOccurrences(of: "/blob/", with: "/")
            print("✅ [ImageExtractor] GitHub raw URL変換成功: \(rawURL)")
            return rawURL
        }
        
        print("ℹ️ [ImageExtractor] GitHub URLではありません")
        return nil
    }
    
    // URLからHTMLを取得し、最初の画像URLを抽出する
    func extractFirstImageURL(from urlString: String, completion: @escaping (Result<String, Error>) -> Void) {
        // まずGitHub URLかチェック
        if let githubRawURL = convertGitHubURLToRaw(urlString) {
            // GitHubの画像URLの場合は直接返す
            DispatchQueue.main.async {
                completion(.success(githubRawURL))
            }
            return
        }
        guard let url = URL(string: urlString) else {
            completion(.failure(NSError(domain: "Invalid URL", code: 0, userInfo: nil)))
            return
        }
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            if let error = error {
                DispatchQueue.main.async {
                    completion(.failure(error))
                }
                return
            }
            
            guard let data = data,
                  let html = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async {
                    completion(.failure(NSError(domain: "Failed to parse HTML", code: 0, userInfo: nil)))
                }
                return
            }
            
            // 複数のパターンで画像URLを検索
            let patterns = [
                // <img src="..."> パターン
                #"<img[^>]+src\s*=\s*["']([^"']+)["'][^>]*>"#,
                // og:image メタタグ
                #"<meta[^>]+property\s*=\s*["']og:image["'][^>]+content\s*=\s*["']([^"']+)["'][^>]*>"#,
                // twitter:image メタタグ
                #"<meta[^>]+name\s*=\s*["']twitter:image["'][^>]+content\s*=\s*["']([^"']+)["'][^>]*>"#,
                // data-src属性（遅延読み込み対応）
                #"<img[^>]+data-src\s*=\s*["']([^"']+)["'][^>]*>"#
            ]
            
            var imageURL: String?
            
            for pattern in patterns {
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: html.utf16.count))
                    
                    if let match = matches.first,
                       match.numberOfRanges > 1,
                       let range = Range(match.range(at: 1), in: html) {
                        let extractedURL = String(html[range])
                        
                        // 相対URLを絶対URLに変換
                        if let absoluteURL = self.resolveURL(extractedURL, baseURL: url) {
                            imageURL = absoluteURL
                            break
                        }
                    }
                }
            }
            
            DispatchQueue.main.async {
                if let imageURL = imageURL {
                    completion(.success(imageURL))
                } else {
                    completion(.failure(NSError(domain: "No image found", code: 0, userInfo: nil)))
                }
            }
        }
        
        task.resume()
    }
    
    // 相対URLを絶対URLに変換する
    private func resolveURL(_ urlString: String, baseURL: URL) -> String? {
        // すでに絶対URLの場合はそのまま返す
        if urlString.hasPrefix("http://") || urlString.hasPrefix("https://") {
            return urlString
        }
        
        // プロトコル相対URL（//で始まる）の場合
        if urlString.hasPrefix("//") {
            return baseURL.scheme! + ":" + urlString
        }
        
        // 相対URLの場合
        if let resolved = URL(string: urlString, relativeTo: baseURL) {
            return resolved.absoluteString
        }
        
        return nil
    }
    
    // Pixiv特有のパターンに対応
    func extractPixivImageURL(from urlString: String, completion: @escaping (Result<String, Error>) -> Void) {
        // Pixivの場合、特別な処理が必要な可能性がある
        // 通常の画像抽出を試みる
        extractFirstImageURL(from: urlString) { result in
            switch result {
            case .success(let imageURL):
                // Pixivの画像URLの場合、適切なサイズに変換する可能性がある
                if imageURL.contains("pixiv.net") {
                    // 例: サムネイルURLを通常サイズに変換
                    let modifiedURL = imageURL
                        .replacingOccurrences(of: "_s.", with: "_m.")
                        .replacingOccurrences(of: "_square", with: "")
                    completion(.success(modifiedURL))
                } else {
                    completion(.success(imageURL))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}