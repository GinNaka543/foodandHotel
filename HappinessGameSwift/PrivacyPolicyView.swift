import SwiftUI

struct PrivacyPolicyView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var hasAgreed: Bool
    let isInitialAgreement: Bool
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("プライバシーポリシー")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.bottom, 10)
                    
                    Group {
                        PrivacySectionView(
                            title: "1. 収集する情報",
                            content: "ぐるほては、以下の情報を収集する場合があります：\n• ユーザーが登録するグルメ情報（店名、写真、メモ）\n• アプリの利用状況に関する情報\n• デバイス情報（機種、OSバージョン等）"
                        )
                        
                        PrivacySectionView(
                            title: "2. 情報の利用目的",
                            content: "収集した情報は以下の目的で利用します：\n• アプリの機能提供とサービスの改善\n• ユーザーサポートの提供\n• アプリの不具合の修正\n• 新機能の開発"
                        )
                        
                        PrivacySectionView(
                            title: "3. データの保存",
                            content: "ユーザーが登録したグルメ情報、写真、メモなどのデータは、主にユーザーの端末内にローカル保存されます。クラウド同期機能を利用する場合は、暗号化された状態でサーバーに保存される場合があります。"
                        )
                        
                        PrivacySectionView(
                            title: "4. 第三者への開示",
                            content: "当アプリは、法令に基づく場合を除き、ユーザーの同意なく第三者に個人情報を提供することはありません。"
                        )
                        
                        PrivacySectionView(
                            title: "5. セキュリティ",
                            content: "当アプリは、ユーザー情報の安全性を確保するため、適切なセキュリティ対策を実施しています。ただし、インターネット上の通信やデータ保存において、完全なセキュリティを保証することはできません。"
                        )
                        
                        PrivacySectionView(
                            title: "6. 子供のプライバシー",
                            content: "当アプリは13歳未満の子供から意図的に個人情報を収集することはありません。13歳未満の方は保護者の同意を得てご利用ください。"
                        )
                        
                        PrivacySectionView(
                            title: "7. プライバシーポリシーの変更",
                            content: "当プライバシーポリシーは、必要に応じて変更されることがあります。重要な変更がある場合は、アプリ内でお知らせします。"
                        )
                        
                        PrivacySectionView(
                            title: "8. お問い合わせ",
                            content: "プライバシーポリシーに関するご質問がある場合は、アプリ内のお問い合わせフォームまたはサポートメールアドレスまでご連絡ください。"
                        )
                    }
                    
                    Text("最終更新日: 2025年8月30日")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.top)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isInitialAgreement {
                        Button("同意する") {
                            hasAgreed = true
                            dismiss()
                        }
                    } else {
                        Button("閉じる") {
                            dismiss()
                        }
                    }
                }
                
                if isInitialAgreement {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("拒否") {
                            hasAgreed = false
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

struct PrivacySectionView: View {
    let title: String
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            Text(content)
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    PrivacyPolicyView(hasAgreed: .constant(false), isInitialAgreement: false)
}