import UIKit

// 既存の画像パスを新しい形式に移行するヘルパー
class ImageMigrationHelper {
    
    static let shared = ImageMigrationHelper()
    
    private init() {}
    
    // 画像パスを移行（既存の絶対パスから相対パスへ）
    func migrateImagePath(_ oldPath: String?) -> String? {
        guard let oldPath = oldPath else { return nil }
        
        // すでに相対パスの場合はそのまま返す
        if !oldPath.hasPrefix("/") {
            return oldPath
        }
        
        // ファイル名を抽出
        let fileName = (oldPath as NSString).lastPathComponent
        
        // 新しい相対パス
        let relativePath = "AnirecoImages/\(fileName)"
        
        // ファイルを新しい場所に移動
        if migrateImageFile(from: oldPath, fileName: fileName) {
            return relativePath
        } else {
            // 移行失敗時は元のパスを返す（互換性のため）
            return oldPath
        }
    }
    
    // 画像ファイルを新しいディレクトリに移動
    private func migrateImageFile(from oldPath: String, fileName: String) -> Bool {
        let fileManager = FileManager.default
        
        // Documents ディレクトリを取得
        guard let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return false
        }
        
        // 新しいディレクトリを作成
        let appDirectoryURL = documentsURL.appendingPathComponent("AnirecoImages")
        
        do {
            // ディレクトリが存在しない場合は作成
            if !fileManager.fileExists(atPath: appDirectoryURL.path) {
                try fileManager.createDirectory(at: appDirectoryURL, withIntermediateDirectories: true, attributes: nil)
            }
            
            let newFileURL = appDirectoryURL.appendingPathComponent(fileName)
            
            // 新しい場所にファイルが既に存在する場合は成功とみなす
            if fileManager.fileExists(atPath: newFileURL.path) {
                return true
            }
            
            // 古いパスにファイルが存在する場合は移動
            if fileManager.fileExists(atPath: oldPath) {
                // まずコピーして、成功したら元ファイルを削除
                try fileManager.copyItem(at: URL(fileURLWithPath: oldPath), to: newFileURL)
                try fileManager.removeItem(at: URL(fileURLWithPath: oldPath))
                return true
            } else {
                // 古いパスからファイルを探す（アプリコンテナが変わった場合）
                let oldFileName = (oldPath as NSString).lastPathComponent
                let possibleOldURL = documentsURL.appendingPathComponent(oldFileName)
                
                if fileManager.fileExists(atPath: possibleOldURL.path) {
                    try fileManager.moveItem(at: possibleOldURL, to: newFileURL)
                    return true
                }
            }
            
        } catch {
        }
        
