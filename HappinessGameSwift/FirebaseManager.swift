import Foundation
import FirebaseCore
import FirebaseFirestore
import FirebaseAuth
import UIKit

class FirebaseManager: ObservableObject {
    static let shared = FirebaseManager()
    private let db = Firestore.firestore()
    
    // dbへの読み取り専用アクセスを提供
    var database: Firestore {
        return db
    }
    @Published var publicPlans: [VisitPlanModel] = []
    @Published var userPlans: [VisitPlanModel] = []
    
    private init() {}
    
    // ユーザー認証を確認
    func verifyUser(username: String, userId: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        print("🔥 [FirebaseManager] verifyUser開始: username=\(username), userId=\(userId)")
        
        db.collection("users").document(userId).getDocument { snapshot, error in
            if let error = error {
                print("❌ [FirebaseManager] ユーザー確認エラー: \(error)")
                completion(.failure(error))
                return
            }
            
            guard let document = snapshot, document.exists,
                  let data = document.data(),
                  let storedUsername = data["username"] as? String else {
                print("⚠️ [FirebaseManager] ユーザーが見つかりません")
                completion(.success(false))
                return
            }
            
            // ユーザー名が一致するか確認
            let isValid = storedUsername == username
            print(isValid ? "✅ ユーザー認証成功" : "❌ ユーザー名が一致しません")
            completion(.success(isValid))
        }
    }
    
