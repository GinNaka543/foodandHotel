import Foundation

// MARK: - 購入明細書モデル
struct PurchaseReceipt: Codable, Identifiable {
    let id: UUID
    let purchaseDate: Date
    let transactionType: TransactionType
    let amount: Int
    let points: Int
    let paymentMethod: PaymentMethod
    let status: PurchaseStatus
    let description: String
    let receiptNumber: String
    
    enum TransactionType: String, Codable, CaseIterable {
        case pointPurchase = "ポイント購入"
        case planPurchase = "プラン購入"
        case subscription = "月額課金"
        
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
    
    init(transactionType: TransactionType, amount: Int, points: Int, paymentMethod: PaymentMethod, description: String) {
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
            print("Failed to save receipts: \(error)")
        }
    }
    
    private func loadReceipts() {
        guard let data = UserDefaults.standard.data(forKey: receiptsKey) else { return }
        
        do {
            receipts = try JSONDecoder().decode([PurchaseReceipt].self, from: data)
        } catch {
            print("Failed to load receipts: \(error)")
            receipts = []
        }
    }
    
    func getReceiptsByType(_ type: PurchaseReceipt.TransactionType) -> [PurchaseReceipt] {
        return receipts.filter { $0.transactionType == type }
    }
    
    func getTotalSpent() -> Int {
        return receipts.reduce(0) { $0 + $1.amount }
    }
    
    func getTotalPointsPurchased() -> Int {
        return receipts.filter { $0.transactionType == .pointPurchase }.reduce(0) { $0 + $1.points }
    }
}