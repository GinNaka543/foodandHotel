import SwiftUI
import FirebaseCore
import FirebaseAuth
import FirebaseFirestore
import StripePaymentSheet
import UIKit
import BackgroundTasks

// AppDelegate for orientation control
class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock = UIInterfaceOrientationMask.portrait
    
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }
}

class MainTabSelection: ObservableObject {
    @Published var selectedTab: MainContainerView.Tab = .chara {
        didSet {
        }
    }
    @Published var showCharacterOrderModal = false
    @Published var showAnimeOrderModal = false
}

class AuthenticationManager: ObservableObject {
    @Published var isLoggedIn: Bool = UserDefaults.standard.bool(forKey: "isLoggedIn")
    @Published var requiresPayment: Bool = false
    @Published var hasPaid: Bool = UserDefaults.standard.bool(forKey: "hasPaidSubscription")
    
    let deviceId: String = {
        // Get device identifier that persists across app reinstalls
        if let vendorId = UIDevice.current.identifierForVendor?.uuidString {
            return vendorId
        }
        return UUID().uuidString
    }()
    
    private var paymentCheckTimer: Timer?
    
    init() {
        checkPaymentRequirement()
        startPaymentCheckTimer()
    }
    
    deinit {
        paymentCheckTimer?.invalidate()
    }
    
    private func startPaymentCheckTimer() {
        // Check every hour in production
        paymentCheckTimer = Timer.scheduledTimer(withTimeInterval: 3600.0, repeats: true) { _ in
            self.checkPaymentRequirement()
            self.syncSubscriptionStatus()
        }
    }
    
    func checkPaymentRequirement() {
        // Get first install date from keychain (persists across app reinstalls)
        if let firstInstallDate = getFirstInstallDateFromKeychain() {
            // Check months for production (2 months)
            let monthsSinceInstall = Calendar.current.dateComponents([.month], from: firstInstallDate, to: Date()).month ?? 0
            
            if monthsSinceInstall >= 2 && !hasPaid {
                requiresPayment = true
            }
        } else {
            // First time install - save the date to keychain
            saveFirstInstallDateToKeychain(Date())
        }
    }
    
    func login() {
        isLoggedIn = true
        // 既存データの移行を実行
        UserDefaultsHelper.shared.migrateDataIfNeeded()
        // ログイン後に通知を送信して、各Managerにデータを再読み込みさせる
        NotificationCenter.default.post(name: Notification.Name("UserDidLogin"), object: nil)
        
        // Save initial subscription tracking data
        if let userId = UserDefaults.standard.string(forKey: "userId") {
            saveInitialSubscriptionTracking(userId: userId)
        }
        
        // Sync subscription status from server
        syncSubscriptionStatus()
        
        // Check payment requirement after login
        checkPaymentRequirement()
    }
    
    private func saveInitialSubscriptionTracking(userId: String) {
        let db = Firestore.firestore()
        let firstInstallDate = getFirstInstallDateFromKeychain() ?? Date()
        
        // Save by device ID instead of user ID
        db.collection("device_subscriptions").document(deviceId).getDocument { document, error in
            if let document = document, document.exists {
                // Update with latest user info if device already exists
                db.collection("device_subscriptions").document(self.deviceId).updateData([
                    "currentUserId": userId,
                    "lastSeenAt": Date().timeIntervalSince1970
                ])
                return
            }
            
            // Create initial tracking document by device ID
            let trackingData: [String: Any] = [
                "deviceId": self.deviceId,
                "currentUserId": userId,
                "firstInstallDate": firstInstallDate.timeIntervalSince1970,
                "daysUntilPayment": 60, // 2 months (60 days) in production
                "hasPaid": self.hasPaid,
                "createdAt": Date().timeIntervalSince1970,
                "lastSeenAt": Date().timeIntervalSince1970
            ]
            
            db.collection("device_subscriptions").document(self.deviceId).setData(trackingData) { _ in
                // Successfully saved tracking data
            }
        }
    }
    
    func logout() {
        // ユーザー認証情報を削除（データは保持）
        UserDefaults.standard.removeObject(forKey: "userId")
        UserDefaults.standard.removeObject(forKey: "username")
        UserDefaults.standard.removeObject(forKey: "isLoggedIn")
        isLoggedIn = false
        
        // 注意: ユーザーのデータ（キャラクター、アニメ等）は削除しない
        // 再ログイン時に同じユーザーIDでログインすれば、データは自動的に復元される
    }
    
