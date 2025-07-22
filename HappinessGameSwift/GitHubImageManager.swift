import Foundation
import UIKit
import FirebaseFirestore
import Combine

class GitHubImageManager: ObservableObject {
    static let shared = GitHubImageManager()
    
    // Firebase参照
    private let db = Firestore.firestore()
    
    // リポジトリ設定キャッシュ
    private var repoSettings: GitHubRepoSettings?
    private var lastSettingsUpdate: Date?
    private let settingsCacheDuration: TimeInterval = 300 // 5分
    
    private init() {
        loadRepositorySettings()
    }
    
    // リポジトリ設定を読み込み
    private func loadRepositorySettings() {
        // キャッシュが有効な場合はスキップ
        if let lastUpdate = lastSettingsUpdate,
           Date().timeIntervalSince(lastUpdate) < settingsCacheDuration,
           repoSettings != nil {
            return
        }
        
        db.collection("githubSettings").document("repositories")
            .getDocument { [weak self] snapshot, error in
                guard let self = self,
                      let data = snapshot?.data() else {
                    print("🖼️ [DEBUG] リポジトリ設定の読み込み失敗: \(error?.localizedDescription ?? "データなし")")
                    return
                }
                
                print("🖼️ [DEBUG] Firestoreデータ取得成功: \(data.keys)")
                
                // 現在のFirestore構造に合わせてデータを取得
                var repoData: [String: Any]?
                if let reposArray = data["repositories"] as? [[String: Any]], !reposArray.isEmpty {
                    // 新しい構造: repositories配列
                    repoData = reposArray.first
                    print("🖼️ [DEBUG] repositories配列から取得")
                } else if let firstRepo = data["0"] as? [String: Any] {
                    // 現在の構造: 直接インデックス
                    repoData = firstRepo
                    print("🖼️ [DEBUG] インデックス0から取得")
                }
                
                guard let repoData = repoData,
                      let repo = GitHubRepository(dictionary: repoData) else {
                    print("🖼️ [DEBUG] リポジトリデータの変換に失敗")
                    return
                }
                
                print("🖼️ [DEBUG] リポジトリ設定読み込み成功: \(repo.owner)/\(repo.name)")
                
                self.repoSettings = GitHubRepoSettings()
                self.repoSettings?.repositories = [repo]
                self.repoSettings?.activeRepoId = data["activeRepoId"] as? String ?? repo.id
                self.lastSettingsUpdate = Date()
            }
    }
    
    // 画像をGitHubにアップロード
    func uploadImage(_ image: UIImage, fileName: String, completion: @escaping (Result<String, Error>) -> Void) {
        print("🖼️ [DEBUG] GitHubImageManager.uploadImage - fileName: \(fileName)")
        uploadImage(image, fileName: fileName, type: "visit-plan", completion: completion)
    }
    
    // キャラクターランキング用の画像アップロード
    func uploadCharacterRankingImage(_ image: UIImage, fileName: String, completion: @escaping (Result<String, Error>) -> Void) {
        uploadImage(image, fileName: fileName, type: "character-ranking", completion: completion)
    }
    