    // ユーザープロファイルをFirebaseから読み込み
    func loadUserProfile(userId: String, completion: @escaping (Result<UserProfile, Error>) -> Void) {
        print("🔥 [FirebaseManager] loadUserProfile開始: userId=\(userId)")
        
        db.collection("users").document(userId).getDocument { snapshot, error in
            if let error = error {
                print("❌ [FirebaseManager] プロフィール読み込みエラー: \(error)")
                completion(.failure(error))
                return
            }
            
            guard let document = snapshot, document.exists,
                  let data = document.data() else {
                print("⚠️ [FirebaseManager] プロフィールが見つかりません")
                completion(.failure(NSError(domain: "FirebaseManager", code: 404, userInfo: [NSLocalizedDescriptionKey: "プロフィールが見つかりません"])))
                return
            }
            
            let username = data["username"] as? String ?? ""
            let birthday = (data["birthday"] as? Timestamp)?.dateValue()
            let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() ?? Date()
            let favoriteVoiceActors = data["favoriteVoiceActors"] as? [String] ?? []
            
            let profile = UserProfile(
                id: userId,
                username: username,
                birthday: birthday,
                animeQuote: "", // Firebaseに保存されていない場合は空文字
                createdAt: createdAt,
                updatedAt: updatedAt,
                favoriteVoiceActors: favoriteVoiceActors
            )
            
            print("✅ [FirebaseManager] プロフィール読み込み成功: \(username)")
            completion(.success(profile))
        }
    }
    
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
        userRef.setData(userData, merge: true) { error in
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
            // Collect voice actors
            var voiceActors = Set<String>()
            for character in characters {
                if !character.voiceActor.isEmpty {
                    voiceActors.insert(character.voiceActor)
                }
                let characterRef = db.collection("userCharacters").document("\(userId)_\(character.id)")
                let characterData: [String: Any] = [
                    "userId": userId,
                    "characterId": character.id.uuidString,
                    "name": character.name,
                    "tag": character.tag,
                    "voiceActor": character.voiceActor,
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
            
            // Save voice actors to user profile
            if !voiceActors.isEmpty {
                let voiceActorsRef = db.collection("users").document(userId)
                voiceActorsRef.updateData([
                    "favoriteVoiceActors": Array(voiceActors)
                ]) { error in
                    if let error = error {
                        print("❌ 声優データ保存エラー: \(error)")
                    } else {
                        print("✅ 声優データ保存成功: \(voiceActors)")
                    }
                }
                
                // Save voice actors to userVoiceActors collection
                for (index, voiceActor) in voiceActors.enumerated() {
                    let voiceActorRef = db.collection("userVoiceActors").document("\(userId)_\(index)")
                    let voiceActorData: [String: Any] = [
                        "userId": userId,
                        "voiceActorId": UUID().uuidString,
                        "name": voiceActor,
                        "createdAt": Timestamp(date: Date()),
                        "updatedAt": Timestamp(date: Date())
                    ]
                    
                    voiceActorRef.setData(voiceActorData, merge: true) { error in
                        if let error = error {
                            print("❌ userVoiceActors保存エラー \(voiceActor): \(error)")
                        } else {
                            print("✅ userVoiceActors保存成功: \(voiceActor)")
                        }
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
    private func updateUserPreferences(_ profile: UserProfile) {
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
    
    // キャラクターランキングデータを取得（レガシー用）
    func fetchCharacterRankings(completion: @escaping (Result<[CharacterRanking], Error>) -> Void) {
        print("🔥 キャラクターランキング取得開始")
        
        db.collection("characterRankings")
            .order(by: "rank")
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ ランキング取得エラー: \(error)")
                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("⚠️ ランキングデータなし")
                    completion(.success([]))
                    return
                }
                
                print("[DEBUG] 取得ランキング数: \(documents.count)")
                var rankings: [CharacterRanking] = []
                
                for doc in documents {
                    let data = doc.data()
                    
                    guard let rank = data["rank"] as? Int,
                          let characterName = data["characterName"] as? String,
                          let characterIdString = data["characterId"] as? String,
                          let characterId = UUID(uuidString: characterIdString) else {
                        print("⚠️ 不正なランキングデータ: \(doc.documentID)")
                        continue
                    }
                    
                    let ranking = CharacterRanking(
                        characterId: characterId,
                        rank: rank,
                        characterName: characterName,
                        characterImagePath: data["characterImagePath"] as? String,
                        externalLink: data["externalLink"] as? String
                    )
                    
                    rankings.append(ranking)
                    print("[DEBUG] ランキング追加: \(rank)位 \(characterName)")
                }
                
                print("✅ ランキング取得完了: \(rankings.count)件")
                completion(.success(rankings))
            }
    }
    
    // キャラクターランキングデータを保存
    func saveCharacterRanking(_ ranking: CharacterRanking, completion: @escaping (Result<Void, Error>) -> Void) {
        print("🔥 キャラクターランキング保存開始: \(ranking.rank)位 \(ranking.characterName)")
        
        // 既存の同じランクのデータを削除してから新規作成
        db.collection("characterRankings")
            .whereField("rank", isEqualTo: ranking.rank)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ 既存ランキング取得エラー: \(error)")
                    completion(.failure(error))
                    return
                }
                
                let batch = self.db.batch()
                
                // 既存データ削除
                if let documents = snapshot?.documents {
                    for doc in documents {
                        batch.deleteDocument(doc.reference)
                    }
                }
                
                // 新しいランキングデータ追加
                let newRankingRef = self.db.collection("characterRankings").document()
                let rankingData: [String: Any] = [
                    "characterId": ranking.characterId.uuidString,
                    "rank": ranking.rank,
                    "characterName": ranking.characterName,
                    "characterImagePath": ranking.characterImagePath ?? "",
                    "createdAt": Timestamp(date: Date()),
                    "updatedAt": Timestamp(date: Date())
                ]
                
                batch.setData(rankingData, forDocument: newRankingRef)
                
                // バッチ実行
                batch.commit { error in
                    if let error = error {
                        print("❌ ランキング保存エラー: \(error)")
                        completion(.failure(error))
                    } else {
                        print("✅ ランキング保存成功: \(ranking.rank)位 \(ranking.characterName)")
                        completion(.success(()))
                    }
                }
            }
    }
    
    // キャラクターランキングを削除
    func deleteCharacterRanking(rank: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        print("🔥 キャラクターランキング削除開始: \(rank)位")
        
        db.collection("characterRankings")
            .whereField("rank", isEqualTo: rank)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ ランキング削除エラー: \(error)")
                    completion(.failure(error))
                    return
                }
                
                let batch = self.db.batch()
                
                if let documents = snapshot?.documents {
                    for doc in documents {
                        batch.deleteDocument(doc.reference)
                    }
                }
                
                batch.commit { error in
                    if let error = error {
                        print("❌ ランキング削除エラー: \(error)")
                        completion(.failure(error))
                    } else {
                        print("✅ ランキング削除成功: \(rank)位")
                        completion(.success(()))
                    }
                }
            }
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
                        targetVoiceActors: data["targetVoiceActors"] as? [String] ?? [],
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
    func fetchAds(for profile: UserProfile, completion: @escaping (Result<[Advertisement], Error>) -> Void) {
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
    
    // プランを保存（投稿）- ローカル表示のみ（Firebase保存なし）
    func saveVisitPlan(_ plan: VisitPlanModel, completion: @escaping (Result<Void, Error>) -> Void) {
        print("ℹ️ [INFO] プランはローカル表示のみ（Firebase保存なし）")
        // Firebase保存を無効化し、成功レスポンスを返す
        completion(.success(()))
    }
    
    // 公開プランを取得（オールタブ用）
    func fetchPublicPlans(completion: @escaping (Result<[VisitPlanModel], Error>) -> Void) {
        print("🔍 [DEBUG] fetchPublicPlans開始")
        
        // すべての公開プランを取得し、クライアント側でフィルタリング
        db.collection("visitPlans")
            .whereField("isPublic", isEqualTo: true)
            .limit(to: 100)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    print("❌ [DEBUG] fetchPublicPlans失敗: \(error)")
                    completion(.failure(error))
                    return
                }
                
                print("📊 [DEBUG] fetchPublicPlans取得件数: \(snapshot?.documents.count ?? 0)")
                
                var allPlans: [VisitPlanModel] = []
                
                // 公開プランを変換
                snapshot?.documents.forEach { doc in
                    let data = doc.data()
                    print("📋 [DEBUG] プラン: \(data["title"] as? String ?? "nil"), userId: \(data["userId"] as? String ?? "nil"), isPublic: \(data["isPublic"] as? Bool ?? false)")
                    
                    if let plan = VisitPlanModel(dictionary: data) {
                        allPlans.append(plan)
                    }
                }
                
                // 管理者の非公開プランも追加で取得
                self.db.collection("visitPlans")
                    .whereField("userId", isEqualTo: "admin")
                    .whereField("isPublic", isEqualTo: false)
                    .limit(to: 50)
                    .getDocuments { adminSnapshot, adminError in
                        if let adminError = adminError {
                            print("❌ [DEBUG] 管理者非公開プラン取得失敗: \(adminError)")
                        } else {
                            print("📊 [DEBUG] 管理者非公開プラン取得件数: \(adminSnapshot?.documents.count ?? 0)")
                            
                            adminSnapshot?.documents.forEach { doc in
                                let data = doc.data()
                                print("📋 [DEBUG] 管理者非公開プラン: \(data["title"] as? String ?? "nil")")
                                
                                if let plan = VisitPlanModel(dictionary: data) {
                                    allPlans.append(plan)
                                }
                            }
                        }
                        
                        print("📊 [DEBUG] 総プラン数: \(allPlans.count)")
                        
                        // 作成日時でソート
                        let sortedPlans = allPlans.sorted { $0.createdAt > $1.createdAt }
                        self.publicPlans = sortedPlans
                        completion(.success(sortedPlans))
                    }
            }
    }
    
    // ユーザーのプランを取得（オリジナルタブ用）
    func fetchUserPlans(userId: String, completion: @escaping (Result<[VisitPlanModel], Error>) -> Void) {
        print("🔍 [DEBUG] fetchUserPlans開始 - userId: \(userId)")
        db.collection("visitPlans")
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ [DEBUG] fetchUserPlans失敗: \(error)")
                    completion(.failure(error))
                    return
                }
                
                print("🔍 [DEBUG] fetchUserPlans - 取得ドキュメント数: \(snapshot?.documents.count ?? 0)")
                
                let plans: [VisitPlanModel] = snapshot?.documents.compactMap { doc in
                    let data = doc.data()
                    print("🔍 [DEBUG] ドキュメントデータ: id=\(doc.documentID)")
                    print("  - userId: \(data["userId"] as? String ?? "nil")")
                    print("  - title: \(data["title"] as? String ?? "nil")")
                    print("  - isPublic: \(data["isPublic"] as? Bool ?? false)")
                    
                    let plan = VisitPlanModel(dictionary: data)
                    if let planObj = plan {
                        print("  - 変換後プラン: \(planObj.title), isPublic: \(planObj.isPublic)")
                        return planObj
                    } else {
                        print("  - プラン変換失敗")
                        return nil
                    }
                } ?? []
                
                print("🔍 [DEBUG] fetchUserPlans - 変換後プラン数: \(plans.count)")
                self.userPlans = plans
                completion(.success(plans))
            }
    }
    
    // プラン購入を記録
    func recordPlanPurchase(_ purchase: PlanPurchase, completion: @escaping (Result<Void, Error>) -> Void) {
        print("🔥 [FirebaseManager] recordPlanPurchase開始")
        print("  - userId: \(purchase.userId)")
        print("  - planId: \(purchase.planId)")
        print("  - purchasePrice: \(purchase.purchasePrice)")
        
        // 購入記録を保存
        let purchaseRef = db.collection("planPurchases").document(purchase.id)
        purchaseRef.setData(purchase.dictionary) { error in
            if let error = error {
                print("❌ [FirebaseManager] planPurchases保存失敗: \(error)")
                completion(.failure(error))
                return
            }
            
            print("✅ [FirebaseManager] planPurchases保存成功: \(purchase.id)")
            
            // プランの購入者リストを更新
            let planRef = self.db.collection("visitPlans").document(purchase.planId)
            planRef.updateData([
                "purchasedBy": FieldValue.arrayUnion([purchase.userId])
            ]) { error in
                if let error = error {
                    print("❌ [FirebaseManager] visitPlans purchasedBy更新失敗: \(error)")
                    completion(.failure(error))
                } else {
                    print("✅ [FirebaseManager] visitPlans purchasedBy更新成功")
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
        print("🔥 [FirebaseManager] checkPlanPurchased開始")
        print("  - userId: \(userId)")
        print("  - planId: \(planId)")
        
        db.collection("planPurchases")
            .whereField("userId", isEqualTo: userId)
            .whereField("planId", isEqualTo: planId)
            .limit(to: 1)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ [FirebaseManager] checkPlanPurchased失敗: \(error)")
                    completion(.failure(error))
                    return
                }
                
                let documentsCount = snapshot?.documents.count ?? 0
                let isPurchased = documentsCount > 0
                print("✅ [FirebaseManager] checkPlanPurchased結果: \(isPurchased ? "購入済み" : "未購入") (documents: \(documentsCount))")
                
                if isPurchased {
                    print("🔍 [FirebaseManager] 見つかった購入記録:")
                    for doc in snapshot?.documents ?? [] {
                        print("  - documentId: \(doc.documentID)")
                        print("  - data: \(doc.data())")
                    }
                }
                
                completion(.success(isPurchased))
            }
    }
    
    // MARK: - Custom Rankings Functions
    
    // アクティブなカスタムランキングを取得
    func fetchActiveCustomRankings(completion: @escaping (Result<[CustomRanking], Error>) -> Void) {
        print("🔥 [FirebaseManager] fetchActiveCustomRankings開始")
        db.collection("customRankings")
            .whereField("isActive", isEqualTo: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ [FirebaseManager] customRankings取得エラー: \(error)")
                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    print("⚠️ [FirebaseManager] customRankingsドキュメントなし")
                    completion(.success([]))
                    return
                }
                
                print("🔥 [FirebaseManager] アクティブなcustomRankings数: \(documents.count)")
                
                var rankings: [CustomRanking] = []
                let group = DispatchGroup()
                
                for doc in documents {
                    group.enter()
                    let data = doc.data()
                    print("🔥 [FirebaseManager] 処理中のランキング: \(doc.documentID)")
                    
                    guard let title = data["title"] as? String,
                          let displayProbability = data["displayProbability"] as? Double,
                          let isActive = data["isActive"] as? Bool,
                          let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
                          let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() else {
                        print("⚠️ [FirebaseManager] 必須フィールドが不足: \(doc.documentID)")
                        group.leave()
                        continue
                    }
                    
                    let imageURL = data["imageURL"] as? String
                    
                    print("🔥 [FirebaseManager] ランキング情報: \(title), 確率: \(displayProbability)")
                    
                    // このランキングのアイテムを取得
                    self.fetchCustomRankingItems(rankingId: doc.documentID) { result in
                        switch result {
                        case .success(let items):
                            print("🔥 [FirebaseManager] アイテム取得成功: \(items.count)件")
                            let ranking = CustomRanking(
                                id: doc.documentID,
                                title: title,
                                displayProbability: displayProbability,
                                isActive: isActive,
                                createdAt: createdAt,
                                updatedAt: updatedAt,
                                imageURL: imageURL,
                                items: items
                            )
                            rankings.append(ranking)
                        case .failure(let error):
                            print("❌ [FirebaseManager] ランキングアイテム取得エラー: \(error)")
                        }
                        group.leave()
                    }
                }
                
                group.notify(queue: .main) {
                    print("🔥 [FirebaseManager] 全ランキング取得完了: \(rankings.count)件")
                    completion(.success(rankings))
                }
            }
    }
    
    // カスタムランキングのアイテムを取得
    private func fetchCustomRankingItems(rankingId: String, completion: @escaping (Result<[CustomRankingItem], Error>) -> Void) {
        print("🔥 [FirebaseManager] fetchCustomRankingItems開始: rankingId=\(rankingId)")
        db.collection("customRankings").document(rankingId).collection("items")
            .order(by: "rank")
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ [FirebaseManager] items取得エラー: \(error)")
                    completion(.failure(error))
                    return
                }
                
                print("🔥 [FirebaseManager] items数: \(snapshot?.documents.count ?? 0)")
                let items = snapshot?.documents.compactMap { doc -> CustomRankingItem? in
                    let data = doc.data()
                    
                    guard let rank = data["rank"] as? Int,
                          let characterName = data["characterName"] as? String else {
                        return nil
                    }
                    
                    let characterImageURL = data["characterImageURL"] as? String
                    let customImageURL = data["customImageURL"] as? String
                    let externalLink = data["externalLink"] as? String
                    let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                    
                    return CustomRankingItem(
                        id: doc.documentID,
                        rank: rank,
                        characterName: characterName,
                        characterImageURL: characterImageURL,
                        customImageURL: customImageURL,
                        externalLink: externalLink,
                        createdAt: createdAt
                    )
                } ?? []
                
                completion(.success(items))
            }
    }
    
    // MARK: - Points Management Functions
    
    // ユーザーのポイント残高のみを取得
    func fetchUserPoints(userId: String, completion: @escaping (Result<Int, Error>) -> Void) {
        getUserPoints(userId: userId) { result in
            switch result {
            case .success(let pointsModel):
                completion(.success(pointsModel.points))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // ユーザーのポイント情報を取得
    func getUserPoints(userId: String, completion: @escaping (Result<UserPointsModel, Error>) -> Void) {
        print("🔥 [FirebaseManager] getUserPoints開始: userId=\(userId)")
        
        db.collection("userPoints").document(userId).getDocument { snapshot, error in
            if let error = error {
                print("❌ [FirebaseManager] ポイント取得エラー: \(error)")
                completion(.failure(error))
                return
            }
            
            guard let document = snapshot, document.exists,
                  let data = document.data() else {
                print("⚠️ [FirebaseManager] ポイントデータなし、初期値を作成")
                // ポイントデータがない場合は初期値を作成
                let initialPoints = UserPointsModel(
                    userId: userId,
                    points: 0
                )
                completion(.success(initialPoints))
                return
            }
            
            let points = data["points"] as? Int ?? 0
            
            let userPoints = UserPointsModel(
                userId: userId,
                points: points
            )
            
            print("✅ [FirebaseManager] ポイント取得成功: \(points)pt")
            completion(.success(userPoints))
        }
    }
    
    // ユーザーにポイントを追加
    func addPointsToUser(userId: String, points: Int, description: String, completion: @escaping (Result<Void, Error>) -> Void) {
        print("🔥 [FirebaseManager] addPointsToUser開始: userId=\(userId), points=\(points)")
        
        let batch = db.batch()
        
        // ユーザーポイントを更新
        let userPointsRef = db.collection("userPoints").document(userId)
        batch.setData([
            "userId": userId,
            "points": FieldValue.increment(Int64(points)),
            "totalEarned": FieldValue.increment(Int64(points)),
            "lastUpdated": FieldValue.serverTimestamp()
        ], forDocument: userPointsRef, merge: true)
        
        // 取引履歴を追加
        let transactionRef = db.collection("pointTransactions").document()
        let transactionData: [String: Any] = [
            "id": transactionRef.documentID,
            "userId": userId,
            "amount": points,
            "type": "purchase",
            "description": description,
            "createdAt": FieldValue.serverTimestamp()
        ]
        batch.setData(transactionData, forDocument: transactionRef)
        
        // バッチ実行
        batch.commit { error in
            if let error = error {
                print("❌ [FirebaseManager] ポイント追加エラー: \(error)")
                completion(.failure(error))
            } else {
                print("✅ [FirebaseManager] ポイント追加成功: \(points)pt")
                completion(.success(()))
            }
        }
    }
    
    // ユーザーのポイント取引履歴を取得
    func getPointTransactions(userId: String, completion: @escaping (Result<[PointTransactionModel], Error>) -> Void) {
        print("🔥 [FirebaseManager] getPointTransactions開始: userId=\(userId)")
        
        db.collection("pointTransactions")
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .getDocuments { snapshot, error in
                if let error = error {
                    print("❌ [FirebaseManager] 取引履歴取得エラー: \(error)")
                    completion(.failure(error))
                    return
                }
                
                let transactions = snapshot?.documents.compactMap { doc -> PointTransactionModel? in
                    let data = doc.data()
                    
                    guard let id = data["id"] as? String,
                          let userId = data["userId"] as? String,
                          let amount = data["amount"] as? Int,
                          let type = data["type"] as? String,
                          let description = data["description"] as? String,
                          let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() else {
                        return nil
                    }
                    
                    return PointTransactionModel(
                        id: id,
                        userId: userId,
                        amount: amount,
                        type: PointTransactionModel.TransactionType(rawValue: type) ?? .purchase,
                        description: description,
                        createdAt: createdAt
                    )
                } ?? []
                
                print("✅ [FirebaseManager] 取引履歴取得成功: \(transactions.count)件")
                completion(.success(transactions))
            }
    }
    
    // ポイントを使用（減算）
    func usePoints(userId: String, points: Int, reason: String, completion: @escaping (Result<Void, Error>) -> Void) {
        print("🔥 [FirebaseManager] usePoints開始: userId=\(userId), points=\(points)")
        
        // 現在のポイントを確認
        getUserPoints(userId: userId) { result in
            switch result {
            case .success(let userPoints):
                if userPoints.points < points {
                    completion(.failure(NSError(domain: "FirebaseManager", code: 1, userInfo: [NSLocalizedDescriptionKey: "ポイントが不足しています"])))
                    return
                }
                
                let batch = self.db.batch()
                
                // ユーザーポイントを更新
                let userPointsRef = self.db.collection("userPoints").document(userId)
                batch.setData([
                    "userId": userId,
                    "points": FieldValue.increment(Int64(-points)),
                    "totalSpent": FieldValue.increment(Int64(points)),
                    "lastUpdated": FieldValue.serverTimestamp()
                ], forDocument: userPointsRef, merge: true)
                
                // 取引履歴を追加
                let transactionRef = self.db.collection("pointTransactions").document()
                let transactionData: [String: Any] = [
                    "id": transactionRef.documentID,
                    "userId": userId,
                    "amount": -points,
                    "type": "usage",
                    "description": reason,
                    "createdAt": FieldValue.serverTimestamp()
                ]
                batch.setData(transactionData, forDocument: transactionRef)
                
                // バッチ実行
                batch.commit { error in
                    if let error = error {
                        print("❌ [FirebaseManager] ポイント使用エラー: \(error)")
                        completion(.failure(error))
                    } else {
                        print("✅ [FirebaseManager] ポイント使用成功: \(points)pt")
                        completion(.success(()))
                    }
                }
                
            case .failure(let error):
                completion(.failure(error))
            }
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
    var targetVoiceActors: [String]
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