    func completePayment() {
        hasPaid = true
        requiresPayment = false
        UserDefaults.standard.set(true, forKey: "hasPaidSubscription")
        
        // PaymentGatekeeperを更新
        PaymentGatekeeper.shared.markAsPremium()
        
        // Save payment status to keychain with device ID
        savePaymentStatusToKeychain(deviceId: deviceId, hasPaid: true)
        
        // Update Firebase device subscription
        let db = Firestore.firestore()
        db.collection("device_subscriptions").document(deviceId).updateData([
            "hasPaid": true,
            "paymentDate": Date().timeIntervalSince1970,
            "amount": 600,
            "lastSeenAt": Date().timeIntervalSince1970
        ]) { _ in
            // Successfully updated device subscription
        }
        
        // Also update user document if logged in
        if let userId = UserDefaults.standard.string(forKey: "userId") {
            db.collection("users").document(userId).updateData([
                "hasPaidSubscription": true,
                "subscriptionDate": Timestamp(date: Date()),
                "subscriptionUpdatedAt": Timestamp(date: Date())
            ]) { _ in
                // Successfully updated user subscription
            }
        }
    }
    
    func syncSubscriptionStatus() {
        // Check subscription status by device ID
        let db = Firestore.firestore()
        db.collection("device_subscriptions").document(deviceId).getDocument { [weak self] (document, error) in
            if let document = document, document.exists {
                let serverHasPaid = document.data()?["hasPaid"] as? Bool ?? false
                
                DispatchQueue.main.async {
                    // Sync local status with server status
                    if serverHasPaid && self?.hasPaid == false {
                        // Server says paid but locally is unpaid, update local status
                        self?.hasPaid = true
                        self?.requiresPayment = false
                        UserDefaults.standard.set(true, forKey: "hasPaidSubscription")
                        
                        // Save payment status to keychain
                        if let deviceId = self?.deviceId {
                            self?.savePaymentStatusToKeychain(deviceId: deviceId, hasPaid: true)
                        }
                    } else if !serverHasPaid && self?.hasPaid == true {
                        // Server says unpaid but locally is paid, reset local status
                        self?.hasPaid = false
                        self?.requiresPayment = true
                        UserDefaults.standard.set(false, forKey: "hasPaidSubscription")
                        
                        // Clear payment status from keychain
                        if let deviceId = self?.deviceId {
                            self?.clearPaymentStatusFromKeychain(deviceId: deviceId)
                        }
                    }
                    
                    // Always check payment requirement after sync
                    self?.checkPaymentRequirement()
                }
            } else {
            }
        }
    }
    
    private func clearPaymentStatusFromKeychain(deviceId: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "paymentStatus_\(deviceId)",
            kSecAttrService as String: "HappinessGameSwift"
        ]
        SecItemDelete(query as CFDictionary)
    }
    
    // MARK: - Keychain Helpers
    
    func getFirstInstallDateFromKeychain() -> Date? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "firstInstallDate_\(deviceId)",
            kSecAttrService as String: "HappinessGameSwift",
            kSecReturnData as String: true
        ]
        
        var dataTypeRef: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == errSecSuccess, let data = dataTypeRef as? Data {
            return try? JSONDecoder().decode(Date.self, from: data)
        }
        return nil
    }
    
    private func saveFirstInstallDateToKeychain(_ date: Date) {
        guard let data = try? JSONEncoder().encode(date) else { return }
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "firstInstallDate_\(deviceId)",
            kSecAttrService as String: "HappinessGameSwift",
            kSecValueData as String: data
        ]
        
        // Delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        SecItemAdd(query as CFDictionary, nil)
    }
    
    private func savePaymentStatusToKeychain(deviceId: String, hasPaid: Bool) {
        let data = Data(hasPaid.description.utf8)
        
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "paymentStatus_\(deviceId)",
            kSecAttrService as String: "HappinessGameSwift",
            kSecValueData as String: data
        ]
        
        // Delete any existing item
        SecItemDelete(query as CFDictionary)
        
        // Add new item
        SecItemAdd(query as CFDictionary, nil)
    }
}

