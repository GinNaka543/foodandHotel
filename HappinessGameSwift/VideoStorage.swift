import Foundation

// Helper class to manage video storage
// Stores video metadata in UserDefaults and thumbnail data in files
class VideoStorage {
    static let shared = VideoStorage()
    
    private init() {}
    
    // MARK: - Directory Management
    
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    private var videoThumbnailsDirectory: URL {
        documentsDirectory.appendingPathComponent("VideoThumbnails")
    }
    
    private func ensureDirectoryExists() {
        try? FileManager.default.createDirectory(at: videoThumbnailsDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - File Management
    
    private func thumbnailURL(for videoId: String) -> URL {
        videoThumbnailsDirectory.appendingPathComponent("\(videoId)_thumbnail.jpg")
    }
    
    // MARK: - Video Metadata for Storage
    
    struct VideoMetadata: Codable {
        let id: UUID
        let characterId: UUID
        let videoPath: String
        var hasThumbnail: Bool
        var title: String
        var tags: [String]
        let date: Date
        var youtubeURL: String?
        var youtubeThumbnailURL: String?
        var viewCount: Int?
    }
    
    // MARK: - Save and Load Functions
    
    func saveVideos(for characterId: String, videos: [MemoryVideo]) {
        ensureDirectoryExists()
        
        var metadataArray: [VideoMetadata] = []
        
        for video in videos {
            // Save thumbnail if present
            if let thumbnailData = video.thumbnailData {
                let thumbnailURL = self.thumbnailURL(for: video.id.uuidString)
                try? thumbnailData.write(to: thumbnailURL)
            }
            
            // Create metadata
            let metadata = VideoMetadata(
                id: video.id,
                characterId: video.characterId,
                videoPath: video.videoPath,
                hasThumbnail: video.thumbnailData != nil,
                title: video.title,
                tags: video.tags,
                date: video.date,
                youtubeURL: video.youtubeURL,
                youtubeThumbnailURL: video.youtubeThumbnailURL,
                viewCount: video.viewCount
            )
            
            metadataArray.append(metadata)
        }
        
        // Save metadata to UserDefaults
        let key = "videos_metadata_\(characterId)"
        if let data = try? JSONEncoder().encode(metadataArray) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    func loadVideos(for characterId: String) -> [MemoryVideo] {
        // First try new storage method
        let metadataKey = "videos_metadata_\(characterId)"
        if let data = UserDefaults.standard.data(forKey: metadataKey),
           let metadataArray = try? JSONDecoder().decode([VideoMetadata].self, from: data) {
            
            return metadataArray.map { metadata in
                var thumbnailData: Data? = nil
                if metadata.hasThumbnail {
                    let thumbnailURL = self.thumbnailURL(for: metadata.id.uuidString)
                    thumbnailData = try? Data(contentsOf: thumbnailURL)
                }
                
                return MemoryVideo(
                    id: metadata.id,
                    characterId: metadata.characterId,
                    videoPath: metadata.videoPath,
                    thumbnailData: thumbnailData,
                    title: metadata.title,
                    tags: metadata.tags,
                    date: metadata.date,
                    youtubeURL: metadata.youtubeURL,
                    youtubeThumbnailURL: metadata.youtubeThumbnailURL,
                    viewCount: metadata.viewCount
                )
            }
        }
        
        // Fallback to old method for migration
        let oldKey = "videos_\(characterId)"
        if let data = UserDefaults.standard.data(forKey: oldKey),
           let videos = try? JSONDecoder().decode([MemoryVideo].self, from: data) {
            // Migrate to new storage
            saveVideos(for: characterId, videos: videos)
            // Remove old data
            UserDefaults.standard.removeObject(forKey: oldKey)
            return videos
        }
        
        return []
    }
    
    func deleteVideo(videoId: String) {
        let thumbnailURL = self.thumbnailURL(for: videoId)
        try? FileManager.default.removeItem(at: thumbnailURL)
    }
    
    // MARK: - Anime Videos
    
    func saveAnimeVideos(for animeId: String, videos: [MemoryVideo]) {
        ensureDirectoryExists()
        
        var metadataArray: [VideoMetadata] = []
        
        for video in videos {
            // Save thumbnail if present
            if let thumbnailData = video.thumbnailData {
                let thumbnailURL = self.thumbnailURL(for: video.id.uuidString)
                try? thumbnailData.write(to: thumbnailURL)
            }
            
            // Create metadata
            let metadata = VideoMetadata(
                id: video.id,
                characterId: video.characterId,
                videoPath: video.videoPath,
                hasThumbnail: video.thumbnailData != nil,
                title: video.title,
                tags: video.tags,
                date: video.date,
                youtubeURL: video.youtubeURL,
                youtubeThumbnailURL: video.youtubeThumbnailURL,
                viewCount: video.viewCount
            )
            
            metadataArray.append(metadata)
        }
        
        // Save metadata to UserDefaults
        let key = "anime_videos_metadata_\(animeId)"
        if let data = try? JSONEncoder().encode(metadataArray) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    func loadAnimeVideos(for animeId: String) -> [MemoryVideo] {
        // First try new storage method
        let metadataKey = "anime_videos_metadata_\(animeId)"
        if let data = UserDefaults.standard.data(forKey: metadataKey),
           let metadataArray = try? JSONDecoder().decode([VideoMetadata].self, from: data) {
            
            return metadataArray.map { metadata in
                var thumbnailData: Data? = nil
                if metadata.hasThumbnail {
                    let thumbnailURL = self.thumbnailURL(for: metadata.id.uuidString)
                    thumbnailData = try? Data(contentsOf: thumbnailURL)
                }
                
                return MemoryVideo(
                    id: metadata.id,
                    characterId: metadata.characterId,
                    videoPath: metadata.videoPath,
                    thumbnailData: thumbnailData,
                    title: metadata.title,
                    tags: metadata.tags,
                    date: metadata.date,
                    youtubeURL: metadata.youtubeURL,
                    youtubeThumbnailURL: metadata.youtubeThumbnailURL,
                    viewCount: metadata.viewCount
                )
            }
        }
        
        // Fallback to old method for migration
        let oldKey = "anime_videos_\(animeId)"
        if let data = UserDefaults.standard.data(forKey: oldKey),
           let videos = try? JSONDecoder().decode([MemoryVideo].self, from: data) {
            // Migrate to new storage
            saveAnimeVideos(for: animeId, videos: videos)
            // Remove old data
            UserDefaults.standard.removeObject(forKey: oldKey)
            return videos
        }
        
        return []
    }
    
    // MARK: - Migration
    
    func migrateAllVideos() {
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys
        
        // Migrate character videos
        let characterVideoKeys = allKeys.filter { $0.hasPrefix("videos_") && !$0.contains("metadata") && !$0.contains("anime") }
        for key in characterVideoKeys {
            let characterId = key.replacingOccurrences(of: "videos_", with: "")
            _ = loadVideos(for: characterId) // This will trigger migration
        }
        
        // Migrate anime videos
        let animeVideoKeys = allKeys.filter { $0.hasPrefix("anime_videos_") && !$0.contains("metadata") }
        for key in animeVideoKeys {
            let animeId = key.replacingOccurrences(of: "anime_videos_", with: "")
            _ = loadAnimeVideos(for: animeId) // This will trigger migration
        }
    }
}