        return false
    }
    
    // キャラクターデータの画像パスを移行
    func migrateCharacterImagePaths() {
        guard let data = UserDefaults.standard.data(forKey: "characters"),
              let characters = try? JSONDecoder().decode([Character].self, from: data) else {
            return
        }
        
        var needsUpdate = false
        let migratedCharacters = characters.map { character -> Character in
            var updatedCharacter = character
            
            // アイコン画像パスの移行
            if let newPath = migrateImagePath(character.imageIdentifier) {
                if newPath != character.imageIdentifier {
                    updatedCharacter.imageIdentifier = newPath
                    needsUpdate = true
                }
            }
            
            // 背景画像パスの移行
            if let newPath = migrateImagePath(character.backgroundImagePath) {
                if newPath != character.backgroundImagePath {
                    updatedCharacter.backgroundImagePath = newPath
                    needsUpdate = true
                }
            }
            
            return updatedCharacter
        }
        
        // 更新が必要な場合のみ保存
        if needsUpdate {
            if let encodedData = try? JSONEncoder().encode(migratedCharacters) {
                UserDefaults.standard.set(encodedData, forKey: "characters")
            }
        }
    }
    
    // アニメデータの画像パスを移行
    func migrateAnimeImagePaths() {
        guard let data = UserDefaults.standard.data(forKey: "animes"),
              let animes = try? JSONDecoder().decode([Anime].self, from: data) else {
            return
        }
        
        var needsUpdate = false
        let migratedAnimes = animes.map { anime -> Anime in
            var updatedAnime = anime
            
            // アイコン画像パスの移行
            if let newPath = migrateImagePath(anime.imageIdentifier) {
                if newPath != anime.imageIdentifier {
                    updatedAnime.imageIdentifier = newPath
                    needsUpdate = true
                }
            }
            
            // 背景画像パスの移行
            if let newPath = migrateImagePath(anime.backgroundImagePath) {
                if newPath != anime.backgroundImagePath {
                    updatedAnime.backgroundImagePath = newPath
                    needsUpdate = true
                }
            }
            
            return updatedAnime
        }
        
        // 更新が必要な場合のみ保存
        if needsUpdate {
            if let encodedData = try? JSONEncoder().encode(migratedAnimes) {
                UserDefaults.standard.set(encodedData, forKey: "animes")
            }
        }
    }
    
    // アートワークデータの画像パスを移行
    func migrateArtworkImagePaths() {
        // キャラクターごとのアートワーク
        migrateCharacterArtworks()
        // アニメごとのアートワーク
        migrateAnimeArtworks()
    }
    
    private func migrateCharacterArtworks() {
        guard let data = UserDefaults.standard.data(forKey: "characters"),
              let characters = try? JSONDecoder().decode([Character].self, from: data) else {
            return
        }
        
        for character in characters {
            let key = "character_artworks_\(character.id.uuidString)"
            guard let artworkData = UserDefaults.standard.data(forKey: key),
                  let artworks = try? JSONDecoder().decode([Artwork].self, from: artworkData) else {
                continue
            }
            
            var needsUpdate = false
            let migratedArtworks = artworks.map { artwork -> Artwork in
                var updatedArtwork = artwork
                if let newPath = migrateImagePath(artwork.imagePath) {
                    if newPath != artwork.imagePath {
                        updatedArtwork.imagePath = newPath
                        needsUpdate = true
                    }
                }
                return updatedArtwork
            }
            
            if needsUpdate {
                if let encodedData = try? JSONEncoder().encode(migratedArtworks) {
                    UserDefaults.standard.set(encodedData, forKey: key)
                }
            }
        }
    }
    
    private func migrateAnimeArtworks() {
        guard let data = UserDefaults.standard.data(forKey: "animes"),
              let animes = try? JSONDecoder().decode([Anime].self, from: data) else {
            return
        }
        
        for anime in animes {
            let key = "artworks_\(anime.id.uuidString)"
            guard let artworkData = UserDefaults.standard.data(forKey: key),
                  let artworks = try? JSONDecoder().decode([Artwork].self, from: artworkData) else {
                continue
            }
            
            var needsUpdate = false
            let migratedArtworks = artworks.map { artwork -> Artwork in
                var updatedArtwork = artwork
                if let newPath = migrateImagePath(artwork.imagePath) {
                    if newPath != artwork.imagePath {
                        updatedArtwork.imagePath = newPath
                        needsUpdate = true
                    }
                }
                return updatedArtwork
            }
            
            if needsUpdate {
                if let encodedData = try? JSONEncoder().encode(migratedArtworks) {
                    UserDefaults.standard.set(encodedData, forKey: key)
                }
            }
        }
    }
    
    // 動画データのパスを移行
    func migrateVideoPathsForAllItems() {
        // キャラクターの動画
        migrateCharacterVideos()
        // アニメの動画
        migrateAnimeVideos()
    }
    
    private func migrateCharacterVideos() {
        guard let data = UserDefaults.standard.data(forKey: "characters"),
              let characters = try? JSONDecoder().decode([Character].self, from: data) else {
            return
        }
        
        for character in characters {
            let key = "videos_\(character.id.uuidString)"
            guard let videoData = UserDefaults.standard.data(forKey: key),
                  let videos = try? JSONDecoder().decode([MemoryVideo].self, from: videoData) else {
                continue
            }
            
            var needsUpdate = false
            let migratedVideos = videos.map { video -> MemoryVideo in
                if let newPath = migrateImagePath(video.videoPath), newPath != video.videoPath {
                    needsUpdate = true
                    // videoPathはletなので、新しいインスタンスを作成
                    return MemoryVideo(
                        id: video.id,
                        characterId: video.characterId,
                        videoPath: newPath,
                        thumbnailData: video.thumbnailData,
                        title: video.title,
                        tags: video.tags,
                        date: video.date,
                        youtubeURL: video.youtubeURL,
                        youtubeThumbnailURL: video.youtubeThumbnailURL
                    )
                }
                return video
            }
            
            if needsUpdate {
                if let encodedData = try? JSONEncoder().encode(migratedVideos) {
                    UserDefaults.standard.set(encodedData, forKey: key)
                }
            }
        }
    }
    
    private func migrateAnimeVideos() {
        guard let data = UserDefaults.standard.data(forKey: "animes"),
              let animes = try? JSONDecoder().decode([Anime].self, from: data) else {
            return
        }
        
        for anime in animes {
            let key = "anime_videos_\(anime.id.uuidString)"
            guard let videoData = UserDefaults.standard.data(forKey: key),
                  let videos = try? JSONDecoder().decode([MemoryVideo].self, from: videoData) else {
                continue
            }
            
            var needsUpdate = false
            let migratedVideos = videos.map { video -> MemoryVideo in
                if let newPath = migrateImagePath(video.videoPath), newPath != video.videoPath {
                    needsUpdate = true
                    // videoPathはletなので、新しいインスタンスを作成
                    return MemoryVideo(
                        id: video.id,
                        characterId: video.characterId,
                        videoPath: newPath,
                        thumbnailData: video.thumbnailData,
                        title: video.title,
                        tags: video.tags,
                        date: video.date,
                        youtubeURL: video.youtubeURL,
                        youtubeThumbnailURL: video.youtubeThumbnailURL
                    )
                }
                return video
            }
            
            if needsUpdate {
                if let encodedData = try? JSONEncoder().encode(migratedVideos) {
                    UserDefaults.standard.set(encodedData, forKey: key)
                }
            }
        }
    }
    
    // すべての画像パスを移行
    func migrateAllImagePaths() {
        migrateCharacterImagePaths()
        migrateAnimeImagePaths()
        migrateArtworkImagePaths()
        migrateVideoPathsForAllItems()
    }
}