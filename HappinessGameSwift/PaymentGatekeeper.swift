import SwiftUI
import Foundation

class PaymentGatekeeper: ObservableObject {
    static let shared = PaymentGatekeeper()
    
    @Published var shouldShowPaymentRequired = false
    @Published var isAppLocked = false
    
    // 2ヶ月の無料期間（秒）
    private let freeTrialDuration: TimeInterval = 60 * 60 * 24 * 60 // 60日
    
    // デバッグ用：短い期間でテスト
    #if DEBUG
    private let debugTrialDuration: TimeInterval = 60 * 2 // 2分
    private var useDebugDuration = false
    #endif
    
    private var checkTimer: Timer?
    
    init() {
        checkPaymentStatus()
        startPeriodicCheck()
    }
    
    // 初回インストール日を取得または設定
    private var installDate: Date {
        get {
            if let date = UserDefaults.standard.object(forKey: "appInstallDate") as? Date {
                return date
            } else {
                let now = Date()
                UserDefaults.standard.set(now, forKey: "appInstallDate")
                return now
            }
        }
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
        
        #if DEBUG
        let trialDuration = useDebugDuration ? debugTrialDuration : freeTrialDuration
        #else
        let trialDuration = freeTrialDuration
        #endif
        
        if timeElapsed > trialDuration {
            // 無料期間終了
            isAppLocked = true
            shouldShowPaymentRequired = true
        } else {
            isAppLocked = false
            shouldShowPaymentRequired = false
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
                    print("✅ Premium status synced from Firebase: isPremium=\(isPremium)")
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
                    print("❌ Failed to sync premium status from Firebase: \(error)")
                    #endif
                    // Firebaseからの取得に失敗した場合はローカルの情報を使用
                }
            }
        }
    }
    
    // 定期的にチェック
    private func startPeriodicCheck() {
        checkTimer?.invalidate()
        checkTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
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
                    print("✅ Premium status marked and saved to Firebase successfully")
                case .failure(let error):
                    print("❌ Failed to save premium status to Firebase: \(error)")
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
        UserDefaults.standard.removeObject(forKey: "appInstallDate")
        UserDefaults.standard.removeObject(forKey: "devicePremiumStatus")
        UserDefaults.standard.removeObject(forKey: "devicePremiumPurchaseDate")
        UserDefaults.standard.removeObject(forKey: "isPremiumUser")
        UserDefaults.standard.removeObject(forKey: "premiumPurchaseDate")
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
                    print("✅ Premium status synced on login: isPremium=\(isPremium)")
                    #endif
                    
                    // ローカルのプレミアムステータスを更新
                    self.isPremiumUser = isPremium
                    
                    if isPremium, let purchaseDate = purchaseDate {
                        UserDefaults.standard.set(purchaseDate, forKey: "premiumPurchaseDate")
                    }
                    
                    // 支払い状態を再チェック
                    self.checkPaymentStatus()
                    
                case .failure(let error):
                    #if DEBUG
                    print("❌ Failed to sync premium status on login: \(error)")
                    #endif
                    // Firebaseからの取得に失敗した場合はローカルの情報を使用
                    self.checkPaymentStatus()
                }
            }
        }
    }
    #endif
}