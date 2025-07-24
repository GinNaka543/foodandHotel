import SwiftUI

struct PlanPaymentConfirmationView: View {
    let planTitle: String
    let animeName: String
    let spotsCount: Int
    let totalDuration: String
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    @State private var userPoints: Int = 0
    @State private var isLoadingPoints = true
    @State private var isProcessing = false
    @State private var showingPointPurchase = false
    
    private let creationCost = 50
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ヘッダー
                HStack {
                    Text("プラン作成確認")
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
                            Image(systemName: "map.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.blue)
                            
                            Text("旅行プランを作成")
                                .font(.system(size: 20, weight: .semibold))
                                .multilineTextAlignment(.center)
                        }
                        
                        // プラン情報
                        VStack(alignment: .leading, spacing: 12) {
                            Text("プラン名")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                            Text(planTitle)
                                .font(.system(size: 18, weight: .semibold))
                            
                            Divider()
                            
                            Text("アニメ")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                            Text(animeName)
                                .font(.system(size: 16))
                            
                            Divider()
                            
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("スポット数")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.gray)
                                    Text("\(spotsCount)箇所")
                                        .font(.system(size: 16))
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("所要時間")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.gray)
                                    Text(totalDuration)
                                        .font(.system(size: 16))
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        
                        // ポイント情報
                        VStack(spacing: 12) {
                            HStack {
                                Text("作成料金:")
                                    .font(.system(size: 16))
                                Spacer()
                                Text("50ポイント")
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
                                    Text("作成後のポイント:")
                                        .font(.system(size: 16))
                                    Spacer()
                                    Text("\(userPoints - creationCost)ポイント")
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
                                Text("• 作成したプランはオリジナルタブに保存されます")
                                Text("• 50ポイントが消費されます")
                                Text("• 後から編集・削除が可能です")
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
                    if !isLoadingPoints && userPoints < creationCost {
                        // ポイント不足時のボタン
                        Button(action: {
                            showingPointPurchase = true
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
                        
                        Text("ポイントが不足しています")
                            .font(.system(size: 14))
                            .foregroundColor(.red)
                    } else {
                        Button(action: {
                            isProcessing = true
                            onConfirm()
                        }) {
                            HStack {
                                if isProcessing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                    Text("処理中...")
                                } else {
                                    Image(systemName: "checkmark.circle")
                                    Text("50ポイントで作成")
                                }
                            }
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(isProcessing || isLoadingPoints ? Color.gray : Color.purple)
                            )
                        }
                        .disabled(isProcessing || isLoadingPoints)
                    }
                    
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
        .sheet(isPresented: $showingPointPurchase) {
            PointPurchaseView(onPurchaseComplete: {
                loadUserPoints()
            })
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
                    userPoints = 0
                }
            }
        }
    }
}

struct PlanPaymentConfirmationView_Previews: PreviewProvider {
    static var previews: some View {
        PlanPaymentConfirmationView(
            planTitle: "青豚の聖地巡り",
            animeName: "青春ブタ野郎",
            spotsCount: 5,
            totalDuration: "4時間30分",
            onConfirm: {},
            onCancel: {}
        )
    }
}