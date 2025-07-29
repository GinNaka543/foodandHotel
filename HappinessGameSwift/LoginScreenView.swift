import SwiftUI

struct LoginScreenView: View {
    @ObservedObject var authManager: AuthenticationManager
    @Environment(\.dismiss) var dismiss
    
    @State private var username = ""
    @State private var userId = ""
    @State private var isLoading = false
    @State private var showingAlert = false
    @State private var alertTitle = ""
    @State private var alertMessage = ""
    @State private var showingTermsOfService = false
    
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
                                .frame(width: 56, height: 56)
                                .cornerRadius(11)
                            
                            Image("ログインロゴ")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 105)
                        }
                        .padding(.top, -100) // 20 - 120 = -100 to move 120px up
                        
                        // フォーム
                        VStack(spacing: 24) {
                            // ユーザー名
                            VStack(alignment: .leading, spacing: 8) {
                                Text(NSLocalizedString("username", comment: ""))
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                
                                TextField(NSLocalizedString("enter_username", comment: ""), text: $username)
                                    .font(.system(size: 16))
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                    .autocapitalization(.none)
                            }
                            
                            // ユーザーID
                            VStack(alignment: .leading, spacing: 8) {
                                Text(NSLocalizedString("user_id", comment: ""))
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                
                                TextField(NSLocalizedString("enter_user_id", comment: ""), text: $userId)
                                    .font(.system(size: 16))
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                    .autocapitalization(.none)
                                
                                Text(NSLocalizedString("user_id_help", comment: "You can check your User ID from Profile Edit on the home page"))
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        .padding(.horizontal, 32)
                        
                        // ログインボタン
                        Button(action: login) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                }
                                Text(NSLocalizedString("login_button", comment: ""))
                                    .font(.system(size: 17, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(
                                (!username.isEmpty && !userId.isEmpty && !isLoading)
                                    ? Color.purple
                                    : Color(.systemGray4)
                            )
                            .cornerRadius(26)
                        }
                        .disabled(username.isEmpty || userId.isEmpty || isLoading)
                        .padding(.horizontal, 32)
                        
                        // 新規登録リンク
                        Button(action: {
                            dismiss()
                            // 選択画面に戻る
                        }) {
                            Text(NSLocalizedString("no_account_yet", comment: ""))
                                .font(.system(size: 14))
                                .foregroundColor(.blue)
                        }
                        
                        // アカウント復元の説明
                        VStack(spacing: 8) {
                            Text(NSLocalizedString("forgot_id_username", comment: ""))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.orange)
                            
                            Text(NSLocalizedString("recreate_account_message", comment: ""))
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .lineSpacing(4)
                        }
                        .padding(.horizontal, 32)
                        .padding(.vertical, 12)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                        
                        // 利用規約ボタン
                        Button(action: {
                            showingTermsOfService = true
                        }) {
                            Text(NSLocalizedString("terms_of_service", comment: ""))
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                                .underline()
                        }
                        .padding(.bottom, 40)
                    }
                }
            }
            .background(Color.white)
            .navigationBarHidden(true)
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("OK") {}
        } message: {
            Text(alertMessage)
        }
        .sheet(isPresented: $showingTermsOfService) {
            TermsOfServiceView()
        }
    }
    
    private func login() {
        isLoading = true
        
        FirebaseManager.shared.verifyUser(username: username, userId: userId) { result in
            DispatchQueue.main.async {
                isLoading = false
                switch result {
                case .success(let isValid):
                    if isValid {
                        saveUserData(username: username, userId: userId)
                        
                        // Firebaseからユーザーデータを同期
                        FirebaseManager.shared.syncUserContentFromFirebase(userId: userId) { syncResult in
                            switch syncResult {
                            case .success:
                                print("ユーザーデータの同期が完了しました")
                                
                                // 購入済みプランも同期
                                FirebaseManager.shared.syncPurchasedPlans(userId: userId) { planSyncResult in
                                    DispatchQueue.main.async {
                                        switch planSyncResult {
                                        case .success:
                                            print("購入済みプランの同期が完了しました")
                                        case .failure(let error):
                                            print("購入済みプランの同期エラー: \(error)")
                                        }
                                        
                                        // プレミアムステータスをFirebaseから同期
                                        FirebaseManager.shared.loadPremiumUserStatus(userId: userId) { result in
                                            DispatchQueue.main.async {
                                                switch result {
                                                case .success(let (isPremium, purchaseDate)):
                                                    if isPremium, let purchaseDate = purchaseDate {
                                                        UserDefaults.standard.set(purchaseDate, forKey: "premiumPurchaseDate")
                                                        UserDefaults.standard.set(true, forKey: "isPremiumUser")
                                                    }
                                                    PaymentGatekeeper.shared.checkPaymentStatus()
                                                case .failure:
                                                    PaymentGatekeeper.shared.checkPaymentStatus()
                                                }
                                            }
                                        }
                                        
                                        authManager.login()
                                        dismiss()
                                    }
                                }
                                
                            case .failure(let error):
                                print("ユーザーデータの同期エラー: \(error)")
                                DispatchQueue.main.async {
                                    authManager.login()
                                    dismiss()
                                }
                            }
                        }
                    } else {
                        alertTitle = NSLocalizedString("login_failed", comment: "")
                        alertMessage = NSLocalizedString("invalid_credentials", comment: "")
                        showingAlert = true
                    }
                case .failure(let error):
                    alertTitle = NSLocalizedString("error", comment: "")
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
    LoginScreenView(authManager: AuthenticationManager())
}