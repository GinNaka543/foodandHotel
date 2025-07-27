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
        
        guard !activeOnly.isEmpty else {
            selectedRanking = nil
            return
        }
        
        // 確率の合計を計算
        let totalProbability = activeOnly.reduce(0) { $0 + $1.displayProbability }
        
        guard totalProbability > 0 else {
            selectedRanking = nil
            return
        }
        
        // ランダムな値を生成
        let randomValue = Double.random(in: 0..<totalProbability)
        
        // 確率に基づいて選択
        var accumulator = 0.0
        for ranking in activeOnly {
            accumulator += ranking.displayProbability
            if randomValue < accumulator {
                selectedRanking = ranking
                return
            }
        }
        
        // フォールバック
        selectedRanking = activeOnly.first
    }
    
    // アクティブなランキングを読み込み
    func loadActiveRankings() {
        FirebaseManager.shared.fetchActiveCustomRankings { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let rankings):
                    for ranking in rankings {
                    }
                    self.activeRankings = rankings
                    self.selectRandomRanking()
                case .failure(let error):
                    self.activeRankings = []
                    self.selectedRanking = nil
                }
            }
        }
    }
}