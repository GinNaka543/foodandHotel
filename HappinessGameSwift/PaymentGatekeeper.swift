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
    
    // プレミアムユーザーかどうか（ユーザーIDに紐付けない）
    private var isPremiumUser: Bool {
        get {
            // デバイス単位で管理
            return UserDefaults.standard.bool(forKey: "devicePremiumStatus")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "devicePremiumStatus")
        }
    }
    
    // 支払い状態をチェック
    func checkPaymentStatus() {
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
    
    // 定期的にチェック
    private func startPeriodicCheck() {
        checkTimer?.invalidate()
        checkTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { _ in
            self.checkPaymentStatus()
        }
    }
    
    // 購入完了時に呼ぶ
    func markAsPremium() {
        isPremiumUser = true
        isAppLocked = false
        shouldShowPaymentRequired = false
        
        // ユーザーIDに関係なく、デバイスに紐付ける
        UserDefaults.standard.set(Date(), forKey: "devicePremiumPurchaseDate")
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
        isPremiumUser = false
        _ = installDate // 新しい日付を設定
        checkPaymentStatus()
    }
    #endif
}