import SwiftUI

struct RegisterScreenView: View {
    @ObservedObject var authManager: AuthenticationManager
    @Environment(\.dismiss) var dismiss
    
    @State private var username = ""
    @State private var generatedUserId = ""
    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showingSuccessView = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // グラデーションヘッダー
                LinearGradient(
                    gradient: Gradient(colors: [Color.green, Color.blue]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: 4)
                
                // 戻るボタン
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 20))
                            .foregroundColor(.black)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)
                
                ScrollView {
                    VStack(spacing: 30) {
                        // ロゴ
                        VStack(spacing: 16) {
                            Image("icon")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .cornerRadius(16)
                            
                            Image("ログインロゴ")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 150)
                        }
                        .padding(.top, 20)
                        
                        // フォーム
                        VStack(spacing: 24) {
                            // ユーザー名
                            VStack(alignment: .leading, spacing: 8) {
                                Text("ユーザー名")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                
                                TextField("ユーザー名を入力", text: $username)
                                    .font(.system(size: 16))
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                    .autocapitalization(.none)
                            }
                            
                            Text("※ユーザー名は後から変更できます")
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.horizontal, 32)
                        
                        // 登録ボタン
                        Button(action: register) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                }
                                Text("新規登録")
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                (!username.isEmpty && !isLoading)
                                    ? Color.purple
                                    : Color(.systemGray4)
                            )
                            .cornerRadius(26)
                        }
                        .disabled(username.isEmpty || isLoading)
                        .padding(.horizontal, 32)
                        
                        // ログインリンク
                        Button(action: {
                            dismiss()
                        }) {
                            Text("すでにアカウントをお持ちの方はこちら")
                                .font(.system(size: 14))
                                .foregroundColor(.blue)
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
            .background(Color.white)
            .navigationBarHidden(true)
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            if alertTitle == "登録完了" {
                Button("OK") {
                    saveUserData(username: username, userId: generatedUserId)
                    authManager.login()
                    dismiss()
                }
            } else {
                Button("OK") {}
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func register() {
        isLoading = true
        generatedUserId = UUID().uuidString
        
        let profile = UserProfile(
            id: generatedUserId,
            username: username,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        FirebaseManager.shared.saveUserProfile(profile) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // デバイスで初回登録かチェック
                    let hasReceivedBonus = UserDefaults.standard.bool(forKey: "hasReceivedFirstTimeBonus")
                    
                    if !hasReceivedBonus {
                        // 初回登録時のみ50ポイントを付与
                        FirebaseManager.shared.addPointsToUser(
                            userId: generatedUserId,
                            points: 50,
                            description: "新規登録ボーナス"
                        ) { pointsResult in
                            DispatchQueue.main.async {
                                isLoading = false
                                switch pointsResult {
                                case .success:
                                    // ボーナス付与済みフラグを設定
                                    UserDefaults.standard.set(true, forKey: "hasReceivedFirstTimeBonus")
                                    alertTitle = "登録完了"
                                    alertMessage = """
                                    ユーザーIDが発行されました。
                                    
                                    ユーザーID: \(generatedUserId)
                                    
                                    🎉 新規登録ボーナスとして50ポイントが付与されました！
                                    
                                    このIDは次回ログイン時に必要です。
                                    必ずメモやスクリーンショットで保存してください。
                                    """
                                    showingAlert = true
                                case .failure(let error):
                                    // ポイント付与に失敗してもユーザー登録は成功しているので続行
                                    alertTitle = "登録完了"
                                    alertMessage = """
                                    ユーザーIDが発行されました。
                                    
                                    ユーザーID: \(generatedUserId)
                                    
                                    このIDは次回ログイン時に必要です。
                                    必ずメモやスクリーンショットで保存してください。
                                    """
                                    showingAlert = true
                                }
                            }
                        }
                    } else {
                        // 2回目以降の登録（ボーナスなし）
                        isLoading = false
                        alertTitle = "登録完了"
                        alertMessage = """
                        ユーザーIDが発行されました。
                        
                        ユーザーID: \(generatedUserId)
                        
                        このIDは次回ログイン時に必要です。
                        必ずメモやスクリーンショットで保存してください。
                        """
                        showingAlert = true
                    }
                case .failure(let error):
                    isLoading = false
                    alertTitle = "登録エラー"
                    alertMessage = error.localizedDescription
                    showingAlert = true
                }
            }
        }
    }
    
    private func saveUserData(username: String, userId: String) {
        UserDefaults.standard.set(userId, forKey: "userId")
        UserDefaults.standard.set(username, forKey: "username")
        UserDefaults.standard.set(true, forKey: "isLoggedIn")
    }
}

#Preview {
    RegisterScreenView(authManager: AuthenticationManager())
}