@main
struct HappinessGameSwiftApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var mainTab = MainTabSelection()
    @StateObject private var characterManager = CharacterManager()
    @StateObject private var animeManager = AnimeManager()
    @StateObject private var productManager = ProductManager()
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var paymentGatekeeper = PaymentGatekeeper.shared
    @State private var showSplash = true
    @State private var hasSeenFirstLaunch = UserDefaults.standard.bool(forKey: "hasSeenFirstLaunch")
    @State private var hasRequestedTracking = UserDefaults.standard.bool(forKey: "hasRequestedTracking")
    
    init() {
        // Initialize memory pressure monitoring
        _ = MemoryPressureManager.shared
        
        // Initialize YouTube thumbnail manager (if available)
        // _ = YouTubeThumbnailManager.shared
        
        #if DEBUG
        // Track app launch performance
        let launchTracker = PerformanceMonitor.shared.startTracking(.appLaunch)
        #endif
        
        // Configure Firebase
        FirebaseApp.configure()
        #if DEBUG
        print("Firebase configured successfully")
        print("Bundle ID: \(Bundle.main.bundleIdentifier ?? "Unknown")")
        
        // Start network monitoring and diagnostics
        NetworkManager.shared.startMonitoring()
        
        // Delay network diagnostics to avoid blocking app launch
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 3.0) {
            NetworkManager.shared.diagnoseNetworkIssues()
        }
        #endif
        
        // Stripe SDKを初期化
        // Read Stripe publishable key from Info.plist
        if let infoDict = Bundle.main.infoDictionary,
           let stripeKey = infoDict["STRIPE_PUBLISHABLE_KEY"] as? String,
           !stripeKey.isEmpty {
            StripeAPI.defaultPublishableKey = stripeKey
        } else {
            fatalError("STRIPE_PUBLISHABLE_KEY not found in Info.plist")
        }
        
        // Initialize app optimizations
        _ = AppOptimizationManager.shared
        
        // Emergency cleanup for large data
        EmergencyCleanup.performEmergencyCleanup()
        
        // First, enforce UserDefaults size limit to prevent crashes
        DataMigrationManager.shared.enforceUserDefaultsSizeLimit()
        
        // 画像パスの移行処理を実行
        ImageMigrationHelper.shared.migrateAllImagePaths()
        
        // Migrate large data from UserDefaults to file storage
        DataMigrationManager.shared.performMigrationIfNeeded()
        
        // Enforce size limit again after migration
        DataMigrationManager.shared.enforceUserDefaultsSizeLimit()
        
        // Clean up old data
        DataMigrationManager.shared.cleanupOldData()
        
        // Debug: Check UserDefaults size (only in debug mode)
        #if DEBUG
        print("=== UserDefaults Size Analysis ===")
        print(DataMigrationManager.shared.estimateUserDefaultsSize())
        print("===================================")
        #endif
        
        // Stripe決済の事前初期化
        preloadStripePayment()
        
        #if DEBUG
        // End launch tracking
        launchTracker.end()
        #endif
        
        #if DEBUG
        // Setup app lifecycle monitoring
        setupLifecycleMonitoring()
        #endif
    }
    
    #if DEBUG
    private func setupLifecycleMonitoring() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didEnterBackgroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            PerformanceMonitor.shared.trackEvent(.appEnterBackground)
            // Clean up resources
            ImageCache.shared.clearMemoryCache()
        }
        
        NotificationCenter.default.addObserver(
            forName: UIApplication.willEnterForegroundNotification,
            object: nil,
            queue: .main
        ) { _ in
            PerformanceMonitor.shared.trackEvent(.appEnterForeground)
        }
    }
    #endif
    
    private func preloadStripePayment() {
        // アプリ起動時にStripeの支払いインテントを事前に作成
        // 少し遅延させてユーザーIDが利用可能になるのを待つ
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 2.0) {
            // ユーザーIDがない場合は、後でリトライするか、汎用的なプリロードを行う
            let userId = UserDefaults.standard.string(forKey: "userId") ?? "preload_user"
            
            guard let url = URL(string: "https://happiness-game.onrender.com/api/create-payment-intent") else {
                return
            }
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body: [String: Any] = [
                "amount": 600,
                "userId": userId,
                "pointAmount": 500,
                "type": "app_subscription"
            ]
            
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                return
            }
            
            URLSession.shared.dataTask(with: request) { data, response, _ in
                
                guard let data = data else { return }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let clientSecret = json["clientSecret"] as? String {
                        // PaymentSheetの設定を事前に準備
                        var configuration = PaymentSheet.Configuration()
                        configuration.merchantDisplayName = "AniCollect"
                        configuration.allowsDelayedPaymentMethods = false
                        
                        // 事前にPaymentSheetを作成（表示はしない）
                        _ = PaymentSheet(paymentIntentClientSecret: clientSecret, configuration: configuration)
                    }
                } catch {
                }
            }.resume()
        }
    }
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                // Main content
                if !hasSeenFirstLaunch {
                    // 初回起動時の説明画面
                    FirstLaunchView(hasSeenFirstLaunch: $hasSeenFirstLaunch)
                } else if !hasRequestedTracking {
                    // トラッキング許可画面
                    TrackingPermissionView(hasRequestedTracking: $hasRequestedTracking)
                } else if authManager.isLoggedIn {
                    if paymentGatekeeper.isAppLocked {
                        PaymentBlockerView()
                            .environmentObject(paymentGatekeeper)
                    } else {
                        MainContainerView()
                            .environmentObject(mainTab)
                            .environmentObject(characterManager)
                            .environmentObject(animeManager)
                            .environmentObject(productManager)
                            .environmentObject(authManager)
                            .environmentObject(paymentGatekeeper)
                            .onAppear {
                                // 開発用: サンプル画像を自動生成
                                createSampleImagesIfNeeded()
                                // ユーザーIDを確認
                                if UserDefaults.standard.string(forKey: "userId") != nil {
                                    // 既存データの移行を実行
                                    UserDefaultsHelper.shared.migrateDataIfNeeded()
                                    // データを再読み込み
                                    characterManager.loadCharacters()
                                    animeManager.loadAnimes()
                                }
                            }
                    }
                } else {
                    AuthSelectionView(authManager: authManager)
                }
                
                // Splash screen overlay
                if showSplash && hasSeenFirstLaunch {
                    SplashScreenView()
                        .transition(.opacity)
                        .zIndex(1)
                        .onAppear {
                            // 2秒後にスプラッシュ画面を非表示
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                withAnimation(.easeOut(duration: 0.5)) {
                                    showSplash = false
                                }
                            }
                        }
                }
            }
        }
    }
    
    func cleanupLargeUserDefaultsEntries() {
        let userDefaults = UserDefaults.standard
        let keys = userDefaults.dictionaryRepresentation().keys
        for key in keys {
            if key.hasPrefix("artworks_") || key.hasPrefix("videos_") {
                if let data = userDefaults.data(forKey: key), data.count >= 4_000_000 {
                    userDefaults.removeObject(forKey: key)
                }
            }
        }
    }
}

