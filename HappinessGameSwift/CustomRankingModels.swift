import Foundation

// カスタムランキングモデル
struct CustomRanking: Codable, Identifiable {
    let id: String?
    let title: String
    let displayProbability: Double
    let isActive: Bool
    let createdAt: Date
    let updatedAt: Date
    let imageURL: String?
    var items: [CustomRankingItem]?
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case displayProbability
        case isActive
        case createdAt
        case updatedAt
        case imageURL
        case items
    }
}

// カスタムランキングアイテムモデル
struct CustomRankingItem: Codable, Identifiable {
    let id: String
    let rank: Int
    let characterName: String
    let characterImageURL: String?
    let customImageURL: String?
    let externalLink: String?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case rank
        case characterName
        case characterImageURL
        case customImageURL
        case externalLink
        case createdAt
    }
}

// カスタムランキング管理クラス
class CustomRankingManager: ObservableObject {
    @Published var activeRankings: [CustomRanking] = []
    @Published var selectedRanking: CustomRanking?
    
    // 確率に基づいてランキングを選択
    func selectRandomRanking() {
        let activeOnly = activeRankings.filter { $0.isActive }
        print("🔍 [CustomRankingManager] selectRandomRanking開始: アクティブランキング数=\(activeOnly.count)")
        
        guard !activeOnly.isEmpty else {
            print("🔍 [CustomRankingManager] アクティブランキングなし")
            selectedRanking = nil
            return
        }
        
        // 確率の合計を計算
        let totalProbability = activeOnly.reduce(0) { $0 + $1.displayProbability }
        print("🔍 [CustomRankingManager] 確率合計: \(totalProbability)")
        
        guard totalProbability > 0 else {
            print("🔍 [CustomRankingManager] 確率合計が0")
            selectedRanking = nil
            return
        }
        
        // ランダムな値を生成
        let randomValue = Double.random(in: 0..<totalProbability)
        print("🔍 [CustomRankingManager] ランダム値: \(randomValue)")
        
        // 確率に基づいて選択
        var accumulator = 0.0
        for ranking in activeOnly {
            accumulator += ranking.displayProbability
            print("🔍 [CustomRankingManager] 累積確率: \(accumulator), ランキング: \(ranking.title)")
            if randomValue < accumulator {
                selectedRanking = ranking
                print("🔍 [CustomRankingManager] 選択されたランキング: \(ranking.title)")
                return
            }
        }
        
        // フォールバック
        selectedRanking = activeOnly.first
        print("🔍 [CustomRankingManager] フォールバック選択: \(activeOnly.first?.title ?? "なし")")
    }
    
    // アクティブなランキングを読み込み
    func loadActiveRankings() {
        print("🔍 [CustomRankingManager] loadActiveRankings開始")
        FirebaseManager.shared.fetchActiveCustomRankings { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let rankings):
                    print("🔍 [CustomRankingManager] アクティブランキング取得成功: \(rankings.count)件")
                    for ranking in rankings {
                        print("🔍   - \(ranking.title): アイテム数=\(ranking.items?.count ?? 0)")
                        print("🔍   - imageURL: \(ranking.imageURL ?? "なし")")
                    }
                    self.activeRankings = rankings
                    self.selectRandomRanking()
                    print("🔍 [CustomRankingManager] 選択されたランキング: \(self.selectedRanking?.title ?? "なし")")
                case .failure(let error):
                    print("❌ [CustomRankingManager] カスタムランキング読み込みエラー: \(error)")
                    self.activeRankings = []
                    self.selectedRanking = nil
                }
            }
        }
    }
}