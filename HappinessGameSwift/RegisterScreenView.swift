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
                                Text(NSLocalizedString("username", comment: "Username"))
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                
                                TextField(NSLocalizedString("enter_username", comment: "Enter username"), text: $username)
                                    .font(.system(size: 16))
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                    .autocapitalization(.none)
                            }
                            
                            Text(NSLocalizedString("username_can_be_changed_later", comment: "Username can be changed later"))
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
                                Text(NSLocalizedString("register", comment: "Register"))
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
                            Text(NSLocalizedString("already_have_account", comment: "Already have an account? Sign in here"))
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
            if alertTitle == NSLocalizedString("registration_complete", comment: "Registration Complete") {
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
        generatedUserId = UUID().uuidString  // 自動生成
        
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
                            description: NSLocalizedString("registration_bonus", comment: "Registration bonus")
                        ) { pointsResult in
                            DispatchQueue.main.async {
                                isLoading = false
                                switch pointsResult {
                                case .success:
                                    // ボーナス付与済みフラグを設定
                                    UserDefaults.standard.set(true, forKey: "hasReceivedFirstTimeBonus")
                                    alertTitle = NSLocalizedString("registration_complete", comment: "Registration Complete")
                                    alertMessage = String(format: NSLocalizedString("registration_complete_with_bonus", comment: "Registration complete with bonus"), generatedUserId)
                                    showingAlert = true
                                case .failure(let error):
                                    // ポイント付与に失敗してもユーザー登録は成功しているので続行
                                    alertTitle = NSLocalizedString("registration_complete", comment: "Registration Complete")
                                    alertMessage = String(format: NSLocalizedString("registration_complete_message", comment: "Registration complete message"), generatedUserId)
                                    showingAlert = true
                                }
                            }
                        }
                    } else {
                        // 2回目以降の登録（ボーナスなし）
                        isLoading = false
                        alertTitle = NSLocalizedString("registration_complete", comment: "Registration Complete")
                        alertMessage = """
                        \(NSLocalizedString("user_id_issued", comment: "User ID has been issued"))
                        
                        \(String(format: NSLocalizedString("user_id_label_format", comment: "User ID: %@"), generatedUserId))
                        
                        \(NSLocalizedString("id_required_for_next_login", comment: "This ID is required for next login"))
                        \(NSLocalizedString("save_with_memo_or_screenshot", comment: "Save with memo or screenshot"))
                        """
                        showingAlert = true
                    }
                case .failure(let error):
                    isLoading = false
                    alertTitle = NSLocalizedString("registration_error", comment: "Registration Error")
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