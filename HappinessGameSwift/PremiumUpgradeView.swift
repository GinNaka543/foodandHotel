import SwiftUI
import StoreKit

struct PremiumUpgradeView: View {
    @Binding var showPaymentRequired: Bool
    @AppStorage("isPremiumUser") private var isPremiumUser = false
    @StateObject private var storeKitManager = StoreKitManager.shared
    @State private var selectedProduct: SKProduct?
    @State private var processingPayment = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture {
                    // 背景タップで閉じない
                }
            
            VStack(spacing: 24) {
                // ヘッダー
                VStack(spacing: 12) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.yellow)
                    
                    Text("プレミアムプランへのアップグレード")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("無料期間が終了しました")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                // 特典リスト
                VStack(alignment: .leading, spacing: 16) {
                    FeatureRow(icon: "infinity", text: "無制限のアニメ登録")
                    FeatureRow(icon: "sparkles", text: "すべての機能へのアクセス")
                    FeatureRow(icon: "clock.arrow.circlepath", text: "定期的なアップデート")
                    FeatureRow(icon: "heart.fill", text: "開発者をサポート")
                }
                .padding(.horizontal)
                
                // 価格
                VStack(spacing: 8) {
                    if let product = storeKitManager.products.first(where: { 
                        $0.productIdentifier == "com.nakajima.HappinessGameSwift.premium.2months" 
                    }) {
                        Text(localizedPrice(for: product))
                            .font(.system(size: 36, weight: .bold))
                        selectedProduct = product
                    } else {
                        Text("¥600")
                            .font(.system(size: 36, weight: .bold))
                    }
                    Text("永続ライセンス")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                // ボタン
                VStack(spacing: 12) {
                    Button(action: {
                        handlePurchase()
                    }) {
                        HStack {
                            if processingPayment {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text(processingPayment ? "処理中..." : "購入する")
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(processingPayment || selectedProduct == nil)
                    
                    Button("後で") {
                        showPaymentRequired = false
                    }
                    .foregroundColor(.gray)
                }
                .padding(.horizontal)
            }
            .padding(24)
            .background(Color(.systemBackground))
            .cornerRadius(20)
            .shadow(radius: 20)
            .frame(maxWidth: 350)
        }
        .onAppear {
            loadPremiumProduct()
        }
        .alert("エラー", isPresented: $showError) {
            Button("OK") {}
        } message: {
            Text(errorMessage)
        }
    }
    
    private func loadPremiumProduct() {
        // StoreKitManagerがすでに商品を読み込んでいるか確認
        if storeKitManager.products.isEmpty {
            storeKitManager.loadProducts()
        }
    }
    
    private func localizedPrice(for product: SKProduct) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceLocale
        return formatter.string(from: product.price) ?? "¥600"
    }
    
    private func handlePurchase() {
        guard let product = selectedProduct ?? storeKitManager.products.first(where: { 
            $0.productIdentifier == "com.nakajima.HappinessGameSwift.premium.2months" 
        }) else {
            errorMessage = "商品が見つかりません"
            showError = true
            return
        }
        
        processingPayment = true
        
        storeKitManager.purchase(product) { result in
            DispatchQueue.main.async {
                processingPayment = false
                
                switch result {
                case .success:
                    // PaymentGatekeeperを更新
                    PaymentGatekeeper.shared.markAsPremium()
                    isPremiumUser = true
                    showPaymentRequired = false
                case .failure(let error):
                    if let storeError = error as? StoreError,
                       storeError == .userCancelled {
                        // キャンセルの場合はエラーメッセージを表示しない
                        return
                    }
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 24)
            Text(text)
                .font(.subheadline)
            Spacer()
        }
    }
}

#Preview {
    PremiumUpgradeView(showPaymentRequired: .constant(true))
}