// メインコンテナビュー - ナビゲーションバーを固定し、上部コンテンツのみを切り替え
struct MainContainerView: View {
    @EnvironmentObject var mainTab: MainTabSelection
    @EnvironmentObject var characterManager: CharacterManager
    @EnvironmentObject var animeManager: AnimeManager
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var showingTermsOfService = false
    @State private var showingPaymentPopup = false
    
    enum Tab: Int, CaseIterable {
        case home = 0
        case chara = 1
        case anime = 2
        case visit = 3
        case card = 4
        
        var icon: String {
            switch self {
            case .home: return "house"
            case .chara: return "person.2"
            case .anime: return "tv"
            case .visit: return "link"
            case .card: return "shippingbox"
            }
        }
        
        var title: String {
            switch self {
            case .home: return NSLocalizedString("home", comment: "Home tab")
            case .chara: return NSLocalizedString("character", comment: "Character tab")
            case .anime: return NSLocalizedString("anime", comment: "Anime tab")
            case .visit: return NSLocalizedString("visit", comment: "Visit tab")
            case .card: return NSLocalizedString("product", comment: "Product tab")
            }
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // 上部コンテンツエリア
            VStack(spacing: 0) {
                // 選択されたタブに応じてコンテンツを表示
                VStack {
                    Group {
                        if mainTab.selectedTab == .home {
                            HomeScreen()
                                .environmentObject(mainTab)
                                .environmentObject(authManager)
                                .environmentObject(characterManager)
                                .environmentObject(animeManager)
                        } else if mainTab.selectedTab == .chara {
                            CharaScreen()
                                .environmentObject(mainTab)
                                .environmentObject(characterManager)
                        } else if mainTab.selectedTab == .anime {
                            AnimeScreen()
                                .environmentObject(mainTab)
                                .environmentObject(animeManager)
                                .environmentObject(characterManager)
                        } else if mainTab.selectedTab == .visit {
                            if UIDevice.current.userInterfaceIdiom == .pad {
                                VisitScreen_iPad()
                            } else {
                                VisitScreen()
                            }
                        } else if mainTab.selectedTab == .card {
                            ProductScreen()
                        }
                    }
                    .animation(nil, value: mainTab.selectedTab)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // ナビゲーションバーの高さ分のスペース
                Spacer().frame(height: 75)
            }
            
            // 固定の下部ナビゲーションバー
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 0) {
                    ForEach(Tab.allCases, id: \.rawValue) { tab in
                        NavigationBarItem(
                            icon: tab.icon,
                            title: tab.title,
                            isSelected: mainTab.selectedTab == tab,
                            onTap: {
                                // 即座にタブを切り替える（アニメーション削除）
                                mainTab.selectedTab = tab
                            }
                        )
                    }
                }
                .frame(height: 75)
                .background(Color.white)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color(.systemGray4)),
                    alignment: .top
                )
            }
            .edgesIgnoringSafeArea(.bottom)
        }
        .background(Color.white)
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowTermsOfService"))) { _ in
            showingTermsOfService = true
        }
        .fullScreenCover(isPresented: $showingTermsOfService) {
            TermsOfServiceView()
        }
        .sheet(isPresented: $showingPaymentPopup) {
            PaymentPopupView()
                .environmentObject(authManager)
                .interactiveDismissDisabled(true) // 支払い完了まで閉じれないようにする
        }
        .onAppear {
            // Check if payment is required
            if authManager.requiresPayment {
                showingPaymentPopup = true
            }
        }
        .onChange(of: authManager.requiresPayment) { _, newValue in
            if newValue {
                showingPaymentPopup = true
            }
        }
        .sheet(isPresented: $mainTab.showCharacterOrderModal) {
            CharacterOrderModal()
                .environmentObject(characterManager)
        }
        .sheet(isPresented: $mainTab.showAnimeOrderModal) {
            AnimeOrderModal()
                .environmentObject(animeManager)
        }
    }
}