    // 画像をGitHubにアップロード（内部メソッド）
    private func uploadImage(_ image: UIImage, fileName: String, type: String, completion: @escaping (Result<String, Error>) -> Void) {
        print("🖼️ [DEBUG] uploadImage内部処理開始 - fileName: \(fileName), type: \(type)")
        
        // リポジトリ設定を再読み込み
        loadRepositorySettings()
        
        // 利用可能なリポジトリを取得
        guard let repo = repoSettings?.getAvailableRepository() else {
            print("🖼️ [DEBUG] リポジトリ設定なし")
            completion(.failure(NSError(domain: "GitHubImageManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "利用可能なリポジトリがありません"])))  
            return
        }
        
        print("🖼️ [DEBUG] リポジトリ設定取得: \(repo.owner)/\(repo.name)")
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            completion(.failure(NSError(domain: "GitHubImageManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "画像の変換に失敗しました"])))
            return
        }
        
        let base64String = imageData.base64EncodedString()
        let folderPath = type == "character-ranking" ? "character-rankings" : repo.basePath
        let path = "\(folderPath)/\(fileName).jpg"
        
        let url = URL(string: "https://api.github.com/repos/\(repo.owner)/\(repo.name)/contents/\(path)")!
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("Bearer \(repo.token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let messageText = type == "character-ranking" ? "Upload character ranking image" : "Upload visit plan image"
        let body: [String: Any] = [
            "message": "\(messageText): \(fileName)",
            "content": base64String,
            "branch": repo.branch
        ]
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
        } catch {
            completion(.failure(error))
            return
        }
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse else {
                completion(.failure(NSError(domain: "GitHubImageManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])))
                return
            }
            
            if httpResponse.statusCode == 201 || httpResponse.statusCode == 200 {
                // 成功時、画像のURLを返す
                let imageUrl = "https://raw.githubusercontent.com/\(repo.owner)/\(repo.name)/\(repo.branch)/\(path)"
                print("🖼️ [DEBUG] GitHub API成功 - 生成URL: \(imageUrl)")
                
                // アップロード記録を保存
                self.recordImageUpload(repo: repo, fileName: fileName, path: path, size: Int64(imageData.count), type: type)
                
                completion(.success(imageUrl))
            } else if httpResponse.statusCode == 422 {
                // ファイルが既に存在する場合は更新
                self.updateImage(repo: repo, imageData: imageData, path: path, type: type, completion: completion)
            } else {
                completion(.failure(NSError(domain: "GitHubImageManager", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "Upload failed with status: \(httpResponse.statusCode)"])))
            }
        }.resume()
    }
    
    // 既存の画像を更新
    private func updateImage(repo: GitHubRepository, imageData: Data, path: String, type: String = "visit-plan", completion: @escaping (Result<String, Error>) -> Void) {
        // まず現在のファイル情報を取得
        let getUrl = URL(string: "https://api.github.com/repos/\(repo.owner)/\(repo.name)/contents/\(path)")!
        var getRequest = URLRequest(url: getUrl)
        getRequest.setValue("Bearer \(repo.token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: getRequest) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let sha = json["sha"] as? String else {
                completion(.failure(NSError(domain: "GitHubImageManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to get file SHA"])))
                return
            }
            
            // ファイルを更新
            let url = URL(string: "https://api.github.com/repos/\(repo.owner)/\(repo.name)/contents/\(path)")!
            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            request.setValue("Bearer \(repo.token)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let base64String = imageData.base64EncodedString()
            let body: [String: Any] = [
                "message": "Update visit plan image",
                "content": base64String,
                "sha": sha,
                "branch": repo.branch
            ]
            
            do {
                request.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                completion(.failure(error))
                return
            }
            
            URLSession.shared.dataTask(with: request) { _, response, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 || httpResponse.statusCode == 201 else {
                    completion(.failure(NSError(domain: "GitHubImageManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Update failed"])))
                    return
                }
                
                let imageUrl = "https://raw.githubusercontent.com/\(repo.owner)/\(repo.name)/\(repo.branch)/\(path)"
                completion(.success(imageUrl))
            }.resume()
        }.resume()
    }
    
    // 画像アップロード記録を保存
    private func recordImageUpload(repo: GitHubRepository, fileName: String, path: String, size: Int64, type: String = "visit-plan") {
        let record = GitHubImageRecord(
            id: UUID().uuidString,
            fileName: fileName,
            repoId: repo.id,
            path: path,
            size: size,
            uploadedAt: Date(),
            uploadedBy: UserDefaults.standard.string(forKey: "userId") ?? "",
            type: type
        )
        
        // Firebaseに記録を保存
        db.collection("githubImages").document(record.id).setData(record.dictionary)
        
        // リポジトリの使用量を更新
        updateRepositoryUsage(repoId: repo.id, additionalSize: size, incrementCount: 1)
    }
    
    // リポジトリ使用量を更新
    private func updateRepositoryUsage(repoId: String, additionalSize: Int64, incrementCount: Int) {
        let repoRef = db.collection("githubSettings").document("repositories")
        
        db.runTransaction({ (transaction, errorPointer) -> Any? in
            let document: DocumentSnapshot
            do {
                try document = transaction.getDocument(repoRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }
            
            guard var data = document.data(),
                  var reposData = data["repositories"] as? [[String: Any]] else {
                return nil
            }
            
            // 該当リポジトリを更新
            for (index, var repoDict) in reposData.enumerated() {
                if repoDict["id"] as? String == repoId {
                    let currentSize = repoDict["currentSize"] as? Int64 ?? 0
                    let currentCount = repoDict["imageCount"] as? Int ?? 0
                    repoDict["currentSize"] = currentSize + additionalSize
                    repoDict["imageCount"] = currentCount + incrementCount
                    reposData[index] = repoDict
                    break
                }
            }
            
            data["repositories"] = reposData
            transaction.setData(data, forDocument: repoRef)
            return nil
        }) { (object, error) in
            if let error = error {
                print("リポジトリ使用量更新エラー: \(error)")
            }
        }
    }
    
    // 画像を削除
    func deleteImage(fileName: String, completion: @escaping (Result<Void, Error>) -> Void) {
        // まず画像記録を取得
        db.collection("githubImages")
            .whereField("fileName", isEqualTo: fileName)
            .limit(to: 1)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self,
                      let document = snapshot?.documents.first,
                      let repoId = document.data()["repoId"] as? String,
                      let path = document.data()["path"] as? String,
                      let size = document.data()["size"] as? Int64,
                      let repo = self.repoSettings?.repositories.first(where: { $0.id == repoId }) else {
                    completion(.failure(NSError(domain: "GitHubImageManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "画像記録が見つかりません"])))
                    return
                }
                
                // GitHubから削除
                self.deleteFromGitHub(repo: repo, path: path, recordId: document.documentID, size: size, completion: completion)
            }
    }
    
    // GitHubからファイルを削除
    private func deleteFromGitHub(repo: GitHubRepository, path: String, recordId: String, size: Int64, completion: @escaping (Result<Void, Error>) -> Void) {
        // まず現在のファイル情報を取得
        let getUrl = URL(string: "https://api.github.com/repos/\(repo.owner)/\(repo.name)/contents/\(path)")!
        var getRequest = URLRequest(url: getUrl)
        getRequest.setValue("Bearer \(repo.token)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: getRequest) { data, response, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let sha = json["sha"] as? String else {
                completion(.failure(NSError(domain: "GitHubImageManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Failed to get file SHA"])))
                return
            }
            
            // ファイルを削除
            let deleteUrl = URL(string: "https://api.github.com/repos/\(repo.owner)/\(repo.name)/contents/\(path)")!
            var deleteRequest = URLRequest(url: deleteUrl)
            deleteRequest.httpMethod = "DELETE"
            deleteRequest.setValue("Bearer \(repo.token)", forHTTPHeaderField: "Authorization")
            deleteRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body: [String: Any] = [
                "message": "Delete visit plan image",
                "sha": sha,
                "branch": repo.branch
            ]
            
            do {
                deleteRequest.httpBody = try JSONSerialization.data(withJSONObject: body)
            } catch {
                completion(.failure(error))
                return
            }
            
            URLSession.shared.dataTask(with: deleteRequest) { _, response, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 || httpResponse.statusCode == 204 else {
                    completion(.failure(NSError(domain: "GitHubImageManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "Delete failed"])))
                    return
                }
                
                // 削除記録を更新
                self.db.collection("githubImages").document(recordId).delete()
                self.updateRepositoryUsage(repoId: repo.id, additionalSize: -size, incrementCount: -1)
                
                completion(.success(()))
            }.resume()
        }.resume()
    }
    
    // リポジトリ容量をチェック
    func checkRepositoryCapacity(completion: @escaping (Result<[GitHubRepository], Error>) -> Void) {
        loadRepositorySettings()
        
        guard let settings = repoSettings else {
            completion(.failure(NSError(domain: "GitHubImageManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "リポジトリ設定が読み込まれていません"])))
            return
        }
        
        // 各リポジトリの実際のサイズをGitHub APIで確認
        let group = DispatchGroup()
        var updatedRepos: [GitHubRepository] = []
        
        for repo in settings.repositories {
            group.enter()
            
            let url = URL(string: "https://api.github.com/repos/\(repo.owner)/\(repo.name)")!
            var request = URLRequest(url: url)
            request.setValue("Bearer \(repo.token)", forHTTPHeaderField: "Authorization")
            
            URLSession.shared.dataTask(with: request) { data, response, error in
                defer { group.leave() }
                
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let sizeKB = json["size"] as? Int else {
                    updatedRepos.append(repo)
                    return
                }
                
                var updatedRepo = repo
                updatedRepo.currentSize = Int64(sizeKB) * 1024 // KBをバイトに変換
                updatedRepos.append(updatedRepo)
            }.resume()
        }
        
        group.notify(queue: .main) {
            // Firebaseの設定を更新
            self.updateRepositorySettings(repos: updatedRepos)
            completion(.success(updatedRepos))
        }
    }
    
    // リポジトリ設定を更新
    private func updateRepositorySettings(repos: [GitHubRepository]) {
        var reposData: [[String: Any]] = []
        for repo in repos {
            reposData.append(repo.dictionary)
        }
        
        let data: [String: Any] = [
            "repositories": reposData,
            "activeRepoId": repoSettings?.activeRepoId ?? "",
            "lastUpdated": Date().timeIntervalSince1970
        ]
        
        db.collection("githubSettings").document("repositories").setData(data) { error in
            if let error = error {
                print("リポジトリ設定更新エラー: \(error)")
            } else {
                self.repoSettings?.repositories = repos
                self.lastSettingsUpdate = Date()
            }
        }
    }
    
    // 新しいリポジトリを追加
    func addRepository(_ repo: GitHubRepository, completion: @escaping (Result<Void, Error>) -> Void) {
        loadRepositorySettings()
        
        if repoSettings == nil {
            repoSettings = GitHubRepoSettings()
        }
        
        repoSettings?.repositories.append(repo)
        
        // 最初のリポジトリの場合はアクティブに設定
        if repoSettings?.repositories.count == 1 {
            repoSettings?.activeRepoId = repo.id
        }
        
        updateRepositorySettings(repos: repoSettings?.repositories ?? [])
        completion(.success(()))
    }
    
    // リポジトリを切り替え
    func switchActiveRepository(to repoId: String, completion: @escaping (Result<Void, Error>) -> Void) {
        guard let repo = repoSettings?.repositories.first(where: { $0.id == repoId }) else {
            completion(.failure(NSError(domain: "GitHubImageManager", code: 0, userInfo: [NSLocalizedDescriptionKey: "指定されたリポジトリが見つかりません"])))
            return
        }
        
        repoSettings?.activeRepoId = repoId
        
        db.collection("githubSettings").document("repositories").updateData([
            "activeRepoId": repoId
        ]) { error in
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(()))
            }
        }
    }
}