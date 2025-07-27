import SwiftUI

struct AnimeRankingScreen: View {
    @StateObject private var firebaseManager = FirebaseManager.shared
    @State private var advertisements: [Advertisement] = []
    @State private var isLoading = true
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ヘッダー
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.black)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 6) {
                        Text("今おすすめのアニメ")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.black)
                        Text("プロモーション")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.gray)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    
                    Spacer()
                    
                    // 空のスペーサーで右側のバランスを保つ
                    Spacer()
                        .frame(width: 44)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white)
                .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
                
                if isLoading {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 16) {
                            ForEach(advertisements, id: \.id) { ad in
                                Button(action: {
                                    handleAdClick(ad)
                                }) {
                                    ZStack(alignment: .bottom) {
                                        // 画像
                                        if let url = URL(string: convertGitHubUrl(ad.imageURL)), !ad.imageURL.isEmpty {
                                            AsyncImage(url: url) { phase in
                                                switch phase {
                                                case .success(let image):
                                                    image
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                        .frame(height: 158.4)
                                                        .clipped()
                                                case .failure(_):
                                                    Color(.systemGray5)
                                                        .frame(height: 158.4)
                                                        .overlay(
                                                            Image(systemName: "photo")
                                                                .font(.system(size: 30))
                                                                .foregroundColor(.gray)
                                                        )
                                                case .empty:
                                                    Color(.systemGray5)
                                                        .frame(height: 158.4)
                                                        .overlay(
                                                            ProgressView()
                                                        )
                                                @unknown default:
                                                    Color(.systemGray5)
                                                        .frame(height: 158.4)
                                                }
                                            }
                                        } else {
                                            Color(.systemGray5)
                                                .frame(height: 158.4)
                                        }
                                        
                                        // タイトルオーバーレイ
                                        VStack {
                                            Spacer()
                                            HStack {
                                                Text(ad.title)
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundColor(.white)
                                                    .lineLimit(2)
                                                    .padding(.horizontal, 8)
                                                    .padding(.vertical, 6)
                                                Spacer()
                                            }
                                            .background(
                                                // ブラー効果の背景
                                                VisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
                                                    .opacity(0.7)
                                            )
                                        }
                                    }
                                    .frame(maxWidth: .infinity)
                                    .cornerRadius(10)
                                    .clipped()
                                }
                                .buttonStyle(PlainButtonStyle())
                                .onAppear {
                                    recordImpression(for: ad)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 16)
                    }
                }
            }
            .background(Color.white)
        }
        .navigationBarHidden(true)
        .onAppear {
            loadAnimeAds()
        }
    }
    
    private func loadAnimeAds() {
        isLoading = true
        firebaseManager.fetchAds(for: "anime") { result in
            switch result {
            case .success(let ads):
                self.advertisements = ads
                self.isLoading = false
            case .failure(let error):
                self.isLoading = false
            }
        }
    }
    
    private func handleAdClick(_ ad: Advertisement) {
        
        // クリックを記録
        if let adId = ad.id {
            firebaseManager.recordAdClick(advertisementId: adId)
        }
        
        // URLを開く
        if let url = URL(string: ad.linkURL) {
            UIApplication.shared.open(url)
        }
    }
    
    private func recordImpression(for ad: Advertisement) {
        if let adId = ad.id {
            firebaseManager.recordAdImpression(advertisementId: adId)
        }
    }
    
    private func convertGitHubUrl(_ url: String) -> String {
        if url.contains("github.com") && url.contains("/blob/") {
            return url
                .replacingOccurrences(of: "github.com", with: "raw.githubusercontent.com")
                .replacingOccurrences(of: "/blob/", with: "/")
        }
        return url
    }
}

#Preview {
    AnimeRankingScreen()
}