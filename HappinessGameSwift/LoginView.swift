import SwiftUI

struct LoginView: View {
    @State private var username = ""
    @State private var userId = ""
    @State private var isNewUser = false
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var generatedUserId = ""
    @State private var isLoading = false
    @ObservedObject var authManager: AuthenticationManager
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ヘッダー
                VStack(spacing: 16) {
                    Image("icon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .cornerRadius(20)
                    
                    Image("ログインロゴ")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 120)
                }
                .padding(.top, 60)
                .padding(.bottom, 40)
                
                // フォーム
                VStack(spacing: 20) {
                    // ユーザー名入力
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("username", comment: "Username"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                        
                        TextField(NSLocalizedString("enter_username", comment: "Enter username"), text: $username)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                    }
                    
                    // ユーザーID入力（ログイン時のみ）
                    if !isNewUser {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(NSLocalizedString("user_id", comment: "User ID"))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.gray)
                            
                            TextField(NSLocalizedString("enter_user_id", comment: "Enter user ID"), text: $userId)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                        }
                    }
                    
                    // 生成されたユーザーID表示（新規登録時）
                    if isNewUser && !generatedUserId.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(NSLocalizedString("your_user_id_save", comment: "Your User ID (Please save it)"))
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.red)
                            
                            HStack {
                                Text(generatedUserId)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.primary)
                                    .padding(12)
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                                
                                Button(action: {
                                    UIPasteboard.general.string = generatedUserId
                                    alertTitle = NSLocalizedString("copied", comment: "Copied")
                                    alertMessage = NSLocalizedString("user_id_copied", comment: "User ID copied to clipboard")
                                    showingAlert = true
                                }) {
                                    Image(systemName: "doc.on.doc")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 20)
                
                Spacer()
                
                // ボタン
                VStack(spacing: 16) {
                    Button(action: isNewUser ? register : login) {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                            }
                            Text(isNewUser ? NSLocalizedString("register", comment: "Register") : NSLocalizedString("login", comment: "Login"))
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(
                            (isNewUser ? !username.isEmpty : !username.isEmpty && !userId.isEmpty) && !isLoading
                                ? Color.purple
                                : Color.gray
                        )
                        .cornerRadius(12)
                    }
                    .disabled(isNewUser ? username.isEmpty || isLoading : username.isEmpty || userId.isEmpty || isLoading)
                    
                    Button(action: {
                        withAnimation {
                            isNewUser.toggle()
                            generatedUserId = ""
                        }
                    }) {
                        Text(isNewUser ? NSLocalizedString("login_with_existing", comment: "Login with existing account") : NSLocalizedString("create_new_account", comment: "Create new account"))
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .background(Color(.systemGroupedBackground))
            .ignoresSafeArea(edges: .bottom)
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            if alertTitle == NSLocalizedString("registration_complete", comment: "Registration Complete") {
                Button("OK") {
                    // 登録完了後、自動ログイン
                    saveUserData(username: username, userId: generatedUserId)
                    authManager.login()
                }
            } else {
                Button("OK") {}
            }
        } message: {
            Text(alertMessage)
        }
    }
    
    private func login() {
        isLoading = true
        
        // Firebaseからユーザー情報を確認
        FirebaseManager.shared.verifyUser(username: username, userId: userId) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let isValid):
                    if isValid {
                        saveUserData(username: username, userId: userId)
                        authManager.login()
                    } else {
                        alertTitle = NSLocalizedString("login_failed", comment: "Login Failed")
                        alertMessage = NSLocalizedString("invalid_credentials", comment: "Username or User ID is incorrect")
                        showingAlert = true
                    }
                case .failure(let error):
                    alertTitle = NSLocalizedString("error", comment: "Error")
                    alertMessage = error.localizedDescription
                    showingAlert = true
                }
            }
        }
    }
    
    private func register() {
        isLoading = true
        generatedUserId = UUID().uuidString
        
        // 新規ユーザーを作成
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
                                    alertMessage = String(format: NSLocalizedString("registration_complete_with_bonus", comment: "Please save your User ID: %@\n\n🎉 50 points have been awarded as a new registration bonus!\n\nThis ID is required for your next login."), generatedUserId)
                                    showingAlert = true
                                case .failure(let error):
                                    // ポイント付与に失敗してもユーザー登録は成功しているので続行
                                    alertTitle = NSLocalizedString("registration_complete", comment: "Registration Complete")
                                    alertMessage = String(format: NSLocalizedString("registration_complete_message", comment: "Please save your User ID: %@\n\nThis ID is required for your next login."), generatedUserId)
                                    showingAlert = true
                                }
                            }
                        }
                    } else {
                        // 2回目以降の登録（ボーナスなし）
                        isLoading = false
                        alertTitle = "登録完了"
                        alertMessage = "ユーザーIDを必ず保存してください：\n\n\(generatedUserId)\n\nこのIDは次回ログイン時に必要です。"
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
    LoginView(authManager: AuthenticationManager())
}