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
        
        // Firebase を使わないローカル登録
        DispatchQueue.main.async {
            self.isLoading = false
            // ローカルにユーザーIDを保存
            UserDefaults.standard.set(self.generatedUserId, forKey: "userId")
            UserDefaults.standard.set(self.username, forKey: "username")
            UserDefaults.standard.set(true, forKey: "isLoggedIn")
            
            self.alertTitle = NSLocalizedString("registration_complete", comment: "Registration Complete")
            self.alertMessage = String(format: NSLocalizedString("registration_complete_message", comment: "Registration complete message"), self.generatedUserId)
            self.showingAlert = true
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