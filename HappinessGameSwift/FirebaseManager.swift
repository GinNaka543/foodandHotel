import Foundation
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth
import UIKit

class FirebaseManager: ObservableObject {
    static let shared = FirebaseManager()
    private let db = Firestore.firestore()
    @Published var publicPlans: [VisitPlanModel] = []
    @Published var userPlans: [VisitPlanModel] = []
    
    private init() {}
    
    // ユーザープロファイルをFirebaseに保存
    func saveUserProfile(_ profile: UserProfile, completion: @escaping (Result<Void, Error>) -> Void) {
        print("🔥 Firebase保存開始: ユーザーID=\(profile.id), ユーザー名=\(profile.username)")
        let userRef = db.collection("users").document(profile.id)
        
        var userData: [String: Any] = [
            "id": profile.id,
            "username": profile.username,
            "createdAt": Timestamp(date: profile.createdAt),
            "updatedAt": Timestamp(date: profile.updatedAt),
            "platform": "iOS",
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        ]
        
        // 誕生日がある場合は追加
        if let birthday = profile.birthday {
            userData["birthday"] = Timestamp(date: birthday)
        }
        
        print("🔥 Firebase書き込みデータ: \(userData)")
        userRef.setData(userData) { error in
            if let error = error {
                print("❌ Firebase書き込みエラー: \(error)")
                completion(.failure(error))
            } else {
                print("✅ Firebase基本プロフィール保存成功")
                // ユーザーが登録したキャラクターとアニメも保存
                self.saveUserContentData(userId: profile.id)
                completion(.success(()))
            }
        }
    }
    
    // ユーザーが登録したキャラクターとアニメデータを保存
    private func saveUserContentData(userId: String) {
        print("🔥 ユーザーコンテンツ保存開始: ユーザーID=\(userId)")
        
        // キャラクターデータを保存
        if let charactersData = UserDefaults.standard.data(forKey: "characters"),
           let characters = try? JSONDecoder().decode([Character].self, from: charactersData) {
            
            print("🔥 キャラクター保存開始: \(characters.count)件")
            for character in characters {
                let characterRef = db.collection("userCharacters").document("\(userId)_\(character.id)")
                let characterData: [String: Any] = [
                    "userId": userId,
                    "characterId": character.id.uuidString,
                    "name": character.name,
                    "tag": character.tag,
                    "anime": "", // character.anime is not available in current Character struct
                    "createdAt": Timestamp(date: Date()), // character.createdAt is not available
                    "updatedAt": Timestamp(date: Date())  // character.updatedAt is not available
                ]
                
                characterRef.setData(characterData, merge: true) { error in
                    if let error = error {
                        print("❌ キャラクター保存エラー \(character.name): \(error)")
                    } else {
                        print("✅ キャラクター保存成功: \(character.name)")
                    }
                }
            }
        } else {
            print("🔥 キャラクターデータなし")
        }
        
        // アニメデータを保存
        if let animesData = UserDefaults.standard.data(forKey: "animes"),
           let animes = try? JSONDecoder().decode([Anime].self, from: animesData) {
            
            print("🔥 アニメ保存開始: \(animes.count)件")
            for anime in animes {
                let animeRef = db.collection("userAnimes").document("\(userId)_\(anime.id)")
                let animeData: [String: Any] = [
                    "userId": userId,
                    "animeId": anime.id.uuidString,
                    "title": anime.title,
                    "hashtag": anime.hashtag,
                    "createdAt": Timestamp(date: Date()), // anime.createdAt may not be available
                    "updatedAt": Timestamp(date: Date())  // anime.updatedAt may not be available
                ]
                
                animeRef.setData(animeData, merge: true) { error in
                    if let error = error {
                        print("❌ アニメ保存エラー \(anime.title): \(error)")
                    } else {
                        print("✅ アニメ保存成功: \(anime.title)")
                    }
                }
            }
        } else {
            print("🔥 アニメデータなし")
        }
    }
    
    // ユーザーの好みデータを更新
    private func updateUserPreferences(_ profile: HappinessGameSwift.UserProfile) {
        // Firebaseが利用可能になったらコメントを解除
        /*
        // アニメ別のインデックスを更新
        for anime in profile.favoriteAnimes {
            let animeRef = db.collection("animeIndex").document(anime)
            animeRef.setData([
                "name": anime,
                "users": FieldValue.arrayUnion([profile.id]),
                "updatedAt": Timestamp(date: Date())
            ], merge: true)
        }
        
        // キャラクター別のインデックスを更新
        for character in profile.favoriteCharacters {
            let characterRef = db.collection("characterIndex").document(character)
            characterRef.setData([
                "name": character,
                "users": FieldValue.arrayUnion([profile.id]),
                "updatedAt": Timestamp(date: Date())
            ], merge: true)
        }
        
        // ハッシュタグ別のインデックスを更新
        for hashtag in profile.hashtags {
            let hashtagRef = db.collection("hashtagIndex").document(hashtag)
            hashtagRef.setData([
                "tag": hashtag,
                "users": FieldValue.arrayUnion([profile.id]),
                "updatedAt": Timestamp(date: Date())
            ], merge: true)
        }
        */
    }
    
