import Foundation

struct PointPackage {
    let points: Int
    let price: Int
    let isPopular: Bool
    
    var pricePerPoint: Double {
        return Double(price) / Double(points)
    }
}

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

// MARK: - 購入明細書モデル
struct PurchaseReceipt: Codable, Identifiable {
    let id: UUID
    let purchaseDate: Date
    let transactionType: PurchaseTransactionType
    let amount: Int
    let points: Int
    let paymentMethod: PaymentMethod
    let status: PurchaseStatus
    let description: String
    let receiptNumber: String
    
    enum PurchaseTransactionType: String, Codable, CaseIterable {
        case pointPurchase = "ポイント購入"
        case planPurchase = "プラン購入"
        case subscription = "月額課金"
        case premiumUpgrade = "プレミアムアップグレード"
        
        var displayName: String {
            return self.rawValue
        }
    }
    
    enum PaymentMethod: String, Codable, CaseIterable {
        case creditCard = "クレジットカード"
        case applePay = "Apple Pay"
        case googlePay = "Google Pay"
        case points = "ポイント"
        
        var displayName: String {
            return self.rawValue
        }
    }
    
    enum PurchaseStatus: String, Codable {
        case completed = "完了"
        case pending = "処理中"
        case failed = "失敗"
        case refunded = "返金済み"
        
        var displayName: String {
            return self.rawValue
        }
    }
    
    init(transactionType: PurchaseTransactionType, amount: Int, points: Int, paymentMethod: PaymentMethod, description: String) {
        self.id = UUID()
        self.purchaseDate = Date()
        self.transactionType = transactionType
        self.amount = amount
        self.points = points
        self.paymentMethod = paymentMethod
        self.status = .completed
        self.description = description
        self.receiptNumber = PurchaseReceipt.generateReceiptNumber()
    }
    
    private static func generateReceiptNumber() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd"
        let dateString = dateFormatter.string(from: Date())
        let randomNumber = String(format: "%04d", Int.random(in: 1000...9999))
        return "AR\(dateString)\(randomNumber)"
    }
    
    var formattedAmount: String {
        return "¥\(NumberFormatter.localizedString(from: NSNumber(value: amount), number: .decimal))"
    }
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "ja_JP")
        return formatter.string(from: purchaseDate)
    }
}

// MARK: - 購入履歴管理
class PurchaseReceiptManager: ObservableObject {
    static let shared = PurchaseReceiptManager()
    
    @Published var receipts: [PurchaseReceipt] = []
    
    private let receiptsKey = "purchase_receipts"
    
    private init() {
        loadReceipts()
    }
    
    func addReceipt(_ receipt: PurchaseReceipt) {
        receipts.insert(receipt, at: 0) // 新しいものを先頭に
        saveReceipts()
    }
    
    func removeReceipt(_ receipt: PurchaseReceipt) {
        receipts.removeAll { $0.id == receipt.id }
        saveReceipts()
    }
    
    private func saveReceipts() {
        do {
            let data = try JSONEncoder().encode(receipts)
            UserDefaults.standard.set(data, forKey: receiptsKey)
        } catch {
            #if DEBUG
            print("Failed to save receipts: \(error)")
            #endif
        }
    }
    
    private func loadReceipts() {
        guard let data = UserDefaults.standard.data(forKey: receiptsKey) else { return }
        
        do {
            receipts = try JSONDecoder().decode([PurchaseReceipt].self, from: data)
        } catch {
            #if DEBUG
            print("Failed to load receipts: \(error)")
            #endif
            receipts = []
        }
    }
    
    func getReceiptsByType(_ type: PurchaseReceipt.PurchaseTransactionType) -> [PurchaseReceipt] {
        return receipts.filter { $0.transactionType == type }
    }
    
    func getTotalSpent() -> Int {
        return receipts.reduce(0) { $0 + $1.amount }
    }
    
    func getTotalPointsPurchased() -> Int {
        return receipts.filter { $0.transactionType == .pointPurchase }.reduce(0) { $0 + $1.points }
    }
}