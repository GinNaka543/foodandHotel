import SwiftUI
import StoreKit

struct PointPurchaseView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var storeKitManager = StoreKitManager.shared
    @StateObject private var firebaseManager = FirebaseManager.shared
    @State private var selectedProduct: SKProduct?
    @State private var isPurchasing = false
    @State private var showingSuccess = false
    @State private var errorMessage = ""
    
    let onPurchaseComplete: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ヘッダー
                HStack {
                    Text(NSLocalizedString("purchase_points", comment: ""))
                        .font(.system(size: 20, weight: .bold))
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                if storeKitManager.isLoading {
                    Spacer()
                    ProgressView(NSLocalizedString("loading_products", comment: ""))
                        .padding()
                    Spacer()
                } else if storeKitManager.products.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text(NSLocalizedString("failed_to_load_products", comment: ""))
                            .font(.title3)
                            .foregroundColor(.gray)
                        Button(NSLocalizedString("reload", comment: "")) {
                            storeKitManager.loadProducts()
                        }
                        .foregroundColor(.blue)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            // 説明
                            VStack(alignment: .leading, spacing: 12) {
                                Text(NSLocalizedString("select_points_package", comment: ""))
                                    .font(.system(size: 18, weight: .semibold))
                                
                                Text(NSLocalizedString("points_usage_description", comment: ""))
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            
                            // ポイントパッケージ（StoreKitの商品を表示）
                            LazyVStack(spacing: 12) {
                                ForEach(storeKitManager.products, id: \.productIdentifier) { product in
                                    StoreKitProductCard(
                                        product: product,
                                        isSelected: selectedProduct?.productIdentifier == product.productIdentifier,
                                        onSelect: { 
                                            selectedProduct = product
                                        }
                                    )
                                }
                            }
                            
                            // エラーメッセージ
                            if !errorMessage.isEmpty {
                                Text(errorMessage)
                                    .foregroundColor(.red)
                                    .font(.system(size: 14))
                                    .multilineTextAlignment(.leading)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .padding()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.red.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                        .padding(20)
                    }
                }
                
                // 購入ボタン
                VStack(spacing: 16) {
                    if let product = selectedProduct {
                        HStack {
                            Text(NSLocalizedString("total", comment: ""))
                                .font(.system(size: 18, weight: .semibold))
                            Spacer()
                            Text(localizedPrice(for: product))
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(.purple)
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    Button(action: purchasePoints) {
                        HStack {
                            if isPurchasing {
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            }
                            Text(isPurchasing ? NSLocalizedString("processing", comment: "Processing...") : NSLocalizedString("purchase", comment: "Purchase"))
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            selectedProduct != nil && !isPurchasing ? 
                            Color.purple : Color.gray
                        )
                        .cornerRadius(12)
                    }
                    .disabled(selectedProduct == nil || isPurchasing)
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 20)
            }
            .background(Color(.systemGroupedBackground))
        }
        .onAppear {
            if storeKitManager.products.isEmpty {
                storeKitManager.loadProducts()
            }
        }
        .alert(NSLocalizedString("purchase_complete", comment: "Purchase Complete"), isPresented: $showingSuccess) {
            Button("OK") {
                dismiss()
                onPurchaseComplete()
            }
        } message: {
            if let product = selectedProduct {
                Text(String(format: NSLocalizedString("points_purchased_success", comment: ""), extractPoints(from: product.productIdentifier)))
            }
        }
    }
    
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
    
    private func localizedPrice(for product: SKProduct) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceLocale
        return formatter.string(from: product.price) ?? "\(product.price)"
    }
    
    private func purchasePoints() {
        guard let product = selectedProduct else { return }
        
        isPurchasing = true
        errorMessage = ""
        
        storeKitManager.purchase(product) { result in
            DispatchQueue.main.async {
                isPurchasing = false
                
                switch result {
                case .success:
                    showingSuccess = true
                case .failure(let error):
                    if let storeError = error as? StoreError,
                       storeError == .userCancelled {
                        // キャンセルの場合はエラーメッセージを表示しない
                        return
                    }
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - StoreKit商品カード
struct StoreKitProductCard: View {
    let product: SKProduct
    let isSelected: Bool
    let onSelect: () -> Void
    
    private var isPremiumProduct: Bool {
        product.productIdentifier.contains("premium")
    }
    
    private var points: Int {
        // プレミアム商品の場合は0を返す（特別表示のため）
        if isPremiumProduct {
            return 0
        }
        
        // "com.nakajima.HappinessGameSwift.points.1000.v2" -> 1000
        let components = product.productIdentifier.split(separator: ".")
        // points.1000.v2 の場合、インデックス4が数値
        if components.count >= 5,
           let points = Int(components[4]) {
            return points
        }
        return 0
    }
    
    private var isPopular: Bool {
        points == 1000
    }
    
    private var localizedPrice: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceLocale
        return formatter.string(from: product.price) ?? "\(product.price)"
    }
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        if isPremiumProduct {
                            Text(NSLocalizedString("premium_upgrade_lifetime", comment: "Premium Upgrade (Lifetime License)"))
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.primary)
                        } else {
                            Text(String(format: NSLocalizedString("points_format", comment: ""), points))
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.primary)
                        }
                        
                        if isPopular {
                            Text(NSLocalizedString("popular", comment: ""))
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.orange)
                                .cornerRadius(4)
                        }
                        
                        Spacer()
                    }
                    
                    Text(localizedPrice)
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                    
                    if !isPremiumProduct, let pricePerPoint = calculatePricePerPoint() {
                        Text(String(format: NSLocalizedString("price_per_point", comment: ""), pricePerPoint))
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                }
                
                Spacer()
                
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .purple : .gray)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                isSelected ? Color.purple : Color.gray.opacity(0.3),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func calculatePricePerPoint() -> String? {
        guard !isPremiumProduct && points > 0 else { return nil }
        
        let pricePerPoint = product.price.doubleValue / Double(points)
        
        // 価格フォーマッター
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceLocale
        formatter.maximumFractionDigits = 0
        
        return formatter.string(from: NSNumber(value: pricePerPoint))
    }
}

#Preview {
    PointPurchaseView(onPurchaseComplete: {})
}