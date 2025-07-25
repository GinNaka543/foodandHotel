import Foundation
import StoreKit
import SwiftUI

class StoreKitManager: NSObject, ObservableObject {
    static let shared = StoreKitManager()
    
    @Published var products: [SKProduct] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var productRequest: SKProductsRequest?
    private var paymentQueue = SKPaymentQueue.default()
    private var purchaseCompletionHandler: ((Result<String, Error>) -> Void)?
    
    // Product IDの定義（App Store Connectで設定したものと一致させる）
    private let productIds = Set([
        "com.nakajima.HappinessGameSwift.points.100.v2",
        "com.nakajima.HappinessGameSwift.points.500.v2",
        "com.nakajima.HappinessGameSwift.points.1000.v2",
        "com.nakajima.HappinessGameSwift.points.2000.v2"
    ])
    
    override init() {
        super.init()
        
        #if DEBUG
        print("Bundle ID: \(Bundle.main.bundleIdentifier ?? "nil")")
        print("Product IDs: \(productIds)")
        #endif
        
        // 支払いキューのオブザーバーとして登録
        paymentQueue.add(self)
        
        // 初期商品読み込み
        loadProducts()
    }
    
    deinit {
        paymentQueue.remove(self)
    }
    
    // MARK: - 商品の読み込み
    func loadProducts() {
        isLoading = true
        errorMessage = nil
        
        let request = SKProductsRequest(productIdentifiers: productIds)
        request.delegate = self
        productRequest = request
        request.start()
    }
    
    // MARK: - 購入処理
    func purchase(_ product: SKProduct, completion: @escaping (Result<String, Error>) -> Void) {
        guard SKPaymentQueue.canMakePayments() else {
            completion(.failure(StoreError.paymentsNotAllowed))
            return
        }
        
        purchaseCompletionHandler = completion
        
        let payment = SKPayment(product: product)
        paymentQueue.add(payment)
        
        #if DEBUG
        print("Attempting to purchase: \(product.localizedTitle)")
        #endif
    }
    
    // MARK: - 購入履歴の復元
    func restorePurchases() {
        paymentQueue.restoreCompletedTransactions()
    }
    
    // MARK: - Product IDからポイント数を抽出
    private func extractPoints(from productId: String) -> Int {
        // "com.nakajima.HappinessGameSwift.points.1000.v2" -> 1000
        let components = productId.split(separator: ".")
        // points.1000.v2 の場合、インデックス4が数値
        if components.count >= 5,
           let points = Int(components[4]) {
            return points
        }
        return 0
    }
    
    // MARK: - 購入成功時の処理
    private func handleSuccessfulPurchase(productId: String) {
        // Product IDからポイント数を抽出
        let points = extractPoints(from: productId)
        
        guard points > 0 else {
            #if DEBUG
            print("Failed to extract points from product ID: \(productId)")
            #endif
            return
        }
        
        // ユーザーIDを取得
        guard let userId = UserDefaults.standard.string(forKey: "userId"), !userId.isEmpty else {
            #if DEBUG
            print("User ID not found")
            #endif
            return
        }
        
        // 商品情報を取得
        let product = products.first { $0.productIdentifier == productId }
        let displayName = product?.localizedTitle ?? "\(points)ポイント"
        
        // Firebaseにポイントを追加
        FirebaseManager.shared.addPointsToUser(
            userId: userId,
            points: points,
            description: "\(displayName)購入"
        ) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    #if DEBUG
                    print("Successfully added \(points) points to user")
                    #endif
                    
                    // 購入明細書を保存
                    let price = product?.price ?? NSDecimalNumber(value: points)
                    let receipt = PurchaseReceipt(
                        transactionType: .pointPurchase,
                        amount: Int(truncating: price),
                        points: points,
                        paymentMethod: .applePay,
                        description: displayName
                    )
                    PurchaseReceiptManager.shared.addReceipt(receipt)
                    
                    self.purchaseCompletionHandler?(.success(productId))
                    self.purchaseCompletionHandler = nil
                    
                case .failure(let error):
                    #if DEBUG
                    print("Failed to add points: \(error)")
                    #endif
                    self.purchaseCompletionHandler?(.failure(error))
                    self.purchaseCompletionHandler = nil
                }
            }
        }
    }
}

// MARK: - SKProductsRequestDelegate
extension StoreKitManager: SKProductsRequestDelegate {
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        DispatchQueue.main.async {
            self.products = response.products.sorted { product1, product2 in
                self.extractPoints(from: product1.productIdentifier) < self.extractPoints(from: product2.productIdentifier)
            }
            
            #if DEBUG
            print("Loaded \(self.products.count) products from App Store")
            for product in self.products {
                print("Product: \(product.localizedTitle) - \(product.price)")
            }
            
            if !response.invalidProductIdentifiers.isEmpty {
                print("Invalid product identifiers: \(response.invalidProductIdentifiers)")
            }
            #endif
            
            self.isLoading = false
            self.productRequest = nil
        }
    }
    
    func request(_ request: SKRequest, didFailWithError error: Error) {
        DispatchQueue.main.async {
            #if DEBUG
            print("Failed to load products: \(error)")
            #endif
            self.errorMessage = "商品の読み込みに失敗しました"
            self.isLoading = false
            self.productRequest = nil
        }
    }
}

// MARK: - SKPaymentTransactionObserver
extension StoreKitManager: SKPaymentTransactionObserver {
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchased:
                // 購入成功
                handleSuccessfulPurchase(productId: transaction.payment.productIdentifier)
                queue.finishTransaction(transaction)
                
            case .failed:
                // 購入失敗
                if let error = transaction.error as NSError? {
                    if error.code != SKError.paymentCancelled.rawValue {
                        purchaseCompletionHandler?(.failure(error))
                    } else {
                        purchaseCompletionHandler?(.failure(StoreError.userCancelled))
                    }
                }
                purchaseCompletionHandler = nil
                queue.finishTransaction(transaction)
                
            case .restored:
                // リストア（消耗品なので通常は発生しない）
                queue.finishTransaction(transaction)
                
            case .deferred:
                // 保留中（親の承認待ちなど）
                #if DEBUG
                print("Purchase is deferred")
                #endif
                
            case .purchasing:
                // 購入処理中
                break
                
            @unknown default:
                break
            }
        }
    }
}

// MARK: - エラー定義
enum StoreError: LocalizedError {
    case paymentsNotAllowed
    case productNotFound
    case purchaseFailed
    case userCancelled
    
    var errorDescription: String? {
        switch self {
        case .paymentsNotAllowed:
            return "このデバイスでは購入が許可されていません"
        case .productNotFound:
            return "商品が見つかりません"
        case .purchaseFailed:
            return "購入に失敗しました"
        case .userCancelled:
            return "購入がキャンセルされました"
        }
    }
}