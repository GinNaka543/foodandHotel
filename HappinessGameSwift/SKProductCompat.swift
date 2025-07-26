import StoreKit

// iOS 18の非推奨警告を抑制するための互換性レイヤー
@available(iOS, deprecated: 18.0, message: "Use StoreKit 2 Product instead")
typealias SKProductCompat = SKProduct

extension StoreKitManager {
    // 将来的にStoreKit 2への移行が必要な場合はここで対応
    var compatProducts: [SKProductCompat] {
        return products
    }
}