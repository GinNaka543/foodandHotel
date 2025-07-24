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
                            content: """
                            本アプリ「アニレコ」は、以下の情報を収集します：
                            
                            • ユーザー登録情報（ユーザー名、ユーザーID）
                            • アプリ内で作成されたコンテンツ（キャラクター、アニメの記録）
                            • デバイス情報（デバイスID、OSバージョン）
                            • アプリの利用状況（ログイン日時、機能の使用頻度）
                            • 支払い情報（Stripeを通じた決済情報、ただしクレジットカード番号は保存しません）
                            
                            ※メールアドレスは収集しません
                            """
                        )
                        
                        PrivacySectionView(
                            title: "2. 情報の使用目的",
                            content: """
                            収集した情報は以下の目的でのみ使用されます：
                            
                            • アプリの基本機能の提供
                            • ユーザー認証とアカウント管理
                            • 課金・ポイント管理
                            • キャラクター・アニメ情報のバックアップ（データ喪失時の復旧用）
                            • アプリの改善とカスタマーサポート
                            • 法的要求への対応
                            
                            注記：お客様が登録したキャラクターやアニメの情報は、デバイスの故障や機種変更時にデータを復旧できるよう、バックアップ目的でのみサーバーに保存されます。
                            """
                        )
                        
                        PrivacySectionView(
                            title: "3. データの保存と管理",
                            content: """
                            • ユーザーが作成したコンテンツ（キャラクター、アニメ情報）は、バックアップ目的でFirebaseサーバーに安全に保存されます
                            • この仕組みにより、以下の場合でもデータを失うことなく復旧できます：
                              - デバイスの故障や紛失
                              - アプリの再インストール
                              - 新しいデバイスへの機種変更
                            • 認証情報、ポイント情報、課金情報もFirebaseサーバーで管理されます
                            • すべての通信はHTTPSで暗号化されています
                            • ユーザーは自分のデータをいつでも削除することができます
                            • バックアップデータは、ユーザーアカウントに紐づいて保存され、他のユーザーがアクセスすることはできません
                            """
                        )
                        
                        PrivacySectionView(
                            title: "4. 第三者への情報提供",
                            content: """
                            当社は、以下の場合を除き、ユーザーの個人情報を第三者に提供することはありません：
                            
                            • ユーザーの同意がある場合
                            • 法令に基づく開示請求があった場合
                            • 人命、身体または財産の保護のために必要な場合
                            """
                        )
                        
                        PrivacySectionView(
                            title: "5. セキュリティ",
                            content: """
                            当社は、ユーザーの情報を適切に保護するため、以下の対策を実施しています：
                            
                            • HTTPS通信による暗号化
                            • Firebase Authenticationによる安全な認証
                            • APIキーの適切な管理
                            • 定期的なセキュリティアップデート
                            """
                        )
                        
                        PrivacySectionView(
                            title: "6. Cookieおよびトラッキング",
                            content: """
                            • 本アプリは、ユーザー体験向上のためにCookieを使用しません
                            • 広告表示のためのトラッキングは行いません
                            • アプリの利用統計は匿名化された形で収集されます
                            • 収集したキャラクター・アニメ情報は、バックアップ・復旧目的以外には使用されません
                            """
                        )
                        
                        PrivacySectionView(
                            title: "7. データのバックアップと復旧",
                            content: """
                            お客様の大切なデータを守るため、以下のバックアップ機能を提供しています：
                            
                            • 自動バックアップ：キャラクターやアニメの登録・編集時に自動的にサーバーに保存
                            • データ復旧：ログイン時に自動的にバックアップデータから復元
                            • バックアップの目的：
                              - デバイスの故障・紛失時のデータ保護
                              - アプリ削除・再インストール時のデータ復旧
                              - 機種変更時のデータ移行
                            
                            重要：このバックアップデータは、お客様のデータ保護のためだけに使用され、他の目的（マーケティング、分析、第三者への提供など）には一切使用されません。
                            """
                        )
                        
                        PrivacySectionView(
                            title: "8. 子供のプライバシー",
                            content: """
                            本アプリは13歳未満の子供を対象としていません。13歳未満の方は保護者の同意を得てご利用ください。
                            """
                        )
                        
                        PrivacySectionView(
                            title: "9. プライバシーポリシーの変更",
                            content: """
                            当社は、必要に応じてプライバシーポリシーを変更することがあります。重要な変更がある場合は、アプリ内で通知します。
                            """
                        )
                        
                        PrivacySectionView(
                            title: "10. お問い合わせ",
                            content: """
                            プライバシーに関するお問い合わせは、以下までご連絡ください：
                            
                            メール: fneko543@gmail.com
                            """
                        )
                    }
                    
                    Text("最終更新日: 2025年7月24日")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding(.top, 20)
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if !isInitialAgreement {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("閉じる") {
                            dismiss()
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if isInitialAgreement {
                    VStack(spacing: 16) {
                        Button(action: {
                            hasAgreed = true
                            UserDefaults.standard.set(true, forKey: "hasAgreedToPrivacyPolicy")
                            dismiss()
                        }) {
                            Text("同意してアプリを開始する")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .cornerRadius(12)
                        }
                        
                        Text("プライバシーポリシーに同意することで、アプリの利用を開始できます")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(Color(UIColor.systemBackground))
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
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct PrivacyPolicyView_Previews: PreviewProvider {
    static var previews: some View {
        PrivacyPolicyView(hasAgreed: .constant(false), isInitialAgreement: true)
    }
}