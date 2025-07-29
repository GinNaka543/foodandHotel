import SwiftUI

struct AuthSelectionView: View {
    @ObservedObject var authManager: AuthenticationManager
    @State private var showLoginView = false
    @State private var showRegisterView = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ロゴとタイトル
                VStack(spacing: -22) { // -22 to move text 30px closer (8 - 30 = -22)
                    Image("icon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 84, height: 84)
                        .cornerRadius(17)
                    
                    Image("ログインロゴ")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 168)
                    
                    Text(NSLocalizedString("auth_selection_subtitle", comment: ""))
                        .font(.system(size: 20))
                        .foregroundColor(.gray)
                }
                .padding(.top, 130) // ロゴを上部に配置
                
                Spacer()
                
                // ボタンセクション
                VStack(spacing: 16) {
                    // ログインボタン（紫）
                    Button(action: {
                        showLoginView = true
                    }) {
                        Text(NSLocalizedString("login_button", comment: ""))
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.purple)
                            .cornerRadius(26)
                    }
                    
                    // 新規登録ボタン（白枠）
                    Button(action: {
                        showRegisterView = true
                    }) {
                        Text(NSLocalizedString("register_button", comment: ""))
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.purple)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 26)
                                    .stroke(Color.purple, lineWidth: 2)
                            )
                            .cornerRadius(26)
                    }
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 50)
            }
            .background(Color.white)
            .navigationBarHidden(true)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .fullScreenCover(isPresented: $showLoginView) {
            LoginScreenView(authManager: authManager)
        }
        .fullScreenCover(isPresented: $showRegisterView) {
            RegisterScreenView(authManager: authManager)
        }
    }
}

#Preview {
    AuthSelectionView(authManager: AuthenticationManager())
}