import SwiftUI

struct PlanConfirmationView: View {
    let planTitle: String
    let onConfirm: () -> Void
    let onCancel: () -> Void
    let onPurchasePoints: () -> Void
    
    @State private var userPoints: Int = 0
    @State private var isLoading = true
    @StateObject private var firebaseManager = FirebaseManager.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ヘッダー
                HStack {
                    Text("プラン確定の確認")
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
                
                if isLoading {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)
                    Spacer()
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // プラン名表示
                            VStack(alignment: .leading, spacing: 8) {
                                Text("プラン名")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.gray)
                                Text(planTitle)
                                    .font(.system(size: 18, weight: .semibold))
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            
                            // 支払い情報
                            VStack(spacing: 16) {
                                HStack {
                                    Image(systemName: "star.circle.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.orange)
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("プラン確定に必要なポイント")
                                            .font(.system(size: 14))
                                            .foregroundColor(.gray)
                                        Text("50 ポイント")
                                            .font(.system(size: 24, weight: .bold))
                                    }
                                    
                                    Spacer()
                                }
                                
                                Divider()
                                
                                // 現在のポイント残高
                                HStack {
                                    Text("現在の保有ポイント")
                                        .font(.system(size: 16))
                                        .foregroundColor(.gray)
                                    Spacer()
                                    Text("\(userPoints) ポイント")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(userPoints >= 50 ? .primary : .red)
                                }
                                
                                // 支払い後の残高
                                if userPoints >= 50 {
                                    HStack {
                                        Text("支払い後の残高")
                                            .font(.system(size: 14))
                                            .foregroundColor(.gray)
                                        Spacer()
                                        Text("\(userPoints - 50) ポイント")
                                            .font(.system(size: 16))
                                            .foregroundColor(.gray)
                                    }
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(12)
                            
                            // ポイント不足の警告
                            if userPoints < 50 {
                                VStack(spacing: 12) {
                                    HStack {
                                        Image(systemName: "exclamationmark.triangle.fill")
                                            .foregroundColor(.orange)
                                        Text("ポイントが不足しています")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.orange)
                                    }
                                    
                                    Text("プランを確定するには、あと\(50 - userPoints)ポイント必要です")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(12)
                            }
                            
                            // 説明テキスト
                            VStack(alignment: .leading, spacing: 8) {
                                Label("プランを確定すると、訪問ゲームを開始できます", systemImage: "checkmark.circle")
                                Label("確定後はプランの編集ができません", systemImage: "lock")
                                Label("確定したプランは「マイプラン」に保存されます", systemImage: "folder")
                            }
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 100)
                    }
                }
                
                // ボタン
                VStack(spacing: 12) {
                    if userPoints >= 50 {
                        Button(action: onConfirm) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                Text("50ポイントを支払って確定")
                            }
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                    } else {
                        Button(action: onPurchasePoints) {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("ポイントを購入する")
                            }
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.orange)
                            .cornerRadius(12)
                        }
                    }
                    
                    Button(action: onCancel) {
                        Text("キャンセル")
                            .font(.system(size: 17))
                            .foregroundColor(.gray)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
                .background(Color(.systemBackground))
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            loadUserPoints()
        }
    }
    
    private func loadUserPoints() {
        let userId = UserDefaults.standard.string(forKey: "userId") ?? ""
        
        firebaseManager.fetchUserPoints(userId: userId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let points):
                    self.userPoints = points
                case .failure(let error):
                    print("ポイント取得エラー: \(error)")
                    self.userPoints = 0
                }
                self.isLoading = false
            }
        }
    }
}