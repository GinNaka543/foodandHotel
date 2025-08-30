import Foundation

// FirebaseManager - All Firebase functionality removed and replaced with local storage
class FirebaseManager: ObservableObject {
    static let shared = FirebaseManager()
    
    private init() {}
    
    // MARK: - User Management (Local Storage Only)
    
    func checkUserIdAvailability(userId: String, completion: @escaping (Bool) -> Void) {
        // Always return true since we're using local storage
        DispatchQueue.main.async {
            completion(true)
        }
    }
    
    func createUserProfile(_ profile: UserProfile, completion: @escaping (Result<Void, Error>) -> Void) {
        // Save to local storage
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: "userProfile_\(profile.userId)")
            DispatchQueue.main.async {
                completion(.success(()))
            }
        } else {
            DispatchQueue.main.async {
                completion(.failure(NSError(domain: "FirebaseManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to encode user profile"])))
            }
        }
    }
    
    func saveUserProfile(_ profile: UserProfile, completion: @escaping (Result<Void, Error>) -> Void) {
        // Save to local storage
        if let data = try? JSONEncoder().encode(profile) {
            UserDefaults.standard.set(data, forKey: "userProfile_\(profile.userId)")
            DispatchQueue.main.async {
                completion(.success(()))
            }
        } else {
            DispatchQueue.main.async {
                completion(.failure(NSError(domain: "FirebaseManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to encode user profile"])))
            }
        }
    }
    
    func getUserProfile(userId: String, completion: @escaping (Result<UserProfile, Error>) -> Void) {
        // Load from local storage
        if let data = UserDefaults.standard.data(forKey: "userProfile_\(userId)"),
           let profile = try? JSONDecoder().decode(UserProfile.self, from: data) {
            DispatchQueue.main.async {
                completion(.success(profile))
            }
        } else {
            DispatchQueue.main.async {
                completion(.failure(NSError(domain: "FirebaseManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "User profile not found"])))
            }
        }
    }
    
    // MARK: - Points Management (Local Storage Only)
    
    func getUserPoints(userId: String, completion: @escaping (Result<UserPointsModel, Error>) -> Void) {
        let points = UserDefaults.standard.integer(forKey: "userPoints_\(userId)")
        let pointsModel = UserPointsModel(userId: userId, points: points)
        DispatchQueue.main.async {
            completion(.success(pointsModel))
        }
    }
    
    func usePoints(userId: String, points: Int, reason: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let currentPoints = UserDefaults.standard.integer(forKey: "userPoints_\(userId)")
        if currentPoints >= points {
            UserDefaults.standard.set(currentPoints - points, forKey: "userPoints_\(userId)")
            DispatchQueue.main.async {
                completion(.success(()))
            }
        } else {
            DispatchQueue.main.async {
                completion(.failure(NSError(domain: "FirebaseManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Insufficient points"])))
            }
        }
    }
    
    func addPoints(userId: String, points: Int, reason: String, completion: @escaping (Result<Void, Error>) -> Void) {
        let currentPoints = UserDefaults.standard.integer(forKey: "userPoints_\(userId)")
        UserDefaults.standard.set(currentPoints + points, forKey: "userPoints_\(userId)")
        DispatchQueue.main.async {
            completion(.success(()))
        }
    }
    
    // MARK: - Advertisement Tracking (Disabled)
    
    func recordAdClick(advertisementId: String) {
        // Advertisement tracking disabled - Firebase removed
    }
    
    func recordAdImpression(advertisementId: String) {
        // Advertisement tracking disabled - Firebase removed
    }
    
    // MARK: - Other Methods (Disabled/Local Only)
    
    func saveUserContentData_DISABLED(userId: String) {
        // Content saving disabled - Firebase removed
    }
    
    // Add other methods that might be called from the app but don't do anything
    func deleteUser(userId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // Remove local data
        UserDefaults.standard.removeObject(forKey: "userProfile_\(userId)")
        UserDefaults.standard.removeObject(forKey: "userPoints_\(userId)")
        DispatchQueue.main.async {
            completion(.success(()))
        }
    }
    
    func fetchAds(for placement: String, completion: @escaping (Result<[Advertisement], Error>) -> Void) {
        // Advertisement fetching disabled - Firebase removed
        DispatchQueue.main.async {
            completion(.success([]))
        }
    }
    
    func verifyUser(username: String, userId: String, completion: @escaping (Result<Bool, Error>) -> Void) {
        // User verification disabled - Firebase removed (always return success)
        DispatchQueue.main.async {
            completion(.success(true))
        }
    }
    
    func loadPremiumUserStatus(userId: String, completion: @escaping (Result<(Bool, Date?), Error>) -> Void) {
        // Premium status loading disabled - Firebase removed (always return false with no date)
        DispatchQueue.main.async {
            completion(.success((false, nil)))
        }
    }
    
    func savePremiumUserStatus(userId: String, isPremium: Bool, purchaseDate: Date, completion: @escaping (Result<Void, Error>) -> Void) {
        // Premium status saving disabled - Firebase removed
        DispatchQueue.main.async {
            completion(.success(()))
        }
    }
    
    func getPointTransactions(userId: String, completion: @escaping (Result<[PointTransactionModel], Error>) -> Void) {
        // Point transactions disabled - Firebase removed (return empty array)
        DispatchQueue.main.async {
            completion(.success([]))
        }
    }
}

// MARK: - Supporting Models

// Simple UserProfile struct for compatibility
struct UserProfile: Codable {
    let userId: String
    let username: String
    let email: String?
    let createdAt: Date
    let updatedAt: Date
    
    init(userId: String, username: String, email: String? = nil) {
        self.userId = userId
        self.username = username
        self.email = email
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}

// Advertisement struct for compatibility
struct Advertisement: Codable, Identifiable {
    let id: String?
    let title: String
    let description: String
    var imageURL: String
    let linkURL: String
    let priority: Int
    let placements: [String]
    let isActive: Bool
    let createdAt: Date?
    let displayRate: Double
    let targetAnimes: [String]
    let targetCharacters: [String]
    let targetVoiceActors: [String]
    let targetHashtags: [String]
    let impressions: Int
    let clicks: Int
    let expiresAt: Date?
    
    init(id: String? = nil, title: String = "", description: String = "", imageURL: String = "", linkURL: String = "", priority: Int = 5, placements: [String] = [], isActive: Bool = true, displayRate: Double = 100.0, targetAnimes: [String] = [], targetCharacters: [String] = [], targetVoiceActors: [String] = [], targetHashtags: [String] = [], impressions: Int = 0, clicks: Int = 0, createdAt: Date? = nil, expiresAt: Date? = nil) {
        self.id = id ?? UUID().uuidString
        self.title = title
        self.description = description
        self.imageURL = imageURL
        self.linkURL = linkURL
        self.priority = priority
        self.placements = placements
        self.isActive = isActive
        self.createdAt = createdAt ?? Date()
        self.displayRate = displayRate
        self.targetAnimes = targetAnimes
        self.targetCharacters = targetCharacters
        self.targetVoiceActors = targetVoiceActors
        self.targetHashtags = targetHashtags
        self.impressions = impressions
        self.clicks = clicks
        self.expiresAt = expiresAt
    }
}