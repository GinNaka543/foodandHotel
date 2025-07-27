import SwiftUI
import Foundation

struct PixivConfirmationScreen: View {
    let artwork: Artwork
    @Environment(\.presentationMode) var presentationMode
    @State private var showSafari = false
    @State private var thumbnailImage: UIImage? = nil
    @State private var isLoadingThumbnail = false
    
    var body: some View {
        VStack(spacing: 24) {
            // タイトル
            Text(NSLocalizedString("open_in_pixiv_question", comment: "Open in Pixiv?"))
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top, 40)
            
            // サムネイルまたはプレースホルダー
            ZStack {
                if let thumbnailImage = thumbnailImage {
                    Image(uiImage: thumbnailImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                        .cornerRadius(12)
                        .shadow(radius: 5)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 250)
                        .overlay(
                            VStack(spacing: 16) {
                                if isLoadingThumbnail {
                                    ProgressView()
                                        .scaleEffect(1.5)
                                } else {
                                    Image(systemName: "photo")
                                        .font(.system(size: 60))
                                        .foregroundColor(.gray)
                                }
                                Text(NSLocalizedString("pixiv_artwork", comment: "Pixiv Artwork"))
                                    .font(.headline)
                                    .foregroundColor(.gray)
                            }
                        )
                }
            }
            
            // 作品情報
            VStack(spacing: 12) {
                Text(artwork.title)
                    .font(.headline)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                if !artwork.tags.isEmpty {
                    Text("#" + artwork.tags.joined(separator: " #"))
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                if let pixivURL = artwork.pixivURL {
                    Text(pixivURL)
                        .font(.caption2)
                        .foregroundColor(.blue)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .padding(.horizontal)
                }
            }
            
            Spacer()
            
            // ボタン
            VStack(spacing: 16) {
                Button(action: {
                    if let pixivURL = artwork.pixivURL,
                       let url = URL(string: pixivURL) {
                        UIApplication.shared.open(url)
                    }
                }) {
                    Text(NSLocalizedString("open_in_pixiv", comment: "Open in Pixiv"))
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.orange)
                        .cornerRadius(12)
                }
                
                Button(action: {
                    presentationMode.wrappedValue.dismiss()
                }) {
                    Text(NSLocalizedString("cancel", comment: "Cancel"))
                        .font(.headline)
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(12)
                }
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 32)
        }
        .navigationBarHidden(true)
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        // Pixiv URLからサムネイルを生成
        guard let pixivURL = artwork.pixivURL else { return }
        
        // pixivのartwork IDを抽出
        if let artworkId = extractPixivArtworkId(from: pixivURL) {
            // Pixivのサムネイル URL パターン
            let thumbnailURL = "https://img-master.pixiv.net/img-master/img/\(artworkId)_p0_master1200.jpg"
            
            isLoadingThumbnail = true
            
            // 非同期でサムネイルを読み込む
            Task {
                do {
                    if let url = URL(string: thumbnailURL) {
                        let (data, _) = try await URLSession.shared.data(from: url)
                        if let image = UIImage(data: data) {
                            await MainActor.run {
                                self.thumbnailImage = image
                                self.isLoadingThumbnail = false
                            }
                        }
                    }
                } catch {
                    // エラーの場合は代替URLを試す
                    await tryAlternativeThumbnailURL(artworkId: artworkId)
                }
            }
        }
    }
    
    private func extractPixivArtworkId(from url: String) -> String? {
        // URLから artwork ID を抽出
        // 例: https://www.pixiv.net/artworks/123456789
        let pattern = "artworks/(\\d+)"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: url, options: [], range: NSRange(location: 0, length: url.count)),
           let range = Range(match.range(at: 1), in: url) {
            return String(url[range])
        }
        return nil
    }
    
    private func tryAlternativeThumbnailURL(artworkId: String) async {
        // 代替URLパターンを試す
        let alternativeURLs = [
            "https://img-original.pixiv.net/img-original/img/\(artworkId)_p0.jpg",
            "https://img-original.pixiv.net/img-original/img/\(artworkId)_p0.png"
        ]
        
        for urlString in alternativeURLs {
            do {
                if let url = URL(string: urlString) {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    if let image = UIImage(data: data) {
                        await MainActor.run {
                            self.thumbnailImage = image
                            self.isLoadingThumbnail = false
                        }
                        break
                    }
                }
            } catch {
                continue
            }
        }
        
        // すべて失敗した場合
        await MainActor.run {
            self.isLoadingThumbnail = false
        }
    }
}