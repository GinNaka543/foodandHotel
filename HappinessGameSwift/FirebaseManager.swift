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
        
        db.collection("users").document(userId).getDocument { [weak self] snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let document = snapshot, document.exists,
                  let data = document.data(),
                  let storedUsername = data["username"] as? String else {
                completion(.success(false))
                return
            }
            
            // ユーザー名が一致するか確認
            let isValid = storedUsername == username
            
            // ログイン成功時にdeviceIdを更新
            if isValid {
                let deviceId = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
                self?.db.collection("users").document(userId).updateData([
                    "deviceId": deviceId,
                    "lastLoginAt": Timestamp(date: Date())
                ]) { _ in
                    // Update completed
                }
            }
            
            completion(.success(isValid))
        }
    }
    
    // ユーザープロファイルをFirebaseから読み込み
    func loadUserProfile(userId: String, completion: @escaping (Result<UserProfile, Error>) -> Void) {
        
        db.collection("users").document(userId).getDocument { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let document = snapshot, document.exists,
                  let data = document.data() else {
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
            
            completion(.success(profile))
        }
    }
    
    // ユーザープロファイルをFirebaseに保存
    func saveUserProfile(_ profile: UserProfile, completion: @escaping (Result<Void, Error>) -> Void) {
        let userRef = db.collection("users").document(profile.id)
        
        var userData: [String: Any] = [
            "id": profile.id,
            "username": profile.username,
            "createdAt": Timestamp(date: profile.createdAt),
            "updatedAt": Timestamp(date: profile.updatedAt),
            "platform": "iOS",
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            "deviceId": UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        ]
        
        // 誕生日がある場合は追加
        if let birthday = profile.birthday {
            userData["birthday"] = Timestamp(date: birthday)
        }
        
        userRef.setData(userData, merge: true) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                // ユーザーが登録したキャラクターとアニメの保存 - DISABLED
                // self.saveUserContentData_DISABLED(userId: profile.id)
                completion(.success(()))
            }
        }
    }
    
    // ユーザーが登録したキャラクターとアニメデータを保存
    // DISABLED: Privacy policy updated - user content no longer saved to Firebase
    private func saveUserContentData_DISABLED(userId: String) {
        print("🔥 [Firebase] saveUserContentData called for userId: \(userId)")
        
        // キャラクターデータを保存
        if let charactersData = UserDefaultsHelper.shared.getData(forKey: "characters"),
           let characters = try? JSONDecoder().decode([Character].self, from: charactersData) {
            
            print("🔥 [Firebase] Found \(characters.count) characters to save")
            
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
                    "birthday": Timestamp(date: character.birthday),
                    "age": character.age,
                    "favoriteFood": character.favoriteFood,
                    "voiceActor": character.voiceActor,
                    // "cupSize": character.cupSize, // removed
                    "anime": "", // character.anime is not available in current Character struct
                    "createdAt": Timestamp(date: Date()), // character.createdAt is not available
                    "updatedAt": Timestamp(date: Date())  // character.updatedAt is not available
                ]
                
                characterRef.setData(characterData, merge: true) { error in
                    if let error = error {
                        // print("❌ [Firebase] Error saving character: \(error)")
                    } else {
                        // print("✅ [Firebase] Character saved: \(character.name)")
                    }
                }
            }
            
            // Save voice actors to user profile
            if !voiceActors.isEmpty {
                let voiceActorsRef = db.collection("users").document(userId)
                voiceActorsRef.updateData([
                    "favoriteVoiceActors": Array(voiceActors)
                ]) { _ in
                    // Voice actors updated
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
                    
                    voiceActorRef.setData(voiceActorData, merge: true) { _ in
                        // Voice actor data saved
                    }
                }
            }
        } else {
            // print("⚠️ [Firebase] No characters found to save")
        }
        
        // アニメデータを保存
        if let animesData = UserDefaultsHelper.shared.getData(forKey: "animes"),
           let animes = try? JSONDecoder().decode([Anime].self, from: animesData) {
            
            print("🔥 [Firebase] Found \(animes.count) animes to save")
            
            for anime in animes {
                let animeRef = db.collection("userAnimes").document("\(userId)_\(anime.id)")
                let animeData: [String: Any] = [
                    "userId": userId,
                    "animeId": anime.id.uuidString,
                    "title": anime.title,
                    "hashtag": anime.hashtag,
                    "releaseDate": Timestamp(date: anime.releaseDate),
                    "characterIds": anime.characterIds.map { $0.uuidString }, // キャラクターIDリストを保存
                    "rating": anime.rating,
                    "voiceActors": anime.voiceActors,
                    "watchLink": anime.watchLink,
                    "createdAt": Timestamp(date: Date()), // anime.createdAt may not be available
                    "updatedAt": Timestamp(date: Date())  // anime.updatedAt may not be available
                ]
                
                animeRef.setData(animeData, merge: true) { error in
                    if let error = error {
                        // print("❌ [Firebase] Error saving anime: \(error)")
                    } else {
                        // print("✅ [Firebase] Anime saved: \(anime.title)")
                    }
                }
            }
        } else {
            // print("⚠️ [Firebase] No animes found to save")
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
        
        db.collection("characterRankings")
            .order(by: "rank")
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion(.success([]))
                    return
                }
                
                var rankings: [CharacterRanking] = []
                
                for doc in documents {
                    let data = doc.data()
                    
                    guard let rank = data["rank"] as? Int,
                          let characterName = data["characterName"] as? String,
                          let characterIdString = data["characterId"] as? String,
                          let characterId = UUID(uuidString: characterIdString) else {
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
                }
                
                completion(.success(rankings))
            }
    }
    
    // キャラクターランキングデータを保存
    func saveCharacterRanking(_ ranking: CharacterRanking, completion: @escaping (Result<Void, Error>) -> Void) {
        
        // 既存の同じランクのデータを削除してから新規作成
        db.collection("characterRankings")
            .whereField("rank", isEqualTo: ranking.rank)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
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
                        completion(.failure(error))
                    } else {
                        completion(.success(()))
                    }
                }
            }
    }
    
    // キャラクターランキングを削除
    func deleteCharacterRanking(rank: Int, completion: @escaping (Result<Void, Error>) -> Void) {
        
        db.collection("characterRankings")
            .whereField("rank", isEqualTo: rank)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
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
                        completion(.failure(error))
                    } else {
                        completion(.success(()))
                    }
                }
            }
    }
    
    // 広告を取得（プレースメント指定）
    func fetchAds(for placement: String, completion: @escaping (Result<[Advertisement], Error>) -> Void) {
        
        db.collection("advertisements")
            .whereField("isActive", isEqualTo: true)
            .whereField("placements", arrayContains: placement)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion(.success([]))
                    return
                }
                
                var ads: [Advertisement] = []
                for doc in documents {
                    let data = doc.data()
                    
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
                        continue
                    }
                    
                    ads.append(ad)
                }
                
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
            if error != nil {
                // Error recording impression
            } else {
                // Impression recorded
            }
        }
    }
    
    // 広告クリックを記録
    func recordAdClick(advertisementId: String) {
        guard !advertisementId.isEmpty else { return }
        
        let adRef = db.collection("advertisements").document(advertisementId)
        adRef.updateData([
            "clicks": FieldValue.increment(Int64(1))
        ]) { _ in
            // Click recorded
        }
    }
    
    // MARK: - Visit Plan Functions
    
    // プランを保存（投稿）- ローカル表示のみ（Firebase保存なし）
    func saveVisitPlan(_ plan: VisitPlanModel, completion: @escaping (Result<Void, Error>) -> Void) {
        // Firebase保存を無効化し、成功レスポンスを返す
        completion(.success(()))
    }
    
    // 公開プランを取得（オールタブ用）
    func fetchPublicPlans(completion: @escaping (Result<[VisitPlanModel], Error>) -> Void) {
        
        // すべての公開プランを取得し、クライアント側でフィルタリング
        db.collection("visitPlans")
            .whereField("isPublic", isEqualTo: true)
            .limit(to: 100)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }
                
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                
                var allPlans: [VisitPlanModel] = []
                
                // 公開プランを変換
                snapshot?.documents.forEach { doc in
                    let data = doc.data()
                    
                    if let plan = VisitPlanModel(dictionary: data) {
                        allPlans.append(plan)
                    }
                }
                
                // 管理者の非公開プランも追加で取得
                self.db.collection("visitPlans")
                    .whereField("userId", isEqualTo: "admin")
                    .whereField("isPublic", isEqualTo: false)
                    .limit(to: 50)
                    .getDocuments { adminSnapshot, _ in
                        if adminSnapshot != nil {
                            
                            adminSnapshot?.documents.forEach { doc in
                                let data = doc.data()
                                
                                if let plan = VisitPlanModel(dictionary: data) {
                                    allPlans.append(plan)
                                }
                            }
                        }
                        
                        
                        // 作成日時でソート
                        let sortedPlans = allPlans.sorted { $0.createdAt > $1.createdAt }
                        self.publicPlans = sortedPlans
                        completion(.success(sortedPlans))
                    }
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
                
                
                let plans: [VisitPlanModel] = snapshot?.documents.compactMap { doc in
                    let data = doc.data()
                    
                    let plan = VisitPlanModel(dictionary: data)
                    if let planObj = plan {
                        return planObj
                    } else {
                        return nil
                    }
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
    
    // MARK: - User Data Sync Functions
    
    // ユーザーのキャラクターデータをFirebaseから取得
    // DISABLED: Privacy policy updated - user content no longer stored in Firebase
    private func loadUserCharacters_DISABLED(userId: String, completion: @escaping (Result<[Character], Error>) -> Void) {
        // print("📱 Loading characters for userId: \(userId)")
        
        db.collection("userCharacters")
            .whereField("userId", isEqualTo: userId)
            .getDocuments(completion: { snapshot, error in
                if let error = error {
                    // print("❌ Error loading characters: \(error)")
                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    // print("⚠️ No character documents found")
                    completion(.success([]))
                    return
                }
                
                // print("✅ Found \(documents.count) character documents")
                
                var characters: [Character] = []
                
                for doc in documents {
                    let data = doc.data()
                    
                    guard let characterIdString = data["characterId"] as? String,
                          let characterId = UUID(uuidString: characterIdString),
                          let name = data["name"] as? String,
                          let tag = data["tag"] as? String else {
                        continue
                    }
                    
                    let voiceActor = data["voiceActor"] as? String ?? ""
                    let birthday = (data["birthday"] as? Timestamp)?.dateValue() ?? Date()
                    let age = data["age"] as? String ?? ""
                    let favoriteFood = data["favoriteFood"] as? String ?? ""
                    
                    let character = Character(
                        id: characterId,
                        imageIdentifier: nil,
                        name: name,
                        tag: tag,
                        birthday: birthday,
                        favoriteFood: favoriteFood,
                        age: age,
                        voiceActor: voiceActor,
                        seichi: "",
                        height: ""
                    )
                    
                    characters.append(character)
                }
                
                completion(.success(characters))
            })
    }
    
    // ユーザーのアニメデータをFirebaseから取得
    // DISABLED: Privacy policy updated - user content no longer stored in Firebase
    private func loadUserAnimes_DISABLED(userId: String, completion: @escaping (Result<[Anime], Error>) -> Void) {
        // print("📱 Loading animes for userId: \(userId)")
        
        db.collection("userAnimes")
            .whereField("userId", isEqualTo: userId)
            .getDocuments(completion: { snapshot, error in
                if let error = error {
                    // print("❌ Error loading animes: \(error)")
                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    // print("⚠️ No anime documents found")
                    completion(.success([]))
                    return
                }
                
                // print("✅ Found \(documents.count) anime documents")
                
                var animes: [Anime] = []
                
                for doc in documents {
                    let data = doc.data()
                    
                    guard let animeIdString = data["animeId"] as? String,
                          let animeId = UUID(uuidString: animeIdString),
                          let title = data["title"] as? String,
                          let hashtag = data["hashtag"] as? String else {
                        continue
                    }
                    
                    let releaseDate = (data["releaseDate"] as? Timestamp)?.dateValue() ?? Date()
                    
                    // キャラクターIDリストを読み込む
                    let characterIdStrings = data["characterIds"] as? [String] ?? []
                    let characterIds = characterIdStrings.compactMap { UUID(uuidString: $0) }
                    
                    // その他のフィールドも読み込む
                    let rating = data["rating"] as? Double ?? 0.0
                    let voiceActors = data["voiceActors"] as? [String] ?? []
                    let watchLink = data["watchLink"] as? String ?? ""
                    
                    let anime = Anime(
                        id: animeId,
                        imageIdentifier: nil,
                        backgroundImagePath: nil,
                        title: title,
                        hashtag: hashtag,
                        releaseDate: releaseDate,
                        customFields: nil,
                        watchStatus: .none,
                        watchStatuses: [],
                        order: 0,
                        rating: rating,
                        voiceActors: voiceActors,
                        characters: [],
                        characterIds: characterIds,
                        watchLink: watchLink
                    )
                    
                    animes.append(anime)
                }
                
                completion(.success(animes))
            })
    }
    
    // ユーザーのすべてのコンテンツデータをFirebaseから同期
    // DISABLED: Privacy policy updated - user content no longer stored in Firebase
    private func syncUserContentFromFirebase_DISABLED(userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // Function disabled due to privacy policy changes
        print("ℹ️ User content sync disabled - local data only")
        completion(.success(()))
    }
    
    // ユーザーが購入したプランを取得
    func fetchUserPurchasedPlans(userId: String, completion: @escaping (Result<[String], Error>) -> Void) {
        db.collection("planPurchases")
            .whereField("userId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                let planIds = snapshot?.documents.compactMap { document in
                    document.data()["planId"] as? String
                } ?? []
                
                completion(.success(planIds))
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
                
                let documentsCount = snapshot?.documents.count ?? 0
                let isPurchased = documentsCount > 0
                
                if isPurchased {
                    for _ in snapshot?.documents ?? [] {
                        // Document exists
                    }
                }
                
                completion(.success(isPurchased))
            }
    }
    
    // MARK: - Custom Rankings Functions
    
    // アクティブなカスタムランキングを取得
    func fetchActiveCustomRankings(completion: @escaping (Result<[CustomRanking], Error>) -> Void) {
        db.collection("customRankings")
            .whereField("isActive", isEqualTo: true)
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let documents = snapshot?.documents else {
                    completion(.success([]))
                    return
                }
                
                
                var rankings: [CustomRanking] = []
                let group = DispatchGroup()
                
                for doc in documents {
                    group.enter()
                    let data = doc.data()
                    
                    guard let title = data["title"] as? String,
                          let displayProbability = data["displayProbability"] as? Double,
                          let isActive = data["isActive"] as? Bool,
                          let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
                          let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() else {
                        group.leave()
                        continue
                    }
                    
                    let imageURL = data["imageURL"] as? String
                    
                    
                    // このランキングのアイテムを取得
                    self.fetchCustomRankingItems(rankingId: doc.documentID) { result in
                        switch result {
                        case .success(let items):
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
                        case .failure(_):
                            break
                        }
                        group.leave()
                    }
                }
                
                group.notify(queue: .main) {
                    completion(.success(rankings))
                }
            }
    }
    
    // カスタムランキングのアイテムを取得
    private func fetchCustomRankingItems(rankingId: String, completion: @escaping (Result<[CustomRankingItem], Error>) -> Void) {
        db.collection("customRankings").document(rankingId).collection("items")
            .order(by: "rank")
            .getDocuments { snapshot, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
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
        
        db.collection("userPoints").document(userId).getDocument { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let document = snapshot, document.exists,
                  let data = document.data() else {
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
            
            completion(.success(userPoints))
        }
    }
    
    // ユーザーにポイントを追加
    func addPointsToUser(userId: String, points: Int, description: String, completion: @escaping (Result<Void, Error>) -> Void) {
        
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
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    // ユーザーのポイント取引履歴を取得
    func getPointTransactions(userId: String, completion: @escaping (Result<[PointTransactionModel], Error>) -> Void) {
        
        db.collection("pointTransactions")
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .getDocuments { [weak self] snapshot, error in
                if let error = error {
                    // インデックスエラーの場合は詳細なメッセージを表示
                    let nsError = error as NSError
                    if nsError.domain == "FIRFirestoreErrorDomain" && nsError.code == 9 {
                        // print("⚠️ Firebase Index Required!")
                        // print("⚠️ Please create an index for this query.")
                        // print("⚠️ Collection: pointTransactions")
                        // print("⚠️ Fields: userId (Ascending), createdAt (Descending)")
                        // print("⚠️ Check the console for a direct link to create the index.")
                        // print("🔄 Falling back to basic query without ordering...")
                        
                        // フォールバック: ソートなしでクエリを実行
                        self?.getPointTransactionsFallback(userId: userId, completion: completion)
                        return
                    }
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
                
                completion(.success(transactions))
            }
    }
    
    // フォールバック: インデックスが作成されるまでの代替クエリ
    private func getPointTransactionsFallback(userId: String, completion: @escaping (Result<[PointTransactionModel], Error>) -> Void) {
        // print("🔄 Using fallback query for point transactions...")
        
        db.collection("pointTransactions")
            .whereField("userId", isEqualTo: userId)
            .limit(to: 50)
            .getDocuments { snapshot, error in
                if let error = error {
                    // print("❌ Fallback query also failed: \(error)")
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
                    
                    guard let transactionType = PointTransactionModel.TransactionType(rawValue: type) else {
                        return nil
                    }
                    
                    return PointTransactionModel(id: id, userId: userId, amount: amount, type: transactionType, description: description, createdAt: createdAt)
                } ?? []
                
                // クライアントサイドでソート（インデックスがないため）
                let sortedTransactions = transactions.sorted { $0.createdAt > $1.createdAt }
                // print("✅ Fallback query successful, returned \(sortedTransactions.count) transactions")
                completion(.success(sortedTransactions))
            }
    }
    
    // ポイントを使用（減算）
    func usePoints(userId: String, points: Int, reason: String, completion: @escaping (Result<Void, Error>) -> Void) {
        
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
                        completion(.failure(error))
                    } else {
                        completion(.success(()))
                    }
                }
                
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Purchased Plans Management
    
    // ユーザーの購入済みプランIDリストを取得
    func fetchUserPurchasedPlanIds(userId: String, completion: @escaping (Result<[String], Error>) -> Void) {
        // print("📱 Fetching purchased plan IDs for userId: \(userId)")
        
        db.collection("planPurchases")
            .whereField("userId", isEqualTo: userId)
            .getDocuments { snapshot, error in
                if let error = error {
                    // print("❌ Error fetching purchased plans: \(error)")
                    completion(.failure(error))
                    return
                }
                
                let planIds = snapshot?.documents.compactMap { doc in
                    doc.data()["planId"] as? String
                } ?? []
                
                // print("✅ Found \(planIds.count) purchased plans")
                completion(.success(planIds))
            }
    }
    
    // ユーザーの購入済みプランIDをFirebaseに保存
    func savePurchasedPlanIds(userId: String, planIds: [String], completion: @escaping (Result<Void, Error>) -> Void) {
        print("🔥 Saving \(planIds.count) purchased plan IDs for userId: \(userId)")
        
        let userPurchasesRef = db.collection("userPurchasedPlans").document(userId)
        userPurchasesRef.setData([
            "userId": userId,
            "planIds": planIds,
            "updatedAt": FieldValue.serverTimestamp()
        ], merge: true) { error in
            if let error = error {
                // print("❌ Error saving purchased plan IDs: \(error)")
                completion(.failure(error))
            } else {
                // print("✅ Successfully saved purchased plan IDs")
                completion(.success(()))
            }
        }
    }
    
    // 購入済みプランの詳細データを取得してローカルに保存
    private func fetchAndSavePurchasedPlanDetails(userId: String, planIds: [String], completion: @escaping (Result<Void, Error>) -> Void) {
        guard !planIds.isEmpty else {
            completion(.success(()))
            return
        }
        
        let dispatchGroup = DispatchGroup()
        var fetchedPlans: [VisitPlanModel] = []
        var hasError = false
        
        for planId in planIds {
            dispatchGroup.enter()
            
            db.collection("visitPlans").document(planId).getDocument { snapshot, error in
                defer { dispatchGroup.leave() }
                
                if let error = error {
                    // print("❌ Error fetching plan \(planId): \(error)")
                    hasError = true
                    return
                }
                
                guard let document = snapshot, document.exists,
                      let data = document.data(),
                      let plan = VisitPlanModel(dictionary: data) else {
                    // print("⚠️ Could not parse plan \(planId)")
                    return
                }
                
                fetchedPlans.append(plan)
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            if !fetchedPlans.isEmpty {
                // 既存の保存済みプランを読み込み
                var savedPlans: [VisitPlanData] = []
                if let savedData = UserDefaults.standard.data(forKey: "savedPlans"),
                   let decodedPlans = try? JSONDecoder().decode([VisitPlanData].self, from: savedData) {
                    savedPlans = decodedPlans
                }
                
                // 新しく取得したプランを追加（重複を避ける）
                for plan in fetchedPlans {
                    let visitPlanData = VisitPlanData(
                        id: UUID(uuidString: plan.id) ?? UUID(),
                        animeName: plan.animeName,
                        title: plan.title,
                        duration: plan.duration,
                        spots: plan.spots,
                        thumbnailData: nil,
                        thumbnailUrl: plan.thumbnailUrl,
                        createdDate: plan.createdDate,
                        startTime: plan.startTime,
                        numberOfDays: plan.numberOfDays,
                        isPurchased: true,
                        streamingUrls: plan.streamingUrls
                    )
                    
                    // 既に同じプランが保存されていないかチェック
                    if !savedPlans.contains(where: { $0.id.uuidString == plan.id }) {
                        savedPlans.append(visitPlanData)
                    }
                }
                
                // 更新されたプランリストを保存
                if let encodedData = try? JSONEncoder().encode(savedPlans) {
                    UserDefaults.standard.set(encodedData, forKey: "savedPlans")
                    // print("✅ Saved \(fetchedPlans.count) purchased plans to local storage")
                }
            }
            
            completion(hasError ? .failure(NSError(domain: "FirebaseManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Some plans could not be fetched"])) : .success(()))
        }
    }
    
    // 購入済みプランの同期（ローカルとFirebase）
    func syncPurchasedPlans(userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // ローカルの購入済みプランIDを取得
        let localPlanIds = UserDefaults.standard.stringArray(forKey: "purchasedPlanIds_\(userId)") ?? []
        
        // Firebaseから購入済みプランIDを取得
        fetchUserPurchasedPlanIds(userId: userId) { [weak self] result in
            switch result {
            case .success(let firebasePlanIds):
                // ローカルとFirebaseのプランIDをマージ
                let allPlanIds = Array(Set(localPlanIds + firebasePlanIds))
                
                // マージしたリストをローカルに保存
                UserDefaults.standard.set(allPlanIds, forKey: "purchasedPlanIds_\(userId)")
                
                // 購入済みプランの詳細データを取得してローカルに保存
                self?.fetchAndSavePurchasedPlanDetails(userId: userId, planIds: allPlanIds) { detailsResult in
                    switch detailsResult {
                    case .success:
                        // マージしたリストをFirebaseに保存
                        self?.savePurchasedPlanIds(userId: userId, planIds: allPlanIds) { saveResult in
                            switch saveResult {
                            case .success:
                                // print("✅ Successfully synced purchased plans")
                                completion(.success(()))
                            case .failure(let error):
                                completion(.failure(error))
                            }
                        }
                    case .failure(let error):
                        // print("⚠️ Failed to fetch plan details, but continuing: \(error)")
                        // 詳細データの取得に失敗してもIDの同期は成功として扱う
                        completion(.success(()))
                    }
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    // MARK: - Premium User Management
    
    // プレミアムユーザー情報をFirebaseに保存
    func savePremiumUserStatus(userId: String, isPremium: Bool, purchaseDate: Date, completion: @escaping (Result<Void, Error>) -> Void) {
        let userRef = db.collection("users").document(userId)
        let premiumData: [String: Any] = [
            "isPremiumUser": isPremium,
            "premiumPurchaseDate": Timestamp(date: purchaseDate),
            "premiumUpdatedAt": Timestamp(date: Date()),
            "deviceId": UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        ]
        
        userRef.updateData(premiumData) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
    
    // プレミアムユーザー情報をFirebaseから取得
    func loadPremiumUserStatus(userId: String, completion: @escaping (Result<(isPremium: Bool, purchaseDate: Date?), Error>) -> Void) {
        let userRef = db.collection("users").document(userId)
        
        userRef.getDocument { snapshot, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let document = snapshot, document.exists,
                  let data = document.data() else {
                // ユーザードキュメントが存在しない場合は非プレミアムとして扱う
                completion(.success((isPremium: false, purchaseDate: nil)))
                return
            }
            
            let isPremium = data["isPremiumUser"] as? Bool ?? false
            let purchaseDate = (data["premiumPurchaseDate"] as? Timestamp)?.dateValue()
            
            completion(.success((isPremium: isPremium, purchaseDate: purchaseDate)))
        }
    }
    
    // プレミアム購入情報をApple購入記録として保存
    func savePremiumPurchaseRecord(userId: String, productId: String, transactionId: String?, completion: @escaping (Result<Void, Error>) -> Void) {
        let purchaseRef = db.collection("applePurchases").document("\(userId)_\(productId)_\(Date().timeIntervalSince1970)")
        
        let purchaseData: [String: Any] = [
            "userId": userId,
            "productId": productId,
            "transactionId": transactionId ?? "",
            "purchaseType": "premium",
            "purchaseDate": Timestamp(date: Date()),
            "platform": "iOS",
            "deviceId": UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        ]
        
        purchaseRef.setData(purchaseData) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
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