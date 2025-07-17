import SwiftUI

struct PixivThumbnailView: View {
    let pixivURL: String
    @State private var thumbnailImage: UIImage? = nil
    @State private var isLoading = false
    @State private var loadFailed = false
    
    var body: some View {
        ZStack {
            if let image = thumbnailImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                Color.gray.opacity(0.1)
                VStack(spacing: 8) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else if loadFailed {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 24))
                            .foregroundColor(.orange)
                        Text("読み込めませんでした")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        Text("R18作品は表示できません")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    } else {
                        Image(systemName: "photo")
                            .font(.system(size: 30))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("Pixiv")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
                .padding(8)
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        guard thumbnailImage == nil else { return }
        
        if let artworkId = extractPixivArtworkId(from: pixivURL) {
            isLoading = true
            
            Task {
                // 小さいサムネイル用のURL
                let thumbnailURLs = [
                    "https://embed.pixiv.net/artwork.php?illust_id=\(artworkId)",
                    "https://i.pximg.net/c/360x360_70/img-master/img/\(artworkId)_p0_square1200.jpg",
                    "https://i.pximg.net/img-master/img/\(artworkId)_p0_master1200.jpg"
                ]
                
                for urlString in thumbnailURLs {
                    do {
                        if let url = URL(string: urlString) {
                            let (data, _) = try await URLSession.shared.data(from: url)
                            if let image = UIImage(data: data) {
                                await MainActor.run {
                                    self.thumbnailImage = image
                                    self.isLoading = false
                                }
                                break
                            }
                        }
                    } catch {
                        continue
                    }
                }
                
                await MainActor.run {
                    self.isLoading = false
                    self.loadFailed = true
                }
            }
        }
    }
    
    private func extractPixivArtworkId(from url: String) -> String? {
        let pattern = "artworks/(\\d+)"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: url, options: [], range: NSRange(location: 0, length: url.count)),
           let range = Range(match.range(at: 1), in: url) {
            return String(url[range])
        }
        return nil
    }
}

struct PixivFullscreenView: View {
    let pixivURL: String
    @State private var fullscreenImage: UIImage? = nil
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            if let image = fullscreenImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                Color.black
                VStack(spacing: 16) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(1.5)
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 60))
                            .foregroundColor(.orange)
                    }
                    Text(isLoading ? "Pixiv画像を読み込み中..." : "画像を読み込めませんでした")
                        .font(.headline)
                        .foregroundColor(.white)
                    if !isLoading {
                        Text("R18作品の可能性があります")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                    }
                }
            }
        }
        .onAppear {
            loadFullscreenImage()
        }
    }
    
    private func loadFullscreenImage() {
        guard fullscreenImage == nil else { return }
        
        if let artworkId = extractPixivArtworkId(from: pixivURL) {
            isLoading = true
            
            Task {
                // フルスクリーン用の高解像度URL
                let fullscreenURLs = [
                    "https://i.pximg.net/img-original/img/\(artworkId)_p0.jpg",
                    "https://i.pximg.net/img-original/img/\(artworkId)_p0.png",
                    "https://i.pximg.net/img-master/img/\(artworkId)_p0_master1200.jpg",
                    "https://i.pximg.net/c/1200x1200_80_a2_g5/img-master/img/\(artworkId)_p0_master1200.jpg",
                    "https://embed.pixiv.net/artwork.php?illust_id=\(artworkId)"
                ]
                
                for urlString in fullscreenURLs {
                    do {
                        if let url = URL(string: urlString) {
                            var request = URLRequest(url: url)
                            request.setValue("https://www.pixiv.net/", forHTTPHeaderField: "Referer")
                            request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 14_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
                            
                            let (data, _) = try await URLSession.shared.data(for: request)
                            if let image = UIImage(data: data) {
                                await MainActor.run {
                                    self.fullscreenImage = image
                                    self.isLoading = false
                                }
                                return
                            }
                        }
                    } catch {
                        continue
                    }
                }
                
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
    
    private func extractPixivArtworkId(from url: String) -> String? {
        let pattern = "artworks/(\\d+)"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: url, options: [], range: NSRange(location: 0, length: url.count)),
           let range = Range(match.range(at: 1), in: url) {
            return String(url[range])
        }
        return nil
    }
}