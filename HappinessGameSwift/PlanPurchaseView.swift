import SwiftUI

struct PlanPurchaseView: View {
    let plan: VisitPlanModel
    @Binding var isPresented: Bool
    @StateObject private var stripeManager = StripePaymentManager.shared
    @StateObject private var firebaseManager = FirebaseManager.shared
    @State private var isPurchasing = false
    @State private var showingSuccess = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ヘッダー
                HStack {
                    Text("プランを購入")
                        .font(.system(size: 20, weight: .bold))
                    Spacer()
                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // プラン情報
                        VStack(alignment: .leading, spacing: 16) {
                            if let thumbnailUrl = plan.thumbnailUrl,
                               let url = URL(string: thumbnailUrl) {
                                AsyncImage(url: url) { image in
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(height: 200)
                                        .clipped()
                                        .cornerRadius(12)
                                } placeholder: {
                                    Rectangle()
                                        .fill(Color(.systemGray5))
                                        .frame(height: 200)
                                        .cornerRadius(12)
                                        .overlay(
                                            ProgressView()
                                        )
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text(plan.title)
                                    .font(.system(size: 24, weight: .bold))
                                
                                Label(plan.animeName, systemImage: "tv")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                                
                                if !plan.description.isEmpty {
                                    Text(plan.description)
                                        .font(.system(size: 16))
                                        .foregroundColor(.secondary)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            
                            HStack(spacing: 20) {
                                VStack(alignment: .leading) {
                                    Text("所要時間")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                    Text(plan.duration)
                                        .font(.system(size: 16, weight: .medium))
                                }
                                
                                VStack(alignment: .leading) {
                                    Text("スポット数")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                    Text("\(plan.spots.count)箇所")
                                        .font(.system(size: 16, weight: .medium))
                                }
                                
                                VStack(alignment: .leading) {
                                    Text("日数")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                    Text("\(plan.numberOfDays)日間")
                                        .font(.system(size: 16, weight: .medium))
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                        }
                        
                        Divider()
                        
                        // 価格情報
                        VStack(spacing: 16) {
                            HStack {
                                Text("プラン価格")
                                    .font(.system(size: 18, weight: .medium))
                                Spacer()
                                Text("¥\(plan.price)")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.blue)
                            }
                            
                            Text("このプランを購入すると、すべてのスポット情報と詳細なルート案内を利用できます")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                
                // 購入ボタン
                VStack(spacing: 12) {
                    Button(action: { purchasePlan() }) {
                        if isPurchasing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            HStack {
                                Image(systemName: "creditcard")
                                Text("¥\(plan.price)で購入")
                            }
                        }
                    }
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(isPurchasing ? Color.gray : Color.blue)
                    )
                    .disabled(isPurchasing)
                    
                    Text("Stripeで安全に決済されます")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                    
                    if !errorMessage.isEmpty {
                        Text(errorMessage)
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .alert("購入完了", isPresented: $showingSuccess) {
            Button("OK") {
                isPresented = false
            }
        } message: {
            Text("プランの購入が完了しました。ビジット画面から確認できます。")
        }
    }
    
    func purchasePlan() {
        isPurchasing = true
        errorMessage = ""
        
        let userId = UserDefaults.standard.string(forKey: "userId") ?? UUID().uuidString
        
        stripeManager.purchasePlan(userId: userId, plan: plan) { result in
            switch result {
            case .success(let purchase):
                // 購入記録をFirebaseに保存
                firebaseManager.recordPlanPurchase(purchase) { recordResult in
                    DispatchQueue.main.async {
                        isPurchasing = false
                        switch recordResult {
                        case .success:
                            showingSuccess = true
                        case .failure(let error):
                            errorMessage = "購入記録の保存に失敗しました: \(error.localizedDescription)"
                        }
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    isPurchasing = false
                    errorMessage = "購入に失敗しました: \(error.localizedDescription)"
                }
            }
        }
    }
}