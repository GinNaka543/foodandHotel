import SwiftUI

struct PublishPlanDialog: View {
    let planTitle: String
    @Binding var planDescription: String
    @Binding var planPrice: Int
    @Binding var planBudget: Int
    let onPublish: () -> Void
    let onCancel: () -> Void
    
    @State private var showingPaymentInfo = false
    @State private var userPoints: Int = 0
    @State private var isLoadingPoints = true
    @State private var showingPurchaseSheet = false
    @State private var errorMessage = ""
    
    private let publicationCost = 5000 // 5,000ポイント
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ヘッダー
                HStack {
                    Text("プランを公開")
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
                    VStack(alignment: .leading, spacing: 24) {
                        // 公開料金の説明
                        VStack(alignment: .leading, spacing: 12) {
                            Label("プラン公開料金", systemImage: "yensign.circle.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.purple)
                            
                            Text("プランを公開するには5,000ポイントが必要です")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                            
                            VStack(spacing: 12) {
                                HStack {
                                    Text("公開料金:")
                                        .font(.system(size: 14))
                                    Spacer()
                                    Text("5,000ポイント")
                                        .font(.system(size: 18, weight: .bold))
                                        .foregroundColor(.purple)
                                }
                                .padding()
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(12)
                                
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
                                            .foregroundColor(userPoints >= publicationCost ? .green : .red)
                                    }
                                }
                                
                                if !isLoadingPoints && userPoints < publicationCost {
                                    Text("ポイントが不足しています。あと\(publicationCost - userPoints)ポイント必要です。")
                                        .font(.system(size: 12))
                                        .foregroundColor(.red)
                                        .padding(.top, 4)
                                }
                            }
                        }
                        
                        Divider()
                        
                        // プラン情報
                        VStack(alignment: .leading, spacing: 16) {
                            Text("プラン情報")
                                .font(.system(size: 18, weight: .semibold))
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("タイトル")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                Text(planTitle)
                                    .font(.system(size: 16))
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("プランの説明")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                TextField("このプランの魅力を説明してください", text: $planDescription, axis: .vertical)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .lineLimit(3...6)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("販売価格")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                HStack {
                                    TextField("0", value: $planPrice, format: .number)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .frame(width: 120)
                                        .keyboardType(.numberPad)
                                    Text("円")
                                        .font(.system(size: 16))
                                    Spacer()
                                }
                                Text("※ 0円に設定すると無料プランになります")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                            }
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("予算")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                HStack {
                                    TextField("0", value: $planBudget, format: .number)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .frame(width: 120)
                                        .keyboardType(.numberPad)
                                    Text("円")
                                        .font(.system(size: 16))
                                    Spacer()
                                }
                                Text("※ このプランにかかる大体の予算を入力してください（必須）")
                                    .font(.system(size: 12))
                                    .foregroundColor(.red)
                            }
                        }
                        
                        Divider()
                        
                        // 注意事項
                        VStack(alignment: .leading, spacing: 12) {
                            Label("注意事項", systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.orange)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("• 公開後はプランの編集・削除はできません")
                                Text("• 他のユーザーがプランを購入した際、販売価格を受け取ることができます")
                                Text("• 不適切なコンテンツは削除される場合があります")
                            }
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
                
                // 公開ボタン
                VStack(spacing: 12) {
                    if userPoints >= publicationCost {
                        // ポイントが足りている場合
                        Button(action: {
                            if planBudget <= 0 {
                                errorMessage = "予算を入力してください"
                                return
                            }
                            onPublish()
                        }) {
                            HStack {
                                Image(systemName: "checkmark.circle")
                                Text("5,000ポイントで公開")
                            }
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.purple)
                            )
                        }
                        .disabled(planBudget <= 0)
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
                            .font(.system(size: 12))
                            .foregroundColor(.red)
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