// 各タブのコンテンツビュー
struct HomeContentView: View {
    @Binding var selectedTab: MainContainerView.Tab
    var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("中島 銀星")
                        .font(.system(size: 28, weight: .bold))
                    Text("Enter a status message")
                        .font(.system(size: 16))
                        .foregroundColor(.gray)
                }
                Spacer()
                Image("sample") // 仮のアイコン画像
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipShape(Circle())
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            
            // ステータスボタン
            HStack {
                Button(action: {}) {
                    HStack(spacing: 6) {
                        Image(systemName: "music.note")
                            .foregroundColor(.green)
                        Text("Select music")
                            .font(.system(size: 14))
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray6))
                    .cornerRadius(16)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            
            // 検索バー
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search", text: .constant(""))
                    .font(.system(size: 16))
            }
            .padding(10)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.horizontal, 20)
            .padding(.top, 12)
            
            // リスト
            VStack(alignment: .leading, spacing: 0) {
                Text("Friend lists")
                    .font(.system(size: 18, weight: .bold))
                    .padding(.top, 16)
                    .padding(.bottom, 4)
                ForEach(["Birthday reminders", "Friends", "Groups"], id: \.self) { name in
                    HStack {
                        Circle().fill(Color.gray).frame(width: 40, height: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(name)
                                .font(.system(size: 16, weight: .semibold))
                            Text("サンプル説明")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Text("2")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 6)
                }
            }
            .padding(.horizontal, 20)
            
            // サービス
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Services")
                        .font(.system(size: 18, weight: .bold))
                    Spacer()
                    Text("See all")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .padding(.top, 16)
                .padding(.bottom, 4)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 24) {
                        ForEach(["LINE AI", "Stickers", "Themes", "LINE GIFT", "LINE POINT C", "LINE GAME"], id: \.self) { service in
                            VStack(spacing: 6) {
                                Circle().stroke(Color.gray, lineWidth: 2).frame(width: 36, height: 36)
                                Text(service)
                                    .font(.system(size: 12))
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                }
            }
            .padding(.horizontal, 20)
            
            Spacer(minLength: 0)
        }
    }
}

struct CharaContentView: View {
    @StateObject private var characterManager = CharacterManager()
    @State private var showAddSheet = false
    @State private var searchText = ""
    @State private var selectedCharacter: Character? = nil
    @State private var showMenu = false
    @Binding var selectedTab: MainContainerView.Tab
    
    var filteredCharacters: [Character] {
        if searchText.isEmpty { return characterManager.characters }
        return characterManager.characters.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.tag.localizedCaseInsensitiveContains(searchText) ||
            $0.birthday.formatted(.dateTime.year().month().day()).contains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                // 左上メニューボタン
                Button(action: {
                    showMenu.toggle()
                }) {
                    Image(systemName: "line.horizontal.3")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.black)
                }
                Spacer()
                // 右上＋ボタン
                Button(action: { showAddSheet = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.black)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            // 検索バー
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color(.systemGray3))
                    .font(.system(size: 18))
                TextField("Search", text: $searchText)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .font(.system(size: 16))
                    .foregroundColor(.black)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
            .background(Color.white)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
            .frame(height: 38)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            
            // 広告バナー
            SimpleAdBannerView()
                .padding(.vertical, 2)
            
