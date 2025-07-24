import SwiftUI

struct FirstLaunchView: View {
    @Binding var hasSeenFirstLaunch: Bool
    @State private var currentPage = 0
    @State private var showPrivacyPolicy = false
    @State private var hasAgreedToPrivacy = false
    
    var body: some View {
        ZStack {
            // 背景のグラデーション
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.6, green: 0.4, blue: 0.9),
                    Color(red: 0.8, green: 0.6, blue: 0.95)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack {
                // ページインジケーター
                HStack(spacing: 10) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(currentPage == index ? Color.white : Color.white.opacity(0.5))
                            .frame(width: 10, height: 10)
                    }
                }
                .padding(.top, 50)
                
                TabView(selection: $currentPage) {
                    // ページ1: ようこそ
                    WelcomePage()
                        .tag(0)
                    
                    // ページ2: 料金説明
                    PricingPage()
                        .tag(1)
                    
                    // ページ3: 開始
                    StartPage(hasSeenFirstLaunch: $hasSeenFirstLaunch)
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
        }
    }
}

struct WelcomePage: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image("ログインロゴ")
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150)
                .shadow(radius: 10)
            
            Text("アニレコへようこそ")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("好きなキャラクターやアニメを\n記録して管理しましょう")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 40)
            
            Spacer()
            
            HStack {
                Text("スワイプして続ける")
                    .foregroundColor(.white.opacity(0.7))
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.bottom, 50)
        }
    }
}

struct PricingPage: View {
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "info.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.white)
                .shadow(radius: 10)
            
            Text("重要なお知らせ")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            VStack(spacing: 20) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("最初の2ヶ月間は無料")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(.yellow)
                    Text("2ヶ月後から500円")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 40)
            
            // 詳細説明
            VStack(spacing: 10) {
                Text("お試し期間について")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text("このアプリは最初の2ヶ月間は無料でご利用いただけます。")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.9))
                
                Text("2ヶ月経過後、継続利用には500円が必要となります。")
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.9))
                
                Text("支払いはポイントまたはクレジットカードで可能です。")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 20)
            .background(Color.white.opacity(0.2))
            .cornerRadius(15)
            .padding(.horizontal, 40)
            
            Spacer()
            
            HStack {
                Text("スワイプして続ける")
                    .foregroundColor(.white.opacity(0.7))
                Image(systemName: "chevron.right")
                    .foregroundColor(.white.opacity(0.7))
            }
            .padding(.bottom, 50)
        }
    }
}

struct StartPage: View {
    @Binding var hasSeenFirstLaunch: Bool
    @State private var showPrivacyPolicy = false
    @State private var hasAgreedToPrivacy = UserDefaults.standard.bool(forKey: "hasAgreedToPrivacyPolicy")
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "sparkles")
                .font(.system(size: 80))
                .foregroundColor(.white)
                .shadow(radius: 10)
            
            Text("始めましょう！")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("アカウントを作成して\nアプリを始めましょう")
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 40)
            
            Spacer()
            
            VStack(spacing: 20) {
                // プライバシーポリシーへの同意ボタン
                if !hasAgreedToPrivacy {
                    Button(action: {
                        showPrivacyPolicy = true
                    }) {
                        HStack {
                            Image(systemName: hasAgreedToPrivacy ? "checkmark.square.fill" : "square")
                                .foregroundColor(.white)
                            Text("プライバシーポリシーに同意する")
                                .font(.body)
                                .foregroundColor(.white)
                        }
                    }
                }
                
                Button(action: {
                    if hasAgreedToPrivacy {
                        // UserDefaultsに初回起動フラグを保存
                        UserDefaults.standard.set(true, forKey: "hasSeenFirstLaunch")
                        hasSeenFirstLaunch = true
                    } else {
                        showPrivacyPolicy = true
                    }
                }) {
                    Text("アプリを始める")
                        .font(.headline)
                        .foregroundColor(.purple)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(hasAgreedToPrivacy ? Color.white : Color.white.opacity(0.5))
                        .cornerRadius(25)
                        .shadow(radius: 10)
                }
                .padding(.horizontal, 60)
                
                Button(action: {
                    showPrivacyPolicy = true
                }) {
                    Text("プライバシーポリシーを読む")
                        .font(.caption)
                        .foregroundColor(.white)
                        .underline()
                }
            }
            
            Text("プライバシーポリシーに同意することで、アプリの利用を開始できます")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
                .padding(.bottom, 50)
        }
        .fullScreenCover(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView(hasAgreed: $hasAgreedToPrivacy, isInitialAgreement: true)
        }
    }
}

struct FirstLaunchView_Previews: PreviewProvider {
    static var previews: some View {
        FirstLaunchView(hasSeenFirstLaunch: .constant(false))
    }
}