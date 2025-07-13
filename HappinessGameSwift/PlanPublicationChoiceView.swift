import SwiftUI

struct PlanPublicationChoiceView: View {
    let planTitle: String
    let onPrivate: () -> Void
    let onPublic: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ヘッダー
                HStack {
                    Text("プランの公開設定")
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
                        
                        // 説明テキスト
                        VStack(alignment: .leading, spacing: 12) {
                            Text("プランの公開方法を選択してください")
                                .font(.system(size: 16, weight: .semibold))
                            
                            Text("プライベート: 自分だけが閲覧可能\nパブリック: 他のユーザーも購入・閲覧可能")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        // 選択ボタン
                        VStack(spacing: 16) {
                            // プライベートオプション
                            Button(action: onPrivate) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Image(systemName: "lock.fill")
                                                .foregroundColor(.blue)
                                            Text("プライベート")
                                                .font(.system(size: 18, weight: .semibold))
                                                .foregroundColor(.primary)
                                        }
                                        Text("自分だけのプラン")
                                            .font(.system(size: 14))
                                            .foregroundColor(.gray)
                                        Text("無料")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.blue)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // パブリックオプション
                            Button(action: onPublic) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Image(systemName: "globe")
                                                .foregroundColor(.purple)
                                            Text("パブリック")
                                                .font(.system(size: 18, weight: .semibold))
                                                .foregroundColor(.primary)
                                        }
                                        Text("他のユーザーも利用可能")
                                            .font(.system(size: 14))
                                            .foregroundColor(.gray)
                                        Text("5,000ポイント")
                                            .font(.system(size: 16, weight: .bold))
                                            .foregroundColor(.purple)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.gray)
                                }
                                .padding()
                                .background(Color.purple.opacity(0.1))
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(20)
                }
                
                Spacer()
            }
            .background(Color(.systemBackground))
        }
    }
}

#Preview {
    PlanPublicationChoiceView(
        planTitle: "東京アニメ聖地巡礼",
        onPrivate: {},
        onPublic: {},
        onCancel: {}
    )
}