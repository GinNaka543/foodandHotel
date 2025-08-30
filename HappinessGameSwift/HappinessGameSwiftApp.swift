import SwiftUI
import UIKit
import BackgroundTasks

// AppDelegate for orientation control
class AppDelegate: NSObject, UIApplicationDelegate {
    static var orientationLock = UIInterfaceOrientationMask.portrait
    
    func application(_ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        return AppDelegate.orientationLock
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // print("⚠️ App will terminate - forcing UserDefaults synchronization")
        UserDefaults.standard.synchronize()
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // print("📱 App did enter background - synchronizing UserDefaults")
        UserDefaults.standard.synchronize()
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
            // Check days for production (40 days)
            let daysSinceInstall = Calendar.current.dateComponents([.day], from: firstInstallDate, to: Date()).day ?? 0
            
            if daysSinceInstall >= 40 && !hasPaid {
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
        // Save subscription tracking data to local storage
        let firstInstallDate = getFirstInstallDateFromKeychain() ?? Date()
        
        let trackingData: [String: Any] = [
            "deviceId": self.deviceId,
            "currentUserId": userId,
            "firstInstallDate": firstInstallDate.timeIntervalSince1970,
            "daysUntilPayment": 40, // 40 days until payment required
            "hasPaid": self.hasPaid,
            "createdAt": Date().timeIntervalSince1970,
            "lastSeenAt": Date().timeIntervalSince1970
        ]
        
        // Save to UserDefaults instead of Firebase
        UserDefaults.standard.set(trackingData, forKey: "subscriptionTracking_\(deviceId)")
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
        
        // Update local subscription tracking instead of Firebase
        var trackingData = UserDefaults.standard.dictionary(forKey: "subscriptionTracking_\(deviceId)") ?? [:]
        trackingData["hasPaid"] = true
        trackingData["paymentDate"] = Date().timeIntervalSince1970
        trackingData["amount"] = 600
        trackingData["lastSeenAt"] = Date().timeIntervalSince1970
        UserDefaults.standard.set(trackingData, forKey: "subscriptionTracking_\(deviceId)")
        
        // Also update user subscription data locally if logged in
        if let userId = UserDefaults.standard.string(forKey: "userId") {
            UserDefaults.standard.set(true, forKey: "userSubscription_\(userId)_hasPaid")
            UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "userSubscription_\(userId)_subscriptionDate")
        }
    }
    