    // 広告を取得（プレースメント指定）
    func fetchAds(for placement: String, completion: @escaping (Result<[Advertisement], Error>) -> Void) {
        print("🔥 広告取得開始: placement=\(placement)")
        print("[DEBUG] Firestoreクエリ: collection=advertisements, isActive=true, placements(array-contains)=\(placement)")
        
        db.collection("advertisements")
            .whereField("isActive", isEqualTo: true)
            .whereField("placements", arrayContains: placement)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ 広告取得エラー: \(error)")
                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("⚠️ 広告なし (snapshot.documents is nil)")
                    completion(.success([]))
                    return
                }
                
                print("[DEBUG] 取得ドキュメント数: \(documents.count)")
                var ads: [Advertisement] = []
                for doc in documents {
                    let data = doc.data()
                    print("[DEBUG] ドキュメントID: \(doc.documentID)")
                    print("[DEBUG] フィールド一覧: \(data)")
                    
                    var ad = Advertisement(
                        id: doc.documentID,
                        title: data["title"] as? String ?? "",
                        description: data["description"] as? String ?? "",
                        imageURL: data["imageURL"] as? String ?? "",
                        linkURL: data["linkURL"] as? String ?? "",
                        targetAnimes: data["targetAnimes"] as? [String] ?? [],
                        targetCharacters: data["targetCharacters"] as? [String] ?? [],
                        targetHashtags: data["targetHashtags"] as? [String] ?? [],
                        placements: data["placements"] as? [String] ?? [],
                        impressions: data["impressions"] as? Int ?? 0,
                        clicks: data["clicks"] as? Int ?? 0,
                        isActive: data["isActive"] as? Bool ?? true
                    )
                    
                    // Timestamp変換
                    if let createdTimestamp = data["createdAt"] as? Timestamp {
                        ad.createdAt = createdTimestamp.dateValue()
                    }
                    if let expiresTimestamp = data["expiresAt"] as? Timestamp {
                        ad.expiresAt = expiresTimestamp.dateValue()
                    }
                    
                    // 有効期限チェック
                    if let expiresAt = ad.expiresAt, expiresAt < Date() {
                        print("⚠️ 期限切れ広告: \(ad.title)")
                        continue
                    }
                    
                    ads.append(ad)
                    print("✅ 広告追加: \(ad.title)")
                }
                
