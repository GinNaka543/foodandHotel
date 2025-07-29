import SwiftUI

class AdminAuthManager: ObservableObject {
    @Published var isAdminLoggedIn: Bool = false
    
    private let correctUsername = "anicolle"
    private let correctPassword = "20050424"
    
    func login(username: String, password: String) -> Bool {
        if username == correctUsername && password == correctPassword {
            isAdminLoggedIn = true
            return true
        }
        return false
    }
    
    func logout() {
        isAdminLoggedIn = false
    }
}

struct AdminLoginView: View {
    @StateObject private var adminAuth = AdminAuthManager()
    @State private var username: String = ""
    @State private var password: String = ""
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            if adminAuth.isAdminLoggedIn {
                AdvertisementAdminScreen()
                    .navigationBarBackButtonHidden(true)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("ログアウト") {
                                adminAuth.logout()
                            }
                            .foregroundColor(.red)
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("閉じる") {
                                dismiss()
                            }
                        }
                    }
            } else {
                VStack(spacing: 30) {
                    // Logo/Header
                    VStack(spacing: 16) {
                        Image(systemName: "lock.shield")
                            .font(.system(size: 80))
                            .foregroundColor(.purple)
                        
                        Text("管理者ログイン")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("管理機能にアクセスするにはログインが必要です")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 40)
                    
                    // Login Form
                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("ユーザーID")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                            
                            TextField("ユーザーIDを入力", text: $username)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("パスワード")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.primary)
                            
                            SecureField("パスワードを入力", text: $password)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        if showError {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                                .padding(.horizontal)
                        }
                        
                        Button(action: {
                            attemptLogin()
                        }) {
                            Text("ログイン")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.purple)
                                .cornerRadius(10)
                        }
                        .disabled(username.isEmpty || password.isEmpty)
                    }
                    .padding(.horizontal, 40)
                    
                    Spacer()
                }
                .navigationTitle("管理者認証")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("キャンセル") {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
    
    private func attemptLogin() {
        if adminAuth.login(username: username, password: password) {
            // ログイン成功
            showError = false
        } else {
            // ログイン失敗
            errorMessage = "ユーザーIDまたはパスワードが正しくありません"
            showError = true
            
            // パスワードフィールドをクリア
            password = ""
        }
    }
}

struct AdminLoginView_Previews: PreviewProvider {
    static var previews: some View {
        AdminLoginView()
    }
}