    func syncSubscriptionStatus() {
        // Check subscription status from local storage instead of Firebase
        if let trackingData = UserDefaults.standard.dictionary(forKey: "subscriptionTracking_\(deviceId)"),
           let localHasPaid = trackingData["hasPaid"] as? Bool {
            
            // Update status based on local tracking data
            if localHasPaid && !hasPaid {
                // Local says paid but instance is unpaid, update instance status
                hasPaid = true
                requiresPayment = false
                UserDefaults.standard.set(true, forKey: "hasPaidSubscription")
                
                // Save payment status to keychain
                savePaymentStatusToKeychain(deviceId: deviceId, hasPaid: true)
            } else if !localHasPaid && hasPaid {
                // Local says unpaid but instance is paid, reset instance status
                hasPaid = false
                requiresPayment = true
                UserDefaults.standard.set(false, forKey: "hasPaidSubscription")
                
                // Clear payment status from keychain
                clearPaymentStatusFromKeychain(deviceId: deviceId)
            }
            
            // Always check payment requirement after sync
            checkPaymentRequirement()
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
    @StateObject private var authManager = AuthenticationManager()
    @StateObject private var paymentGatekeeper = PaymentGatekeeper.shared
    @StateObject private var localizationManager = LocalizationManager.shared
    @State private var showSplash = true
    @Environment(\.scenePhase) private var scenePhase
    
    init() {
        // Initialize localization manager first to ensure proper language loading
        _ = LocalizationManager.shared
        
        // Initialize memory pressure monitoring
        _ = MemoryPressureManager.shared
        
        // Initialize YouTube thumbnail manager (if available)
        // _ = YouTubeThumbnailManager.shared
        
        #if DEBUG
        // Track app launch performance
        let launchTracker = PerformanceMonitor.shared.startTracking(.appLaunch)
        #endif
        
        // Firebase削除済み
        #if DEBUG
        print("App configured successfully")
        print("Bundle ID: \(Bundle.main.bundleIdentifier ?? "Unknown")")
        
        // Start network monitoring and diagnostics
        NetworkManager.shared.startMonitoring()
        
        // Delay network diagnostics to avoid blocking app launch
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 3.0) {
            NetworkManager.shared.diagnoseNetworkIssues()
        }
        #endif
        
        // Stripe SDKを初期化 - 削除済み
        // Stripeは使用しないため、この部分はコメントアウト
        
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
        
        // Debug media files - disabled until MediaCleanupDebugger is added to project
        #if DEBUG
        // MediaCleanupDebugger.shared.debugMediaFiles()
        #endif
        
        // Debug: Check UserDefaults size (only in debug mode)
        #if DEBUG
        print("=== UserDefaults Size Analysis ===")
        print(DataMigrationManager.shared.estimateUserDefaultsSize())
        print("===================================")
        #endif
        
        
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
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                // Main content
                if paymentGatekeeper.isAppLocked {
                    PaymentBlockerView()
                        .environmentObject(paymentGatekeeper)
                        .environmentObject(localizationManager)
                } else {
                    MainContainerView()
                        .environmentObject(mainTab)
                        .environmentObject(characterManager)
                        .environmentObject(animeManager)
                        .environmentObject(authManager)
                        .environmentObject(paymentGatekeeper)
                        .environmentObject(localizationManager)
                        .onAppear {
                            // 開発用: サンプル画像を自動生成
                            createSampleImagesIfNeeded()
                            // ローカルデータを直接読み込み
                            characterManager.loadCharacters()
                            animeManager.loadAnimes()
                            
                            // DISABLED: Media cleanup causing video deletion issues
                            // Clean up orphaned media files after app startup
                            // DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                            //     print("🧹 [App] Triggering media cleanup...")
                            //     MediaCleanupManager.shared.cleanupOrphanedMediaFiles()
                            // }
                        }
                }
                
                // Splash screen overlay
                if showSplash {
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
            .onChange(of: scenePhase) { _, newPhase in
                switch newPhase {
                case .background:
                    // アプリがバックグラウンドに移行する時に UserDefaults を同期
                    // print("📱 App moving to background - synchronizing UserDefaults")
                    UserDefaults.standard.synchronize()
                    
                case .inactive:
                    // アプリが非アクティブになった時も同期
                    UserDefaults.standard.synchronize()
                case .active:
                    // アプリがアクティブになった時はデータを再読み込み
                    break
                @unknown default:
                    break
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

// ナビゲーションバーアイテムコンポーネント
struct NavigationBarItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .blue : .gray)
                Text(title)
                    .font(.caption)
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            .frame(maxWidth: .infinity)
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
        case chara = 0
        
        var icon: String {
            switch self {
            case .chara: return "fork.knife"
            }
        }
        
        var title: String {
            switch self {
            case .chara: return "グルメ"
            }
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        VStack {
            CharaScreen()
                .environmentObject(mainTab)
                .environmentObject(characterManager)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var bottomNavigationBar: some View {
        EmptyView() // Navigation bar removed since there's only one tab
    }
    
    var body: some View {
        VStack(spacing: 0) {
            mainContent
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
            $0.name.localizedCaseInsensitiveContains(searchText)
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
                        
                        Text("40日間の無料期間が終了しました")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("引き続きアプリをご利用いただくには\n600円（600ポイント）が必要です")
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white.opacity(0.9))
                            .padding(.horizontal, 20)
                        
                        Text("※40日後に課金が発生します")
                            .font(.footnote)
                            .fontWeight(.semibold)
                            .foregroundColor(.yellow)
                            .padding(.top, 5)
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
        // Load user points from local storage only
        if let userId = UserDefaults.standard.string(forKey: "userId") {
            // Load from UserDefaults directly
            userPoints = UserDefaults.standard.integer(forKey: "userPoints_\(userId)")
        } else {
            // Default to 0 if no user is logged in
            userPoints = 0
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
        // Process point payment locally
        if userPoints >= 500 {
            // Deduct points from local storage
            userPoints = max(0, userPoints - 500)
            UserDefaults.standard.set(userPoints, forKey: "userPoints_\(userId)")
            
            // Payment successful
            authManager.completePayment()
            saveSubscriptionLocally(userId: userId, paymentMethod: "points")
            isProcessing = false
            dismiss()
        } else {
            // Not enough points
            isProcessing = false
            errorMessage = "ポイントが不足しています。必要: 500pt, 現在: \(userPoints)pt"
            showError = true
        }
    }
    
    private func processCardPayment(userId: String) {
        // Process card payment locally (for testing purposes)
        // Note: In a real app, this would integrate with App Store In-App Purchases or another payment provider
        DispatchQueue.main.async {
            // Payment successful
            self.authManager.completePayment()
            self.saveSubscriptionLocally(userId: userId, paymentMethod: "card")
            self.isProcessing = false
            self.dismiss()
        }
    }
    
    private func saveSubscriptionLocally(userId: String, paymentMethod: String) {
        // Save subscription status to local storage instead of Firebase
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
        
        // Save to UserDefaults instead of Firebase
        UserDefaults.standard.set(subscriptionData, forKey: "subscriptionTracking_\(authManager.deviceId)")
        
        // Also update user subscription status locally
        UserDefaults.standard.set(true, forKey: "userSubscription_\(userId)_hasSubscription")
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "userSubscription_\(userId)_subscriptionDate")
        UserDefaults.standard.set(paymentMethod, forKey: "userSubscription_\(userId)_paymentMethod")
    }
}


 
