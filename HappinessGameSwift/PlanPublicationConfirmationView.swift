import SwiftUI

struct PlanPublicationConfirmationView: View {
    let planTitle: String
    let onConfirm: () -> Void
    let onCancel: () -> Void
    
    @State private var userPoints: Int = 0
    @State private var isLoadingPoints = true
    @State private var isPublishing = false
    
    private let publicationCost = 5000
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ヘッダー
                HStack {
                    Text("最終確認")
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
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.green)
                            
                            Text("プランを公開しますか？")
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
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                        
                        // ポイント情報
                        VStack(spacing: 12) {
                            HStack {
                                Text("公開料金:")
                                    .font(.system(size: 16))
                                Spacer()
                                Text("5,000ポイント")
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
                                    Text("公開後のポイント:")
                                        .font(.system(size: 16))
                                    Spacer()
                                    Text("\(userPoints - publicationCost)ポイント")
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
                            Label("注意事項", systemImage: "exclamationmark.triangle.fill")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.orange)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text("• 公開後はプランの編集・削除はできません")
                                Text("• 5,000ポイントが消費されます")
                                Text("• 他のユーザーがプランを購入できるようになります")
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
                        isPublishing = true
                        onConfirm()
                    }) {
                        HStack {
                            if isPublishing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                                Text("公開中...")
                            } else {
                                Image(systemName: "checkmark.circle")
                                Text("5,000ポイントで公開")
                            }
                        }
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isPublishing ? Color.gray : Color.purple)
                        )
                    }
                    .disabled(isPublishing || isLoadingPoints || userPoints < publicationCost)
                    
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
                    .disabled(isPublishing)
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

#Preview {
    PlanPublicationConfirmationView(
        planTitle: "東京アニメ聖地巡礼プラン",
        onConfirm: {},
        onCancel: {}
    )
}