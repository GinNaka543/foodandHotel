import SwiftUI

struct FirstLaunchView: View {
    @Binding var hasSeenFirstLaunch: Bool
    @State private var currentPage = 0
    @State private var showPrivacyPolicy = false
    @State private var hasAgreedToPrivacy = false
    @StateObject private var localizationManager = LocalizationManager.shared
    
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
                    WelcomePage(currentPage: $currentPage)
                        .tag(0)
                    
                    // ページ2: 料金説明
                    PricingPage(currentPage: $currentPage)
                        .tag(1)
                    
                    // ページ3: 開始
                    StartPage(hasSeenFirstLaunch: $hasSeenFirstLaunch, currentPage: $currentPage)
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
        }
    }
}

struct WelcomePage: View {
    @Binding var currentPage: Int
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image("ログインロゴ")
                .resizable()
                .scaledToFit()
                .frame(width: 150, height: 150)
                .shadow(radius: 10)
            
            Text(NSLocalizedString("welcome_to_anireco", comment: ""))
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(NSLocalizedString("welcome_description", comment: ""))
                .font(.title3)
                .multilineTextAlignment(.center)
                .foregroundColor(.white.opacity(0.9))
                .padding(.horizontal, 40)
            
            Spacer()
            
            VStack(spacing: 15) {
                HStack {
                    Text(NSLocalizedString("swipe_to_continue", comment: ""))
                        .foregroundColor(.white.opacity(0.7))
                    Image(systemName: "chevron.right")
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Button(action: {
                    withAnimation {
                        currentPage = 1
                    }
                }) {
                    Text(NSLocalizedString("next", comment: ""))
                        .font(.headline)
                        .foregroundColor(.purple)
                        .frame(width: 120)
                        .padding()
                        .background(Color.white)
                        .cornerRadius(25)
                        .shadow(radius: 5)
                }
            }
            .padding(.bottom, 50)
        }
    }
}

struct PricingPage: View {
    @Binding var currentPage: Int
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "info.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.white)
                .shadow(radius: 10)
            
            Text(NSLocalizedString("important_notice", comment: ""))
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            VStack(spacing: 20) {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text(NSLocalizedString("first_2_months_free", comment: ""))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundColor(.yellow)
                    Text(NSLocalizedString("after_2_months_600yen", comment: ""))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
            }
            .padding(.horizontal, 40)
            
            // 詳細説明
            VStack(spacing: 10) {
                Text(NSLocalizedString("trial_period_about", comment: ""))
                    .font(.headline)
                    .foregroundColor(.white)
                
                Text(NSLocalizedString("trial_period_description_1", comment: ""))
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.9))
                
                Text(NSLocalizedString("trial_period_description_2", comment: ""))
                    .font(.body)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white.opacity(0.9))
                
                Text(NSLocalizedString("payment_methods", comment: ""))
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
            
            VStack(spacing: 15) {
                HStack {
                    Text(NSLocalizedString("swipe_to_continue", comment: ""))
                        .foregroundColor(.white.opacity(0.7))
                    Image(systemName: "chevron.right")
                        .foregroundColor(.white.opacity(0.7))
                }
                
                HStack(spacing: 20) {
                    Button(action: {
                        withAnimation {
                            currentPage = 0
                        }
                    }) {
                        Text(NSLocalizedString("back", comment: ""))
                            .font(.headline)
                            .foregroundColor(.purple)
                            .frame(width: 100)
                            .padding()
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(25)
                            .shadow(radius: 5)
                    }
                    
                    Button(action: {
                        withAnimation {
                            currentPage = 2
                        }
                    }) {
                        Text(NSLocalizedString("next", comment: ""))
                            .font(.headline)
                            .foregroundColor(.purple)
                            .frame(width: 100)
                            .padding()
                            .background(Color.white)
                            .cornerRadius(25)
                            .shadow(radius: 5)
                    }
                }
            }
            .padding(.bottom, 50)
        }
    }
}

struct StartPage: View {
    @Binding var hasSeenFirstLaunch: Bool
    @Binding var currentPage: Int
    @State private var showPrivacyPolicy = false
    @State private var hasAgreedToPrivacy = UserDefaults.standard.bool(forKey: "hasAgreedToPrivacyPolicy")
    
    var body: some View {
        VStack(spacing: 30) {
            Spacer()
            
            Image(systemName: "sparkles")
                .font(.system(size: 80))
                .foregroundColor(.white)
                .shadow(radius: 10)
            
            Text(NSLocalizedString("lets_start", comment: ""))
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text(NSLocalizedString("create_account_start", comment: ""))
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
                            Text(NSLocalizedString("agree_to_privacy_policy", comment: ""))
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
                    Text(NSLocalizedString("start_app", comment: ""))
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
                    Text(NSLocalizedString("read_privacy_policy", comment: ""))
                        .font(.caption)
                        .foregroundColor(.white)
                        .underline()
                }
            }
            
            VStack(spacing: 15) {
                Text(NSLocalizedString("privacy_agreement_note", comment: ""))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                Button(action: {
                    withAnimation {
                        currentPage = 1
                    }
                }) {
                    Text(NSLocalizedString("back", comment: ""))
                        .font(.headline)
                        .foregroundColor(.purple)
                        .frame(width: 100)
                        .padding()
                        .background(Color.white.opacity(0.8))
                        .cornerRadius(25)
                        .shadow(radius: 5)
                }
            }
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