import Foundation

// UserDefaultsのキーをユーザーIDごとに分離するためのヘルパークラス
class UserDefaultsHelper {
    static let shared = UserDefaultsHelper()
    
    private init() {}
    
    // 現在のユーザーIDを取得
    private var currentUserId: String? {
        return UserDefaults.standard.string(forKey: "userId")
    }
    
    // ユーザーIDごとのキーを生成
    private func keyForUser(_ baseKey: String, userId: String? = nil) -> String {
        let userIdToUse = userId ?? currentUserId ?? "default"
        return "\(userIdToUse)_\(baseKey)"
    }
    
    // データの保存
    func setData(_ data: Data?, forKey key: String) {
        let userKey = keyForUser(key)
        UserDefaults.standard.set(data, forKey: userKey)
        // 即座に同期して確実に保存
        let success = UserDefaults.standard.synchronize()
        print("💾 [UserDefaultsHelper] Saved data for key '\(key)' (userKey: '\(userKey)'), size: \(data?.count ?? 0) bytes, sync success: \(success)")
        
        // デバッグ用：savedPlansの内容を確認
        if key == "savedPlans", let data = data {
            if let plans = try? JSONDecoder().decode([VisitPlanData].self, from: data) {
                print("💾 [UserDefaultsHelper] Saved \(plans.count) plans:")
                for plan in plans {
                    print("  - \(plan.title) (ID: \(plan.id), Draft: \(plan.isDraft), Spots: \(plan.spots.count))")
                }
            }
        }
    }
    
    // データの読み込み
    func getData(forKey key: String) -> Data? {
        let userKey = keyForUser(key)
        let data = UserDefaults.standard.data(forKey: userKey)
        print("📖 [UserDefaultsHelper] Loading data for key '\(key)' (userKey: '\(userKey)'), size: \(data?.count ?? 0) bytes, found: \(data != nil)")
        
        // デバッグ用：savedPlansの内容を確認
        if key == "savedPlans", let data = data {
            if let plans = try? JSONDecoder().decode([VisitPlanData].self, from: data) {
                print("📖 [UserDefaultsHelper] Loaded \(plans.count) plans:")
                for plan in plans {
                    print("  - \(plan.title) (ID: \(plan.id), Draft: \(plan.isDraft), Spots: \(plan.spots.count))")
                }
            }
        }
        
        return data
    }
    
    // 文字列の保存
    func setString(_ string: String?, forKey key: String) {
        let userKey = keyForUser(key)
        UserDefaults.standard.set(string, forKey: userKey)
    }
    
    // 文字列の読み込み
    func getString(forKey key: String) -> String? {
        let userKey = keyForUser(key)
        return UserDefaults.standard.string(forKey: userKey)
    }
    
    // Bool値の保存
    func setBool(_ bool: Bool, forKey key: String) {
        let userKey = keyForUser(key)
        UserDefaults.standard.set(bool, forKey: userKey)
    }
    
    // Bool値の読み込み
    func getBool(forKey key: String) -> Bool {
        let userKey = keyForUser(key)
        return UserDefaults.standard.bool(forKey: userKey)
    }
    
    // 特定のユーザーのデータをクリア
    func clearUserData(for userId: String) {
        let keysToCheck = [
            "characters",
            "animes",
            "savedPlans",
            "characterRankings",
            "animeRankings",
            "artworks",
            "albums",
            "hiddenPlanIds",
            "currentUserProfile"
        ]
        
        for key in keysToCheck {
            let userKey = keyForUser(key, userId: userId)
            UserDefaults.standard.removeObject(forKey: userKey)
        }
    }
    
    // 現在のユーザーのデータをクリア
    func clearCurrentUserData() {
        guard let userId = currentUserId else { return }
        clearUserData(for: userId)
    }
    
    // 既存のデータを新しいユーザーIDベースのキーに移行
    func migrateDataIfNeeded() {
        guard let userId = currentUserId else { return }
        
        let keysToMigrate = [
            "characters",
            "animes",
            "savedPlans",
            "characterRankings",
            "animeRankings",
            "artworks",
            "albums",
            "hiddenPlanIds"
        ]
        
        for key in keysToMigrate {
            // 古いキーでデータが存在し、新しいキーでデータが存在しない場合のみ移行
            if let oldData = UserDefaults.standard.data(forKey: key) {
                let newKey = keyForUser(key)
                if UserDefaults.standard.data(forKey: newKey) == nil {
                    UserDefaults.standard.set(oldData, forKey: newKey)
                    // 古いデータは削除しない（他のユーザーのデータの可能性があるため）
                }
            }
        }
    }
}