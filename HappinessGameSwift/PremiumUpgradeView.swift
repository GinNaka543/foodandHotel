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
                    
                    Text(NSLocalizedString("premium_upgrade_title", comment: "Premium plan upgrade"))
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(NSLocalizedString("free_trial_ended_message", comment: "Free trial ended"))
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
                
                // 特典リスト
                VStack(alignment: .leading, spacing: 16) {
                    FeatureRow(icon: "infinity", text: NSLocalizedString("unlimited_anime_registration", comment: ""))
                    FeatureRow(icon: "sparkles", text: NSLocalizedString("access_all_features", comment: ""))
                    FeatureRow(icon: "clock.arrow.circlepath", text: NSLocalizedString("regular_updates", comment: ""))
                    FeatureRow(icon: "heart.fill", text: NSLocalizedString("support_developer", comment: ""))
                }
                .padding(.horizontal)
                
                // 価格
                VStack(spacing: 8) {
                    if let product = storeKitManager.products.first(where: { 
                        $0.productIdentifier == "com.nakajima.HappinessGameSwift.premium.2months" 
                    }) {
                        Text(localizedPrice(for: product))
                            .font(.system(size: 36, weight: .bold))
                            .onAppear {
                                selectedProduct = product
                            }
                    } else {
                        Text("¥600")
                            .font(.system(size: 36, weight: .bold))
                    }
                    Text(NSLocalizedString("permanent_license", comment: ""))
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
                            Text(processingPayment ? NSLocalizedString("processing", comment: "") : NSLocalizedString("purchase", comment: ""))
                                .fontWeight(.semibold)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    .disabled(processingPayment || selectedProduct == nil)
                    
                    Button(NSLocalizedString("later", comment: "")) {
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
        .alert(NSLocalizedString("error", comment: ""), isPresented: $showError) {
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
            errorMessage = NSLocalizedString("product_not_found", comment: "")
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