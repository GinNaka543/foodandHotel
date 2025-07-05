import SwiftUI

struct PixivThumbnailView: View {
    let pixivURL: String
    @State private var thumbnailImage: UIImage? = nil
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            if let image = thumbnailImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Color.gray.opacity(0.1)
                VStack {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "photo")
                            .font(.system(size: 30))
                            .foregroundColor(.gray.opacity(0.5))
                    }
                    Text("Pixiv")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
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