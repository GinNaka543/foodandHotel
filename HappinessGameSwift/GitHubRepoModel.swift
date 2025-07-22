import Foundation

// GitHubリポジトリ設定モデル
struct GitHubRepository: Codable {
    let id: String
    let owner: String
    let name: String
    let token: String
    let branch: String
    let createdAt: Date
    let isActive: Bool
    var currentSize: Int64 // バイト単位
    let maxSize: Int64 // 10GB = 10737418240 bytes
    let imageCount: Int
    let basePath: String // 例: "visit-plans"
    
    init(
        id: String = UUID().uuidString,
        owner: String,
        name: String,
        token: String,
        branch: String = "main",
        createdAt: Date = Date(),
        isActive: Bool = true,
        currentSize: Int64 = 0,
        maxSize: Int64 = 10737418240, // 10GB
        imageCount: Int = 0,
        basePath: String = "visit-plans"
    ) {
        self.id = id
        self.owner = owner
        self.name = name
        self.token = token
        self.branch = branch
        self.createdAt = createdAt
        self.isActive = isActive
        self.currentSize = currentSize
        self.maxSize = maxSize
        self.imageCount = imageCount
        self.basePath = basePath
    }
    
    // 残り容量を計算（MB単位）
    var remainingSpaceMB: Double {
        Double(maxSize - currentSize) / 1024 / 1024
    }
    
    // 使用率を計算（パーセント）
    var usagePercentage: Double {
        Double(currentSize) / Double(maxSize) * 100
    }
    
    // 容量がいっぱいかチェック（90%以上で警告）
    var isNearCapacity: Bool {
        usagePercentage >= 90
    }
    
    // Firebaseとの連携用
    var dictionary: [String: Any] {
        return [
            "id": id,
            "owner": owner,
            "name": name,
            "token": token,
            "branch": branch,
            "createdAt": createdAt.timeIntervalSince1970,
            "isActive": isActive,
            "currentSize": currentSize,
            "maxSize": maxSize,
            "imageCount": imageCount,
            "basePath": basePath
        ]
    }
    
    // Firebaseからの初期化
    init?(dictionary: [String: Any]) {
        guard let id = dictionary["id"] as? String,
              let owner = dictionary["owner"] as? String,
              let name = dictionary["name"] as? String,
              let token = dictionary["token"] as? String,
              let branch = dictionary["branch"] as? String,
              let createdAtTimestamp = dictionary["createdAt"] as? Double,
              let isActive = dictionary["isActive"] as? Bool,
              let currentSize = dictionary["currentSize"] as? Int64,
              let maxSize = dictionary["maxSize"] as? Int64,
              let imageCount = dictionary["imageCount"] as? Int,
              let basePath = dictionary["basePath"] as? String else {
            return nil
        }
        
        self.id = id
        self.owner = owner
        self.name = name
        self.token = token
        self.branch = branch
        self.createdAt = Date(timeIntervalSince1970: createdAtTimestamp)
        self.isActive = isActive
        self.currentSize = currentSize
        self.maxSize = maxSize
        self.imageCount = imageCount
        self.basePath = basePath
    }
}

// リポジトリ管理設定
struct GitHubRepoSettings: Codable {
    var repositories: [GitHubRepository]
    var activeRepoId: String? // 現在使用中のリポジトリID
    var totalImagesUploaded: Int
    var lastUpdated: Date
    
    init() {
        self.repositories = []
        self.activeRepoId = nil
        self.totalImagesUploaded = 0
        self.lastUpdated = Date()
    }
    
    // アクティブなリポジトリを取得
    var activeRepository: GitHubRepository? {
        guard let activeId = activeRepoId else { return nil }
        return repositories.first { $0.id == activeId && $0.isActive }
    }
    
    // 利用可能なリポジトリを取得（容量に余裕があるもの）
    func getAvailableRepository() -> GitHubRepository? {
        return repositories
            .filter { $0.isActive && !$0.isNearCapacity }
            .sorted { $0.usagePercentage < $1.usagePercentage }
            .first
    }
}

// 画像アップロード記録
struct GitHubImageRecord: Codable {
    let id: String
    let fileName: String
    let repoId: String
    let path: String
    let size: Int64
    let uploadedAt: Date
    let uploadedBy: String // userId
    let type: String // "visit-plan", "spot", etc.
    
    var dictionary: [String: Any] {
        return [
            "id": id,
            "fileName": fileName,
            "repoId": repoId,
            "path": path,
            "size": size,
            "uploadedAt": uploadedAt.timeIntervalSince1970,
            "uploadedBy": uploadedBy,
            "type": type
        ]
    }
}