import SwiftUI

struct MultipleFirebaseAdView: View {
    let placement: String
    @State private var advertisements: [Advertisement] = []
    @State private var isLoading = true
    private let firebaseManager = FirebaseManager.shared
    @EnvironmentObject var characterManager: CharacterManager
    @EnvironmentObject var animeManager: AnimeManager
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView()
                    .frame(height: 60)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            } else if !advertisements.isEmpty {
                VStack(spacing: 16) {
                    ForEach(advertisements, id: \.id) { ad in
                        ProductAdCard(ad: ad, firebaseManager: firebaseManager)
                    }
                }
            }
        }
        .onAppear {
            loadAds()
        }
    }
    
    private func loadAds() {
        // ユーザーのアニメ、キャラクター、ハッシュタグを取得
        let userAnimes = animeManager.animes.map { $0.title }
        let userCharacters = characterManager.characters.map { $0.name }
        let userHashtags: [String] = [] // 現在はハッシュタグ機能がないため空配列
        
        firebaseManager.fetchAds(for: placement) { result in
            switch result {
            case .success(let ads):
                // ターゲティングされた広告のフィルタリング
                let targetedAds = ads.filter { ad in
                    // displayRateに基づいて確率的に表示するかを決定
                    let shouldDisplay = Double.random(in: 0...100) <= ad.displayRate
                    guard shouldDisplay else { return false }
                    
                    // ターゲティング条件のチェック
                    let animeMatch = ad.targetAnimes.isEmpty || ad.targetAnimes.contains(where: userAnimes.contains)
                    let characterMatch = ad.targetCharacters.isEmpty || ad.targetCharacters.contains(where: userCharacters.contains)
                    let hashtagMatch = ad.targetHashtags.isEmpty || ad.targetHashtags.contains(where: userHashtags.contains)
                    
                    return animeMatch && characterMatch && hashtagMatch
                }
                
                // 優先度でソート
                let sortedAds = targetedAds.sorted { first, second in
                    // ターゲティング一致数を計算
                    let firstMatches = countMatches(ad: first, animes: userAnimes, characters: userCharacters, hashtags: userHashtags)
                    let secondMatches = countMatches(ad: second, animes: userAnimes, characters: userCharacters, hashtags: userHashtags)
                    
                    // ターゲティング一致数が多い方を優先
                    if firstMatches != secondMatches {
                        return firstMatches > secondMatches
                    }
                    
                    // 一致数が同じ場合は優先度で比較
                    return first.priority > second.priority
                }
                
                self.advertisements = sortedAds
                self.isLoading = false
            case .failure(let error):
                self.advertisements = []
                self.isLoading = false
            }
        }
    }
    
    private func countMatches(ad: Advertisement, animes: [String], characters: [String], hashtags: [String]) -> Int {
        let animeMatches = ad.targetAnimes.filter { animes.contains($0) }.count
        let characterMatches = ad.targetCharacters.filter { characters.contains($0) }.count
        let hashtagMatches = ad.targetHashtags.filter { hashtags.contains($0) }.count
        return animeMatches + characterMatches + hashtagMatches
    }
}

struct ProductAdCard: View {
    let ad: Advertisement
    let firebaseManager: FirebaseManager
    
    var body: some View {
        Button(action: {
            handleAdClick()
        }) {
            ZStack(alignment: .topTrailing) {
                HStack(spacing: 16) {
                    // 広告画像
                    if let url = URL(string: convertGitHubUrl(ad.imageURL)), !ad.imageURL.isEmpty {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                            case .failure(_):
                                Color(.systemGray5)
                                    .overlay(
                                        Text("画像エラー")
                                            .font(.caption)
                                            .foregroundColor(.red)
                                    )
                            case .empty:
                                ProgressView()
                            @unknown default:
                                Color(.systemGray5)
                            }
                        }
                        .frame(width: 168.48, height: 99)
                        .cornerRadius(10)
                        .clipped()
                    } else {
                        Color(.systemGray5)
                            .frame(width: 168.48, height: 99)
                            .cornerRadius(10)
                            .clipped()
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(ad.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)
                            .lineLimit(2)
                        Text(ad.description)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                    Spacer()
                }
                .padding(16)
                .cornerRadius(12)
                
                // PRバッジ
                Text("PR")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.purple)
                    .cornerRadius(4)
                    .padding(8)
            }
        }
        .buttonStyle(PlainButtonStyle())
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, -4)
        .onAppear {
            firebaseManager.recordAdImpression(advertisementId: ad.id ?? "")
        }
    }
    
    private func handleAdClick() {
        if let url = URL(string: ad.linkURL) {
            firebaseManager.recordAdClick(advertisementId: ad.id ?? "")
            UIApplication.shared.open(url)
        }
    }
    
    private func convertGitHubUrl(_ urlString: String) -> String {
        if urlString.contains("github.com") && !urlString.contains("raw.githubusercontent.com") {
            return urlString
                .replacingOccurrences(of: "github.com", with: "raw.githubusercontent.com")
                .replacingOccurrences(of: "/blob/", with: "/")
        }
        return urlString
    }
}