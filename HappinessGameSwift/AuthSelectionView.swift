import SwiftUI

struct AuthSelectionView: View {
    @ObservedObject var authManager: AuthenticationManager
    @State private var showLoginView = false
    @State private var showRegisterView = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                Spacer()
                
                // ロゴとタイトル
                VStack(spacing: 24) {
                    Image("icon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .cornerRadius(24)
                    
                    Image("ログインロゴ")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 80)
                    
                    Text("アニメの記録や管理を楽しもう！")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                // ボタンセクション
                VStack(spacing: 16) {
                    // ログインボタン（紫）
                    Button(action: {
                        showLoginView = true
                    }) {
                        Text("ログイン")
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
                        Text("新規登録")
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