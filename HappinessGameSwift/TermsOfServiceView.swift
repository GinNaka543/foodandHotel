import SwiftUI

struct TermsOfServiceView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("利用規約")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .padding(.bottom, 10)
                    
                    Text("最終更新日: 2025年8月30日")
                        .font(.caption)
                        .foregroundColor(.gray)
                    
                    Group {
                        Text("第1条（適用）")
                            .font(.headline)
                        Text("本規約は、ぐるほて（以下「本アプリ」）の利用条件を定めるものです。ユーザーの皆様には、本規約に従って本アプリをご利用いただきます。")
                            .font(.body)
                    }
                    
                    Group {
                        Text("第2条（利用登録）")
                            .font(.headline)
                        Text("本アプリは登録不要でご利用いただけますが、一部機能については登録が必要となる場合があります。登録にあたっては、正確な情報を提供していただく必要があります。")
                            .font(.body)
                    }
                    
                    Group {
                        Text("第3条（コンテンツの管理）")
                            .font(.headline)
                        Text("ユーザーは、本アプリ内でグルメ情報、写真、メモなどを登録・管理できます。登録されたコンテンツはユーザーの端末内に保存され、ユーザー自身が管理するものとします。")
                            .font(.body)
                    }
                    
                    Group {
                        Text("第4条（禁止事項）")
                            .font(.headline)
                        Text("ユーザーは、以下の行為をしてはなりません：\n• 法令または公序良俗に違反する行為\n• 犯罪行為に関連する行為\n• 不正アクセスまたはこれを試みる行為\n• 本アプリの運営を妨害する行為\n• 他のユーザーに関する個人情報等を収集または蓄積する行為")
                            .font(.body)
                    }
                    
                    Group {
                        Text("第5条（本アプリの提供の停止等）")
                            .font(.headline)
                        Text("運営者は、以下の場合には、事前の通知なく本アプリの全部または一部の提供を停止または中断することができるものとします：\n• 保守点検または更新を行う場合\n• 地震、落雷、火災、停電または天災などの不可抗力により提供が困難な場合\n• その他、運営者が提供を困難と判断した場合")
                            .font(.body)
                    }
                    
                    Group {
                        Text("第6条（著作権）")
                            .font(.headline)
                        Text("本アプリおよび本アプリに関連する一切の情報についての著作権およびその他の知的財産権はすべて運営者または運営者にその利用を許諾した権利者に帰属します。")
                            .font(.body)
                    }
                    
                    Group {
                        Text("第7条（免責事項）")
                            .font(.headline)
                        Text("運営者は、本アプリに事実上または法律上の瑕疵がないことを明示的にも黙示的にも保証しておりません。また、本アプリに関して、ユーザーと他のユーザーまたは第三者との間において生じた取引、連絡または紛争等について一切責任を負いません。")
                            .font(.body)
                    }
                    
                    Group {
                        Text("第8条（利用規約の変更）")
                            .font(.headline)
                        Text("運営者は、必要と判断した場合には、ユーザーに通知することなくいつでも本規約を変更することができるものとします。変更後の本規約は、本アプリ内に掲載したときから効力を生じるものとします。")
                            .font(.body)
                    }
                    
                    Group {
                        Text("第9条（個人情報の取扱い）")
                            .font(.headline)
                        Text("運営者は、本アプリの利用によって取得する個人情報については、運営者のプライバシーポリシーに従い適切に取り扱うものとします。")
                            .font(.body)
                    }
                    
                    Group {
                        Text("第10条（準拠法・裁判管轄）")
                            .font(.headline)
                        Text("本規約の解釈にあたっては、日本法を準拠法とします。本アプリに関して紛争が生じた場合には、運営者の本店所在地を管轄する裁判所を専属的合意管轄とします。")
                            .font(.body)
                    }
                    
                    // データの保存について
                    Group {
                        Text("第11条（データの保存）")
                            .font(.headline)
                            .padding(.top)
                        Text("本アプリで登録されたグルメ情報、写真、メモなどのデータは、ユーザーの端末にローカル保存されます。アプリの削除や端末の変更により、データが失われる可能性があることをご了承ください。")
                            .font(.body)
                            .foregroundColor(.red)
                    }
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    TermsOfServiceView()
}