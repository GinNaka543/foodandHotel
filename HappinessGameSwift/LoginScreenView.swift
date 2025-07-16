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
                                .frame(width: 80, height: 80)
                                .cornerRadius(16)
                            
                            Image("ログインロゴ")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 150)
                        }
                        .padding(.top, -100) // 20 - 120 = -100 to move 120px up
                        
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
                            
                            // ユーザーID
                            VStack(alignment: .leading, spacing: 8) {
                                Text("ユーザーID")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                
                                TextField("ユーザーIDを入力", text: $userId)
                                    .font(.system(size: 16))
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                                    .autocapitalization(.none)
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
                                Text("ログイン")
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
                            Text("アカウントをお持ちでない方はこちら")
                                .font(.system(size: 14))
                                .foregroundColor(.blue)
                        }
                        
                        // 利用規約ボタン
                        Button(action: {
                            showingTermsOfService = true
                        }) {
                            Text("利用規約")
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
                        authManager.login()
                        dismiss()
                    } else {
                        alertTitle = "ログイン失敗"
                        alertMessage = "ユーザー名またはユーザーIDが正しくありません"
                        showingAlert = true
                    }
                case .failure(let error):
                    alertTitle = "エラー"
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