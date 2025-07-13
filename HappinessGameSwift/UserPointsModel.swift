import Foundation

struct UserPointsModel: Codable {
    let userId: String
    var points: Int
    let createdAt: Date
    let updatedAt: Date
    
    init(userId: String, points: Int, createdAt: Date = Date(), updatedAt: Date = Date()) {
        self.userId = userId
        self.points = points
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // Firebase用のdictionary形式
    var dictionary: [String: Any] {
        return [
            "userId": userId,
            "points": points,
            "createdAt": createdAt.timeIntervalSince1970,
            "updatedAt": updatedAt.timeIntervalSince1970
        ]
    }
    
    // Firebaseからの初期化
    init?(dictionary: [String: Any]) {
        guard let userId = dictionary["userId"] as? String,
              let points = dictionary["points"] as? Int,
              let createdAtTimestamp = dictionary["createdAt"] as? Double,
              let updatedAtTimestamp = dictionary["updatedAt"] as? Double else {
            return nil
        }
        
        self.userId = userId
        self.points = points
        self.createdAt = Date(timeIntervalSince1970: createdAtTimestamp)
        self.updatedAt = Date(timeIntervalSince1970: updatedAtTimestamp)
    }
}

struct PointTransactionModel: Codable {
    let id: String
    let userId: String
    let amount: Int // 正の値: 追加、負の値: 使用
    let type: TransactionType
    let description: String
    let createdAt: Date
    
    enum TransactionType: String, Codable {
        case purchase = "purchase"      // ポイント購入
        case planPublication = "plan_publication"  // プラン公開
        case adminGrant = "admin_grant"  // 管理者付与
        case planPurchase = "plan_purchase"  // プラン購入
    }
    
    init(id: String = UUID().uuidString, userId: String, amount: Int, type: TransactionType, description: String, createdAt: Date = Date()) {
        self.id = id
        self.userId = userId
        self.amount = amount
        self.type = type
        self.description = description
        self.createdAt = createdAt
    }
    
    // Firebase用のdictionary形式
    var dictionary: [String: Any] {
        return [
            "id": id,
            "userId": userId,
            "amount": amount,
            "type": type.rawValue,
            "description": description,
            "createdAt": createdAt.timeIntervalSince1970
        ]
    }
    
    // Firebaseからの初期化
    init?(dictionary: [String: Any]) {
        guard let id = dictionary["id"] as? String,
              let userId = dictionary["userId"] as? String,
              let amount = dictionary["amount"] as? Int,
              let typeString = dictionary["type"] as? String,
              let type = TransactionType(rawValue: typeString),
              let description = dictionary["description"] as? String,
              let createdAtTimestamp = dictionary["createdAt"] as? Double else {
            return nil
        }
        
        self.id = id
        self.userId = userId
        self.amount = amount
        self.type = type
        self.description = description
        self.createdAt = Date(timeIntervalSince1970: createdAtTimestamp)
    }
}