            // キャラリストのみスクロール
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(filteredCharacters, id: \.id) { character in
                        Button(action: {
                            selectedCharacter = character
                        }) {
                            CharacterRow(character: character, characterManager: characterManager)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .sheet(isPresented: $showAddSheet, onDismiss: {
            characterManager.loadCharacters()
        }) {
            AddCharacterSheet(characters: $characterManager.characters)
                .environmentObject(characterManager)
        }
        .fullScreenCover(item: $selectedCharacter) { character in
            CharacterDetailView(character: Binding(
                get: { character },
                set: { newCharacter in
                    if let idx = characterManager.characters.firstIndex(where: { $0.id == character.id }) {
                        characterManager.characters[idx] = newCharacter
                        characterManager.updateCharacter(newCharacter)
                    }
                    selectedCharacter = newCharacter
                }
            ), characters: $characterManager.characters, onDismiss: { 
                selectedCharacter = nil
                characterManager.refreshUI()
            })
            .environmentObject(characterManager)
        }
    }
}

struct AnimeContentView: View {
    @StateObject private var animeManager = AnimeManager()
    @State private var showAddSheet = false
    @State private var searchText = ""
    @State private var selectedAnime: Anime? = nil
    @State private var showMenu = false
    @Binding var selectedTab: MainContainerView.Tab
    
    var filteredAnimes: [Anime] {
        if searchText.isEmpty { return animeManager.animes }
        return animeManager.animes.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.hashtag.localizedCaseInsensitiveContains(searchText) ||
            $0.releaseDate.formatted(.dateTime.year().month().day()).contains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: {
                    showMenu.toggle()
                }) {
                    Image(systemName: "line.horizontal.3")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.black)
                }
                Spacer()
                Button(action: { showAddSheet = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.black)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color(.systemGray3))
                    .font(.system(size: 18))
                TextField("Search", text: $searchText)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .font(.system(size: 16))
                    .foregroundColor(.black)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
            .background(Color.white)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
            .frame(height: 38)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            
            // 広告バナー
            SimpleAdBannerView()
                .padding(.vertical, 2)
            
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(filteredAnimes, id: \.id) { anime in
                        Button(action: {
                            selectedAnime = anime
                        }) {
                            AnimeRow(anime: anime, animeManager: animeManager)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .sheet(isPresented: $showAddSheet, onDismiss: {
            animeManager.loadAnimes()
        }) {
            AddAnimeSheet(animes: $animeManager.animes)
                .environmentObject(animeManager)
        }
        .fullScreenCover(item: $selectedAnime) { anime in
            AnimeDetailView(anime: Binding(
                get: { anime },
                set: { newAnime in
                    if let idx = animeManager.animes.firstIndex(where: { $0.id == anime.id }) {
                        animeManager.animes[idx] = newAnime
                        animeManager.updateAnime(newAnime)
                    }
                }
            ), animes: $animeManager.animes)
            .environmentObject(animeManager)
        }
    }

}

struct VisitContentView: View {
    @Binding var selectedTab: MainContainerView.Tab
    var body: some View {
        VStack {
            Text("Visit Screen")
                .font(.title)
            Text("Coming Soon...")
                .foregroundColor(.gray)
        }
    }
}

struct CardContentView: View {
    @Binding var selectedTab: MainContainerView.Tab
    var body: some View {
        VStack {
            Text("Card Screen")
                .font(.title)
            Text("Coming Soon...")
                .foregroundColor(.gray)
        }
    }
}

// MARK: - SplashScreenView
struct SplashScreenView: View {
    var body: some View {
        ZStack {
            // 背景色（必要に応じて変更）
            Color.white
                .ignoresSafeArea()
            
            // ログインロゴを中央に表示
            Image("ログインロゴ")
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 200, maxHeight: 200)
        }
    }
}

// MARK: - PaymentPopupView
struct PaymentPopupView: View {
    @EnvironmentObject var authManager: AuthenticationManager
    @Environment(\.dismiss) var dismiss
    @State private var selectedPaymentMethod: PaymentMethod = .card
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var userPoints: Int = 0
    @State private var preloadedPaymentIntent: String? = nil
    @State private var isPreloadingPayment = false
    
    enum PaymentMethod {
        case card
        case points
    }
    
    private let subscriptionPackage = PointPackage(
        points: 500,
        price: 500,
        isPopular: false
    )
    
