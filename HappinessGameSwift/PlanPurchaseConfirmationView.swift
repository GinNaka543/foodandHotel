import SwiftUI

struct PlanPurchaseConfirmationView: View {
    let plan: VisitPlanModel
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    @State private var userPoints: Int = 0
    @State private var isLoadingPoints = true
    @State private var isProcessing = false
    
    var body: some View {
        let _ = print("💰 [DEBUG] PlanPurchaseConfirmationView.body 呼び出し")
        let _ = print("💰 [DEBUG] plan.title: \(plan.title)")
        let _ = print("💰 [DEBUG] plan.price: \(plan.price)")
        let _ = print("💰 [DEBUG] isLoadingPoints: \(isLoadingPoints)")
        let _ = print("💰 [DEBUG] userPoints: \(userPoints)")
        
        NavigationView {
            VStack(spacing: 0) {
                // ヘッダー
                HStack {
                    Text("プラン購入確認")
                        .font(.system(size: 20, weight: .bold))
                    Spacer()
                    Button(action: onCancel) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 確認メッセージ
                        VStack(spacing: 16) {
                            Image(systemName: "cart.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)
                            
                            Text("プランを購入しますか？")
                                .font(.system(size: 20, weight: .semibold))
                                .multilineTextAlignment(.center)
                        }
                        
                        // プラン情報
                        VStack(alignment: .leading, spacing: 12) {
                            Text("プラン名")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                            Text(plan.title)
                                .font(.system(size: 18, weight: .semibold))
                            
                            Divider()
                            
                            Text("アニメ")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                            Text(plan.animeName)
                                .font(.system(size: 16))
                            
                            Divider()
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("スポット数")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.gray)
                                    Text("\(plan.spots.count)箇所")
                                        .font(.system(size: 16))
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("所要時間")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.gray)
                                    Text(plan.duration)
                                        .font(.system(size: 16))
                                }
                            }
                            
                            if !plan.description.isEmpty {
                                Divider()
                                
                                Text("説明")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.gray)
                                Text(plan.description)
                                    .font(.system(size: 16))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        
                        // ポイント情報
                        VStack(spacing: 12) {
                            HStack {
                                Text("購入料金:")
                                    .font(.system(size: 16))
                                Spacer()
                                Text("\(plan.price)ポイント")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.purple)
                            }
                            
                            HStack {
                                Text("現在のポイント:")
                                    .font(.system(size: 16))
                                Spacer()
                                if isLoadingPoints {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                } else {
                                    Text("\(userPoints)ポイント")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            if !isLoadingPoints {
                                HStack {
                                    Text("購入後のポイント:")
                                        .font(.system(size: 16))
                                    Spacer()
                                    Text("\(max(0, userPoints - plan.price))ポイント")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.green)
                                }
                            }
                        }
                        .padding()
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(12)
                        
                        // 注意事項
                        VStack(alignment: .leading, spacing: 12) {
                            Label("注意事項", systemImage: "info.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.blue)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("• 購入したプランはオリジナルタブに保存されます")
                                Text("• \(plan.price)ポイントが消費されます")
                                Text("• 購入後はプランの編集・削除が可能です")
                                Text("• 購入したプランは何度でも利用できます")
                            }
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 20)
                }
                
                // 確認ボタン
                VStack(spacing: 12) {
                    Button(action: {
                        isProcessing = true
                        onConfirm()
                    }) {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                                Text("購入中...")
                            } else {
                                Image(systemName: "checkmark.circle")
                                Text("\(plan.price)ポイントで購入")
                            }
                        }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isProcessing ? Color.gray : Color.purple)
                        )
                    }
                    .disabled(isProcessing || isLoadingPoints || userPoints < plan.price)
                    
                    Button(action: onCancel) {
                        Text("キャンセル")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.gray, lineWidth: 1)
                            )
                    }
                    .disabled(isProcessing)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .onAppear {
            loadUserPoints()
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
}

struct PlanPurchaseConfirmationView_Previews: PreviewProvider {
    static var previews: some View {
        PlanPurchaseConfirmationView(
            plan: VisitPlanModel(
                id: "preview",
                userId: "admin",
                animeName: "青春ブタ野郎",
                title: "青豚の聖地巡り",
                description: "アニメ青春ブタ野郎の聖地を巡る旅行プラン",
                duration: "4時間30分",
                spots: [],
                thumbnailUrl: "",
                price: 500,
                budget: 500,
                createdDate: Date(),
                startTime: Date(),
                numberOfDays: 1,
                totalCost: 500,
                isPublic: true,
                purchasedBy: [],
                createdAt: Date(),
                updatedAt: Date()
            ),
            onConfirm: {},
            onCancel: {}
        )
    }
}