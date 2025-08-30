import Foundation
import UIKit
// Firebase removed - import FirebaseFirestore
import Combine

// GitHubImageManager - Firebase functionality disabled
class GitHubImageManager: ObservableObject {
    static let shared = GitHubImageManager()
    
    // Firebase removed - private let db = Firestore.firestore()
    
    // リポジトリ設定キャッシュ
    private var repoSettings: GitHubRepoSettings?
    private var lastSettingsUpdate: Date?
    private let settingsCacheDuration: TimeInterval = 300 // 5分
    
    private init() {
        // Firebase disabled - loadRepositorySettings()
    }
    
    // All Firebase-related methods disabled - returning failure/empty results
    
    func uploadImageWithMaintainedOrder(uiImage: UIImage, type: GitHubImageType, completion: @escaping (Result<String, Error>) -> Void) {
        completion(.failure(NSError(domain: "GitHubImageManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Firebase functionality disabled"])))
    }
    
    func loadOrUpdateImage(uiImage: UIImage, type: GitHubImageType, completion: @escaping (Result<String, Error>) -> Void) {
        completion(.failure(NSError(domain: "GitHubImageManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Firebase functionality disabled"])))
    }
    
    func deleteImageFromGitHubAndFirebase(recordId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        completion(.failure(NSError(domain: "GitHubImageManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Firebase functionality disabled"])))
    }
    
    func getAvailableRepositoryURL(completion: @escaping (Result<String, Error>) -> Void) {
        completion(.failure(NSError(domain: "GitHubImageManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Firebase functionality disabled"])))
    }
    
    private func saveToFirebase(_ record: GitHubImageRecord) {
        // Firebase functionality disabled
    }
    
    private func loadRepositorySettings() {
        // Firebase functionality disabled
    }
    
    private func incrementImageCount(for repo: GitHubRepository) {
        // Firebase functionality disabled
    }
}

// Supporting types that might be referenced elsewhere
enum GitHubImageType {
    case character
    case artwork
    case other
}

// GitHubImageRecord definition moved to GitHubRepoModel.swift

// GitHubRepository, GitHubRepoSettings, and GitHubImageRecord definitions moved to GitHubRepoModel.swift