                print("✅ 広告取得成功: \(ads.count)件")
                completion(.success(ads.shuffled()))
            }
    }
    
    // 広告を取得（旧メソッド - 互換性のため残す）
    func fetchAds(for profile: HappinessGameSwift.UserProfile, completion: @escaping (Result<[Advertisement], Error>) -> Void) {
        // Firebaseが利用可能になったらコメントを解除
        /*
        var ads: [Advertisement] = []
        let group = DispatchGroup()
        
        // アニメベースの広告を取得
        for anime in profile.favoriteAnimes {
            group.enter()
            db.collection("advertisements")
                .whereField("targetAnimes", arrayContains: anime)
                .whereField("isActive", isEqualTo: true)
                .limit(to: 5)
                .getDocuments { snapshot, error in
                    if let documents = snapshot?.documents {
                        for doc in documents {
                            if let ad = try? doc.data(as: Advertisement.self) {
                                ads.append(ad)
                            }
                        }
                    }
                    group.leave()
                }
        }
        
        // キャラクターベースの広告を取得
        for character in profile.favoriteCharacters {
            group.enter()
            db.collection("advertisements")
                .whereField("targetCharacters", arrayContains: character)
                .whereField("isActive", isEqualTo: true)
                .limit(to: 3)
                .getDocuments { snapshot, error in
                    if let documents = snapshot?.documents {
                        for doc in documents {
                            if let ad = try? doc.data(as: Advertisement.self) {
                                ads.append(ad)
                            }
                        }
                    }
                    group.leave()
                }
        }
        
        group.notify(queue: .main) {
            // 重複を削除してランダムに選択
            let uniqueAds = Array(Set(ads))
            let selectedAds = Array(uniqueAds.shuffled().prefix(3))
            completion(.success(selectedAds))
        }
        */
        // 一時的にダミーデータを返す
        completion(.success([]))
    }
    
    // ローカルのキャラクター名を取得
    private func loadCharacterNames() -> [String] {
        guard let data = UserDefaults.standard.data(forKey: "characters"),
              let characters = try? JSONDecoder().decode([Character].self, from: data) else {
            return []
        }
        return characters.map { $0.name }
    }
    
    // 広告インプレッションを記録
    func recordAdImpression(advertisementId: String) {
        guard !advertisementId.isEmpty else { return }
        
        let adRef = db.collection("advertisements").document(advertisementId)
        adRef.updateData([
            "impressions": FieldValue.increment(Int64(1))
        ]) { error in
            if let error = error {
                print("インプレッション記録エラー: \(error)")
            } else {
                print("✅ インプレッション記録成功: \(advertisementId)")
            }
        }
    }
    
    // 広告クリックを記録
    func recordAdClick(advertisementId: String) {
        guard !advertisementId.isEmpty else { return }
        
        let adRef = db.collection("advertisements").document(advertisementId)
        adRef.updateData([
            "clicks": FieldValue.increment(Int64(1))
        ]) { error in
            if let error = error {
                print("クリック記録エラー: \(error)")
            } else {
                print("✅ クリック記録成功: \(advertisementId)")
            }
        }
    }
    
    // MARK: - Visit Plan Functions
    
    // プランを保存（投稿）
    func saveVisitPlan(_ plan: VisitPlanModel, completion: @escaping (Result<Void, Error>) -> Void) {
        let planRef = db.collection("visitPlans").document(plan.id)
        planRef.setData(plan.dictionary) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    // 公開プランを取得（オールタブ用）
    func fetchPublicPlans(completion: @escaping (Result<[VisitPlanModel], Error>) -> Void) {
        db.collection("visitPlans")
            .whereField("isPublic", isEqualTo: true)
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                let plans = snapshot?.documents.compactMap { doc in
                    VisitPlanModel(dictionary: doc.data())
                } ?? []
                
                self.publicPlans = plans
                completion(.success(plans))
            }
    }
    
    // ユーザーのプランを取得（オリジナルタブ用）
    func fetchUserPlans(userId: String, completion: @escaping (Result<[VisitPlanModel], Error>) -> Void) {
        db.collection("visitPlans")
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                let plans = snapshot?.documents.compactMap { doc in
                    VisitPlanModel(dictionary: doc.data())
                } ?? []
                
                self.userPlans = plans
                completion(.success(plans))
            }
    }
    
    // プラン購入を記録
    func recordPlanPurchase(_ purchase: PlanPurchase, completion: @escaping (Result<Void, Error>) -> Void) {
        // 購入記録を保存
        let purchaseRef = db.collection("planPurchases").document(purchase.id)
        purchaseRef.setData(purchase.dictionary) { error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            // プランの購入者リストを更新
            let planRef = self.db.collection("visitPlans").document(purchase.planId)
            planRef.updateData([
                "purchasedBy": FieldValue.arrayUnion([purchase.userId])
            ]) { error in
                if let error = error {
                    completion(.failure(error))
                } else {
                    completion(.success(()))
                }
            }
        }
    }
    
    // プラン投稿料金の支払いを記録
    func recordPlanPostingPayment(_ payment: PlanPostingPayment, completion: @escaping (Result<Void, Error>) -> Void) {
        let paymentRef = db.collection("planPostingPayments").document(payment.id)
        paymentRef.setData(payment.dictionary) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    // ユーザーがプランを購入済みかチェック
    func checkPlanPurchased(userId: String, planId: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        db.collection("planPurchases")
            .whereField("userId", isEqualTo: userId)
            .whereField("planId", isEqualTo: planId)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                let isPurchased = !(snapshot?.documents.isEmpty ?? true)
                completion(.success(isPurchased))
            }
    }
}

// 広告モデル
struct Advertisement: Identifiable, Hashable {
    var id: String?
    var title: String
    var description: String
    var imageURL: String
    var linkURL: String
    var targetAnimes: [String]
    var targetCharacters: [String]
    var targetHashtags: [String]
    var placements: [String]
    var displayRate: Double = 100.0 // 表示率（0-100%）
    var priority: Int = 5 // 優先度（1-10）
    var impressions: Int = 0
    var clicks: Int = 0
    var isActive: Bool = true
    var createdAt: Date?
    var expiresAt: Date?
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: Advertisement, rhs: Advertisement) -> Bool {
        return lhs.id == rhs.id
    }
}