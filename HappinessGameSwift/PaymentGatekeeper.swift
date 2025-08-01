import SwiftUI
import Foundation

class PaymentGatekeeper: ObservableObject {
    static let shared = PaymentGatekeeper()
    
    @Published var shouldShowPaymentRequired = false
    @Published var isAppLocked = false
    
    // 2ヶ月の無料期間（秒）
    private let freeTrialDuration: TimeInterval = 60 * 60 * 24 * 40 // 40日後に課金要求
    
    // デバッグ用：短い期間でテスト
    #if DEBUG
    private let debugTrialDuration: TimeInterval = 60 * 2 // 2分（テスト用）
    var useDebugDuration = false // publicに変更してテスト可能に
    #endif
    
    private var checkTimer: Timer?
    
    init() {
        checkPaymentStatus()
        startPeriodicCheck()
    }
    
    // 初回インストール日を取得または設定（Keychainを使用）
    private var installDate: Date {
        get {
            // まずKeychainから取得を試みる
            if let keychainDate = getFirstInstallDateFromKeychain() {
                return keychainDate
            }
            
            // Keychainにない場合はUserDefaultsから移行
            if let date = UserDefaults.standard.object(forKey: "appInstallDate") as? Date {
                // Keychainに保存
                saveFirstInstallDateToKeychain(date)
                return date
            }
            
            // どちらにもない場合は新規インストール
            let now = Date()
            UserDefaults.standard.set(now, forKey: "appInstallDate")
            saveFirstInstallDateToKeychain(now)
            return now
        }
    }
    
    // MARK: - Keychain Helpers
    
    private let deviceId: String = {
        if let vendorId = UIDevice.current.identifierForVendor?.uuidString {
            return vendorId
        }
        return UUID().uuidString
    }()
    
    private func getFirstInstallDateFromKeychain() -> Date? {
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
    
    // プレミアムユーザーかどうか（Firebaseから同期）
    private var isPremiumUser: Bool {
        get {
            // ユーザーIDがある場合はFirebaseから同期、ない場合はローカルのみ
            return UserDefaults.standard.bool(forKey: "isPremiumUser")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "isPremiumUser")
        }
    }
    
    // 支払い状態をチェック（Firebase同期あり）
    func checkPaymentStatus() {
        // ユーザーIDがある場合はFirebaseからプレミアムステータスを同期
        if let userId = UserDefaults.standard.string(forKey: "userId"), !userId.isEmpty {
            syncPremiumStatusFromFirebase(userId: userId)
        }
        
        // 既にプレミアムユーザーの場合は何もしない
        if isPremiumUser {
            isAppLocked = false
            shouldShowPaymentRequired = false
            return
        }
        
        // 無料期間の計算
        let timeElapsed = Date().timeIntervalSince(installDate)
        
        let trialDuration = freeTrialDuration
        
        #if DEBUG
        // print("🔍 PaymentGatekeeper Debug:")
        print("  - Install Date: \(installDate)")
        print("  - Time Elapsed: \(Int(timeElapsed)) seconds")
        print("  - Trial Duration: \(Int(trialDuration)) seconds")
        print("  - Remaining: \(Int(trialDuration - timeElapsed)) seconds")
        print("  - Is Premium: \(isPremiumUser)")
        print("  - Should Lock: \(timeElapsed > trialDuration)")
        #endif
        
        if timeElapsed > trialDuration {
            // 無料期間終了
            isAppLocked = true
            shouldShowPaymentRequired = true
            print("🔒 App is now locked - payment required")
        } else {
            isAppLocked = false
            shouldShowPaymentRequired = false
            print("🔓 App is unlocked - within trial period")
        }
    }
    
