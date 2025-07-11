import SwiftUI

struct PublishPlanDialog: View {
    let planTitle: String
    @Binding var planDescription: String
    @Binding var planPrice: Int
    let onPublish: () -> Void
    let onCancel: () -> Void
    
    @State private var showingPaymentInfo = false
    
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
                            
                            Text("プランを公開するには1,000円の料金がかかります")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                            
                            HStack {
                                Text("公開料金:")
                                    .font(.system(size: 14))
                                Spacer()
                                Text("¥1,000")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.purple)
                            }
                            .padding()
                            .background(Color.purple.opacity(0.1))
                            .cornerRadius(12)
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
                    Button(action: {
                        showingPaymentInfo = true
                        onPublish()
                    }) {
                        HStack {
                            Image(systemName: "creditcard")
                            Text("¥1,000を支払って公開")
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
                    
                    Text("Stripeで安全に決済されます")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }
}