    var body: some View {
        NavigationView {
            ZStack {
                // Purple gradient background
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.6, green: 0.4, blue: 0.9),
                        Color(red: 0.8, green: 0.6, blue: 0.95)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                
                VStack(spacing: 25) {
                    // Header
                    VStack(spacing: 16) {
                        Image(systemName: "sparkles.square.filled.on.square")
                            .font(.system(size: 70))
                            .foregroundColor(.white)
                            .shadow(radius: 5)
                        
                        Text("2ヶ月の無料期間が終了しました")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("引き続きアプリをご利用いただくには\n600円（600ポイント）が必要です")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 20)
                    }
                    .padding(.top, 30)
                    
                    // Payment options
                    VStack(spacing: 16) {
                        // Points balance display
                        HStack {
                            Image(systemName: "star.circle.fill")
                                .foregroundColor(.yellow)
                            Text("保有ポイント: \(userPoints)pt")
                                .fontWeight(.medium)
                            
                            // Refresh button
                            Button(action: {
                                loadUserPoints()
                            }) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.white.opacity(0.2))
                        .cornerRadius(20)
                        
                        // Payment method selection
                        VStack(spacing: 12) {
                            // Point payment option
                            Button(action: {
                                selectedPaymentMethod = .points
                            }) {
                                HStack {
                                    Image(systemName: "star.circle.fill")
                                        .font(.title2)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("ポイントで支払う")
                                            .fontWeight(.semibold)
                                        Text("500pt")
                                            .font(.caption)
                                            .foregroundColor(userPoints >= 500 ? .white.opacity(0.8) : .white.opacity(0.5))
                                    }
                                    Spacer()
                                    if selectedPaymentMethod == .points {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(userPoints >= 500 ? Color.white.opacity(0.3) : Color.white.opacity(0.1))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(selectedPaymentMethod == .points ? Color.white : Color.clear, lineWidth: 2)
                                        )
                                )
                            }
                            .disabled(userPoints < 500)
                            .foregroundColor(.white)
                            
                            // Card payment option
                            Button(action: {
                                selectedPaymentMethod = .card
                            }) {
                                HStack {
                                    Image(systemName: "creditcard.circle.fill")
                                        .font(.title2)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("カードで支払う")
                                            .fontWeight(.semibold)
                                        Text("¥500")
                                            .font(.caption)
                                            .foregroundColor(.white.opacity(0.8))
                                    }
                                    Spacer()
                                    if selectedPaymentMethod == .card {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.3))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(selectedPaymentMethod == .card ? Color.white : Color.clear, lineWidth: 2)
                                        )
                                )
                            }
                            .foregroundColor(.white)
                        }
                        .padding(.horizontal, 20)
                    }
                    
                    Spacer()
                    
                    // Action buttons
                    VStack(spacing: 12) {
                        Button(action: {
                            processPayment()
                        }) {
                            if isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .purple))
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(12)
                            } else {
                                Text(selectedPaymentMethod == .points ? "500ポイントで支払う" : "購入する")
                                    .font(.headline)
                                    .foregroundColor(.purple)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.white)
                                    .cornerRadius(12)
                            }
                        }
                        .disabled(isProcessing || (selectedPaymentMethod == .points && userPoints < 500))
                    }
                    .padding(.horizontal, 40)
                    .padding(.bottom, 30)
                }
            }
            .navigationBarHidden(true)
            .alert("エラー", isPresented: $showError) {
                Button("OK") {
                    showError = false
                }
            } message: {
                Text(errorMessage ?? "支払い処理中にエラーが発生しました")
            }
        }
        .onAppear {
            loadUserPoints()
            preloadPaymentIntent()
        }
    }
    
    private func loadUserPoints() {
        // Load user points from Firebase
        if let userId = UserDefaults.standard.string(forKey: "userId") {
            // Use FirebaseManager to get user points
            FirebaseManager.shared.getUserPoints(userId: userId) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let pointsModel):
                        self.userPoints = pointsModel.points
                    case .failure(_):
                        // Try fallback to userPoints collection directly
                        let db = Firestore.firestore()
                        db.collection("userPoints").document(userId).getDocument { document, _ in
                            if let document = document, document.exists {
                                DispatchQueue.main.async {
                                    self.userPoints = document.data()?["points"] as? Int ?? 0
                                }
                            } else {
                                // Final fallback to UserDefaults
                                DispatchQueue.main.async {
                                    self.userPoints = UserDefaults.standard.integer(forKey: "userPoints_\(userId)")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func preloadPaymentIntent() {
        guard preloadedPaymentIntent == nil,
              !isPreloadingPayment,
              let userId = UserDefaults.standard.string(forKey: "userId") else { return }
        
        isPreloadingPayment = true
        
        // Create payment intent in advance
        guard let url = URL(string: "https://happiness-game.onrender.com/api/create-payment-intent") else {
            isPreloadingPayment = false
            return
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body: [String: Any] = [
            "amount": subscriptionPackage.price,
            "userId": userId,
            "pointAmount": subscriptionPackage.points,
            "type": "app_subscription"
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            isPreloadingPayment = false
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                self.isPreloadingPayment = false
                
                if error != nil {
                    return
                }
                
                guard let data = data else { return }
                
                do {
                    if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let clientSecret = json["clientSecret"] as? String {
                        self.preloadedPaymentIntent = clientSecret
                    }
                } catch {
                }
            }
        }.resume()
    }
    
    private func processPayment() {
        guard let userId = UserDefaults.standard.string(forKey: "userId") else {
            errorMessage = "ユーザーIDが見つかりません"
            showError = true
            return
        }
        
        isProcessing = true
        
        if selectedPaymentMethod == .points {
            // Process point payment
            processPointPayment(userId: userId)
        } else {
            // Process card payment
            processCardPayment(userId: userId)
        }
    }
    
    private func processPointPayment(userId: String) {
        // Use FirebaseManager to deduct points
        FirebaseManager.shared.usePoints(userId: userId, points: 500, reason: "アプリ利用料支払い") { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    // Update local points display
                    self.userPoints = max(0, self.userPoints - 500)
                    UserDefaults.standard.set(self.userPoints, forKey: "userPoints_\(userId)")
                    
                    // Payment successful
                    self.authManager.completePayment()
                    self.saveSubscriptionToFirebase(userId: userId, paymentMethod: "points")
                    self.isProcessing = false
                    self.dismiss()
                    
                case .failure(let error):
                    self.isProcessing = false
                    self.errorMessage = "ポイント支払いに失敗しました: \(error.localizedDescription)"
                    self.showError = true
                    // Reload points in case of error
                    self.loadUserPoints()
                }
            }
        }
    }
    
    private func processCardPayment(userId: String) {
        // If we have a preloaded payment intent, use it
        if let preloadedIntent = preloadedPaymentIntent {
            // Configure payment sheet
            var configuration = PaymentSheet.Configuration()
            configuration.merchantDisplayName = "AniCollect"
            configuration.allowsDelayedPaymentMethods = false
            
            // Create payment sheet with preloaded intent
            let paymentSheet = PaymentSheet(paymentIntentClientSecret: preloadedIntent, configuration: configuration)
            
            // Present payment sheet
            DispatchQueue.main.async {
                if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                   let window = windowScene.windows.first,
                   let viewController = window.rootViewController {
                    
                    var topViewController = viewController
                    while let presented = topViewController.presentedViewController {
                        topViewController = presented
                    }
                    
                    paymentSheet.present(from: topViewController) { paymentResult in
                        switch paymentResult {
                        case .completed:
                            // Payment successful
                            self.authManager.completePayment()
                            self.saveSubscriptionToFirebase(userId: userId, paymentMethod: "card")
                            self.isProcessing = false
                            self.dismiss()
                            
                        case .canceled:
                            self.isProcessing = false
                            self.errorMessage = "決済がキャンセルされました"
                            self.showError = true
                            
                        case .failed(let error):
                            self.isProcessing = false
                            self.errorMessage = error.localizedDescription
                            self.showError = true
                        }
                    }
                }
            }
        } else {
            // Fallback to regular payment flow
            StripePaymentManager.shared.purchasePoints(userId: userId, package: subscriptionPackage) { result in
                DispatchQueue.main.async {
                    self.isProcessing = false
                    
                    switch result {
                    case .success:
                        // Payment successful - update local state
                        self.authManager.completePayment()
                        
                        // Save subscription info to Firebase
                        self.saveSubscriptionToFirebase(userId: userId, paymentMethod: "card")
                        
                        self.dismiss()
                        
                    case .failure(let error):
                        self.errorMessage = error.localizedDescription
                        self.showError = true
                    }
                }
            }
        }
    }
    
    private func saveSubscriptionToFirebase(userId: String, paymentMethod: String) {
        // Save subscription status to Firebase by device ID
        let db = Firestore.firestore()
        let subscriptionData: [String: Any] = [
            "deviceId": authManager.deviceId,
            "currentUserId": userId,
            "subscribedAt": Date().timeIntervalSince1970,
            "amount": subscriptionPackage.price,
            "type": "app_subscription",
            "paymentMethod": paymentMethod,
            "firstInstallDate": authManager.getFirstInstallDateFromKeychain()?.timeIntervalSince1970 ?? Date().timeIntervalSince1970,
            "hasPaid": true,
            "paymentDate": Date().timeIntervalSince1970,
            "lastSeenAt": Date().timeIntervalSince1970
        ]
        
        // Save to device_subscriptions collection
        db.collection("device_subscriptions").document(authManager.deviceId).setData(subscriptionData, merge: true) { _ in
            // Successfully saved device subscription
        }
        
        // Also update user document with subscription status
        db.collection("users").document(userId).updateData([
            "hasSubscription": true,
            "subscriptionDate": Date().timeIntervalSince1970,
            "subscriptionPaymentMethod": paymentMethod
        ]) { _ in
            // Successfully updated user subscription status
        }
    }
}


 