import SwiftUI

struct PlanPurchaseView: View {
    let plan: VisitPlanModel
    @Binding var isPresented: Bool
    @StateObject private var stripeManager = StripePaymentManager.shared
    @StateObject private var firebaseManager = FirebaseManager.shared
    @State private var isPurchasing = false
    @State private var showingSuccess = false
    @State private var errorMessage = ""
    @State private var userPoints: Int = 0
    @State private var isLoadingPoints = true
    @State private var showingPurchaseSheet = false
    
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
                        
                        // 価格情報とポイント
                        VStack(spacing: 16) {
                            HStack {
                                Text("プラン価格")
                                    .font(.system(size: 18, weight: .medium))
                                Spacer()
                                Text("\(plan.price)ポイント")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.blue)
                            }
                            
                            // 現在のポイント表示
                            HStack {
                                Text("現在のポイント:")
                                    .font(.system(size: 14))
                                Spacer()
                                if isLoadingPoints {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Text("\(userPoints)ポイント")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(userPoints >= plan.price ? .green : .red)
                                }
                            }
                            
                            if !isLoadingPoints && userPoints < plan.price {
                                Text("ポイントが不足しています。あと\(plan.price - userPoints)ポイント必要です。")
                                    .font(.system(size: 12))
                                    .foregroundColor(.red)
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
                    if userPoints >= plan.price {
                        // ポイントが足りている場合
                        Button(action: { purchasePlanWithPoints() }) {
                            if isPurchasing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                HStack {
                                    Image(systemName: "checkmark.circle")
                                    Text("\(plan.price)ポイントで購入")
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
                    } else {
                        // ポイントが不足している場合
                        Button(action: {
                            showingPurchaseSheet = true
                        }) {
                            HStack {
                                Image(systemName: "plus.circle")
                                Text("ポイントを購入")
                            }
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.orange)
                            )
                        }
                    }
                    
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
        .onAppear {
            loadUserPoints()
        }
        .sheet(isPresented: $showingPurchaseSheet) {
            PointPurchaseView(
                onPurchaseComplete: {
                    loadUserPoints()
                }
            )
        }
        .alert("購入完了", isPresented: $showingSuccess) {
            Button("OK") {
                isPresented = false
            }
        } message: {
            Text("プランの購入が完了しました。ビジット画面から確認できます。")
        }
    }
    
    private func loadUserPoints() {
        guard let userId = UserDefaults.standard.string(forKey: "userId"), !userId.isEmpty else {
            isLoadingPoints = false
            return
        }
        
        FirebaseManager.shared.getUserPoints(userId: userId) { result in
            DispatchQueue.main.async {
                isLoadingPoints = false
                switch result {
                case .success(let pointsModel):
                    userPoints = pointsModel.points
                case .failure(let error):
                    print("ポイント取得エラー: \(error)")
                    userPoints = 0
                }
            }
        }
    }
    
    func purchasePlanWithPoints() {
        isPurchasing = true
        errorMessage = ""
        
        guard let userId = UserDefaults.standard.string(forKey: "userId"), !userId.isEmpty else {
            errorMessage = "ユーザーIDが見つかりません"
            isPurchasing = false
            return
        }
        
        // ポイントを使用してプランを購入
        firebaseManager.usePoints(userId: userId, points: plan.price, reason: "プラン購入: \(plan.title)") { result in
            switch result {
            case .success:
                // 購入記録を作成
                let purchase = PlanPurchase(
                    id: UUID().uuidString,
                    userId: userId,
                    planId: plan.id,
                    planOwnerId: plan.userId,
                    purchasePrice: plan.price,
                    purchasedAt: Date(),
                    stripePaymentIntentId: nil
                )
                
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