    // Firebaseからプレミアムステータスを同期
    private func syncPremiumStatusFromFirebase(userId: String) {
        FirebaseManager.shared.loadPremiumUserStatus(userId: userId) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch result {
                case .success(let (isPremium, purchaseDate)):
                    #if DEBUG
                    // print("✅ Premium status synced from Firebase: isPremium=\(isPremium)")
                    #endif
                    
                    // ローカルのプレミアムステータスを更新
                    self.isPremiumUser = isPremium
                    
                    if isPremium, let purchaseDate = purchaseDate {
                        UserDefaults.standard.set(purchaseDate, forKey: "premiumPurchaseDate")
                    }
                    
                    // UIを更新
                    if isPremium {
                        self.isAppLocked = false
                        self.shouldShowPaymentRequired = false
                    }
                    
                case .failure(let error):
                    #if DEBUG
                    // print("❌ Failed to sync premium status from Firebase: \(error)")
                    #endif
                    // Firebaseからの取得に失敗した場合はローカルの情報を使用
                }
            }
        }
    }
    
    // 定期的にチェック
    private func startPeriodicCheck() {
        checkTimer?.invalidate()
        // 1時間ごとにチェック（40日の試用期間に対応）
        checkTimer = Timer.scheduledTimer(withTimeInterval: 3600, repeats: true) { _ in
            self.checkPaymentStatus()
        }
    }
    
    // 購入完了時に呼ぶ（Firebase同期あり）
    func markAsPremium() {
        isPremiumUser = true
        isAppLocked = false
        shouldShowPaymentRequired = false
        
        let purchaseDate = Date()
        UserDefaults.standard.set(purchaseDate, forKey: "premiumPurchaseDate")
        
        // Firebaseにも保存
        if let userId = UserDefaults.standard.string(forKey: "userId"), !userId.isEmpty {
            FirebaseManager.shared.savePremiumUserStatus(
                userId: userId,
                isPremium: true,
                purchaseDate: purchaseDate
            ) { result in
                #if DEBUG
                switch result {
                case .success():
                    break // print("✅ Premium status marked and saved to Firebase successfully")
                case .failure(_):
                    break // print("❌ Failed to save premium status to Firebase: \(error)")
                }
                #endif
            }
        }
    }
    
    // 残り日数を取得
    func getRemainingDays() -> Int {
        if isPremiumUser { return -1 }
        
        let timeElapsed = Date().timeIntervalSince(installDate)
        
        #if DEBUG
        let trialDuration = useDebugDuration ? debugTrialDuration : freeTrialDuration
        #else
        let trialDuration = freeTrialDuration
        #endif
        
        let remainingTime = trialDuration - timeElapsed
        if remainingTime <= 0 { return 0 }
        
        // デバッグモードで短い期間の場合は秒数を返す
        #if DEBUG
        if trialDuration <= 300 { // 5分以下の場合
            return Int(ceil(remainingTime))
        }
        #endif
        
        return Int(ceil(remainingTime / (60 * 60 * 24)))
    }
    
    #if DEBUG
    // デバッグ用：短い試用期間を有効化
    func enableDebugTrialDuration() {
        useDebugDuration = true
        checkPaymentStatus()
    }
    
    // デバッグ用：試用期間をリセット
    func resetTrialPeriod() {
        // UserDefaultsから削除
        UserDefaults.standard.removeObject(forKey: "appInstallDate")
        UserDefaults.standard.removeObject(forKey: "devicePremiumStatus")
        UserDefaults.standard.removeObject(forKey: "devicePremiumPurchaseDate")
        UserDefaults.standard.removeObject(forKey: "isPremiumUser")
        UserDefaults.standard.removeObject(forKey: "premiumPurchaseDate")
        
        // Keychainからも削除
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "firstInstallDate_\(deviceId)",
            kSecAttrService as String: "HappinessGameSwift"
        ]
        SecItemDelete(query as CFDictionary)
        
        isPremiumUser = false
        _ = installDate // 新しい日付を設定
        checkPaymentStatus()
    }
    
    // ユーザーログイン時にFirebaseからプレミアムステータスを同期
    func syncPremiumStatusOnLogin(userId: String) {
        FirebaseManager.shared.loadPremiumUserStatus(userId: userId) { [weak self] result in
            DispatchQueue.main.async {
                guard let self = self else { return }
                
                switch result {
                case .success(let (isPremium, purchaseDate)):
                    #if DEBUG
                    // print("✅ Premium status synced on login: isPremium=\(isPremium)")
                    #endif
                    
                    // ローカルのプレミアムステータスを更新
                    self.isPremiumUser = isPremium
                    
                    if isPremium, let purchaseDate = purchaseDate {
                        UserDefaults.standard.set(purchaseDate, forKey: "premiumPurchaseDate")
                    }
                    
                    // 支払い状態を再チェック
                    self.checkPaymentStatus()
                    
                case .failure(_):
                    #if DEBUG
                    // print("❌ Failed to sync premium status on login: \(error)")
                    #endif
                    // Firebaseからの取得に失敗した場合はローカルの情報を使用
                    self.checkPaymentStatus()
                }
            }
        }
    }
    #endif
}