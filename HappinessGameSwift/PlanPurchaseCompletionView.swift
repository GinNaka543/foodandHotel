import SwiftUI

struct PlanPurchaseCompletionView: View {
    let plan: VisitPlanModel
    let onViewPlan: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ヘッダー
                HStack {
                    Text("購入完了")
                        .font(.system(size: 20, weight: .bold))
                    Spacer()
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                VStack(spacing: 32) {
                    Spacer()
                        .frame(height: 60)
                    
                    // 完了アイコン
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.green)
                    
                    // メッセージ
                    VStack(spacing: 16) {
                        Text("購入完了！")
                            .font(.system(size: 24, weight: .bold))
                        
                        Text("プランを正常に購入しました")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                        
                        // プランサムネイル
                        if let thumbnailUrl = plan.thumbnailUrl,
                           let url = URL(string: thumbnailUrl) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 120, height: 80)
                                    .clipped()
                                    .cornerRadius(8)
                            } placeholder: {
                                Rectangle()
                                    .fill(Color(.systemGray5))
                                    .frame(width: 120, height: 80)
                                    .cornerRadius(8)
                                    .overlay(
                                        ProgressView()
                                            .scaleEffect(0.7)
                                    )
                            }
                        }
                        
                        VStack(spacing: 8) {
                            Text(plan.title)
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.blue)
                            
                            Text("オリジナルタブに保存されました")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 8)
                    }
                    
                    // 情報
                    VStack(spacing: 12) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 14))
                            Text("\(plan.price)ポイントを消費しました")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.blue)
                                .font(.system(size: 14))
                            Text("プランはオリジナルタブから確認できます")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        
                        HStack {
                            Image(systemName: "map.fill")
                                .foregroundColor(.purple)
                                .font(.system(size: 14))
                            Text("購入したプランは何度でも利用できます")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal, 40)
                    
                    Spacer()
                    
                    // ボタン
                    VStack(spacing: 12) {
                        Button(action: onViewPlan) {
                            HStack {
                                Image(systemName: "map.fill")
                                Text("プランを見る")
                            }
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.blue)
                            )
                        }
                        
                        Button(action: onClose) {
                            Text("閉じる")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.gray, lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
        }
    }
}

struct PlanPurchaseCompletionView_Previews: PreviewProvider {
    static var previews: some View {
        PlanPurchaseCompletionView(
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
            onViewPlan: {},
            onClose: {}
        )
    }
}