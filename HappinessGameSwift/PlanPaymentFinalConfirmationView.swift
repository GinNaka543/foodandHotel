import SwiftUI

struct PlanPaymentFinalConfirmationView: View {
    let planTitle: String
    let visitPlanData: VisitPlanData
    let onViewPlan: () -> Void
    let onClose: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ヘッダー
                HStack {
                    Text("作成完了")
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
                        Text("プラン作成完了！")
                            .font(.system(size: 24, weight: .bold))
                        
                        Text("プランが正常に作成されました")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                        
                        VStack(spacing: 8) {
                            Text(planTitle)
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
                            Text("50ポイントを消費しました")
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

struct PlanPaymentFinalConfirmationView_Previews: PreviewProvider {
    static var previews: some View {
        PlanPaymentFinalConfirmationView(
            planTitle: "青豚の聖地巡り",
            visitPlanData: VisitPlanData(
                id: UUID(),
                animeName: "青春ブタ野郎",
                title: "青豚の聖地巡り",
                duration: "4時間30分",
                spots: [],
                thumbnailData: nil,
                createdDate: Date(),
                startTime: Date(),
                numberOfDays: 1
            ),
            onViewPlan: {},
            onClose: {}
        )
    }
}