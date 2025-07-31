import Foundation
import UIKit

// Helper class to manage video storage
// Stores video metadata in UserDefaults and thumbnail data in files
class VideoStorage {
    static let shared = VideoStorage()
    private let sessionId = UUID().uuidString.prefix(8)
    
    private init() {
        print("🌟 [VideoStorage] Initialized with session ID: \(sessionId)")
        
        // Register for app lifecycle notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }
    
    @objc private func applicationWillTerminate() {
        print("⚠️ [VideoStorage] App will terminate - forcing UserDefaults synchronization")
        UserDefaults.standard.synchronize()
    }
    
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
    
    func deleteVideo(videoId: String, videoPath: String? = nil) {
        print("🗑️ [VideoStorage] deleteVideo called - videoId: \(videoId), videoPath: \(videoPath ?? "nil")")
        
        // Delete thumbnail
        let thumbnailURL = self.thumbnailURL(for: videoId)
        if FileManager.default.fileExists(atPath: thumbnailURL.path) {
            do {
                try FileManager.default.removeItem(at: thumbnailURL)
                print("✅ [VideoStorage] Deleted thumbnail: \(thumbnailURL.lastPathComponent)")
            } catch {
                print("❌ [VideoStorage] Failed to delete thumbnail: \(error)")
            }
        } else {
            print("⚠️ [VideoStorage] Thumbnail not found: \(thumbnailURL.lastPathComponent)")
        }
        
        // Delete actual video file if path is provided
        if let videoPath = videoPath {
            // Handle different path formats
            var videoURL: URL
            
            // Check if it's already a full path
            if videoPath.hasPrefix("/") {
                videoURL = URL(fileURLWithPath: videoPath)
            } else {
                // It's a relative path
                videoURL = documentsDirectory.appendingPathComponent(videoPath)
            }
            
            print("🔍 [VideoStorage] Looking for video at: \(videoURL.path)")
            
            if FileManager.default.fileExists(atPath: videoURL.path) {
                do {
                    let fileSize = (try? FileManager.default.attributesOfItem(atPath: videoURL.path)[.size] as? Int64) ?? 0
                    try FileManager.default.removeItem(at: videoURL)
                    print("✅ [VideoStorage] Deleted video file: \(videoPath) (size: \(fileSize / 1024 / 1024) MB)")
                } catch {
                    print("❌ [VideoStorage] Failed to delete video file: \(error)")
                }
            } else {
                print("❌ [VideoStorage] Video file not found at path: \(videoURL.path)")
                
                // Try alternative paths
                let alternativePaths = [
                    documentsDirectory.appendingPathComponent("VideoAlbums/\(videoPath)"),
                    documentsDirectory.appendingPathComponent(URL(fileURLWithPath: videoPath).lastPathComponent)
                ]
                
                for altPath in alternativePaths {
                    if FileManager.default.fileExists(atPath: altPath.path) {
                        print("🔍 [VideoStorage] Found video at alternative path: \(altPath.path)")
                        do {
                            try FileManager.default.removeItem(at: altPath)
                            print("✅ [VideoStorage] Deleted video from alternative path")
                        } catch {
                            print("❌ [VideoStorage] Failed to delete from alternative path: \(error)")
                        }
                        break
                    }
                }
            }
        } else {
            print("⚠️ [VideoStorage] No video path provided for deletion")
        }
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
    
    // MARK: - Album File Management
    
    private var albumsDirectory: URL {
        documentsDirectory.appendingPathComponent("VideoAlbums")
    }
    
    private func albumFileURL(for characterId: String) -> URL {
        albumsDirectory.appendingPathComponent("albums_\(characterId).json")
    }
    
    private func ensureAlbumsDirectoryExists() {
        try? FileManager.default.createDirectory(at: albumsDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - Album Management
    
    func saveAlbums(for characterId: String, albums: [Album]) {
        let key = "video_albums_\(characterId)"
        print("💾 [VideoAlbum] Session \(sessionId) - Attempting to save \(albums.count) albums for character: \(characterId)")
        print("💾 [VideoAlbum] Save key: \(key)")
        
        do {
            let encodedData = try JSONEncoder().encode(albums)
            print("💾 [VideoAlbum] Successfully encoded \(encodedData.count) bytes")
            
            UserDefaults.standard.set(encodedData, forKey: key)
            
            // Force synchronize to ensure data is written immediately
            let syncResult = UserDefaults.standard.synchronize()
            print("💾 [VideoAlbum] Synchronize result: \(syncResult)")
            
            // Additional force save using CFPreferences
            CFPreferencesSetAppValue(key as CFString, encodedData as CFPropertyList, kCFPreferencesCurrentApplication)
            let cfSyncResult = CFPreferencesAppSynchronize(kCFPreferencesCurrentApplication)
            print("💾 [VideoAlbum] CFPreferences sync result: \(cfSyncResult)")
            
            print("💾 [VideoAlbum] Saved \(albums.count) video albums to UserDefaults with key: \(key)")
            
            // Verify the save was successful
            if let verifyData = UserDefaults.standard.data(forKey: key) {
                print("✅ [VideoAlbum] Verified save: data exists with \(verifyData.count) bytes")
                
                // Double-check by trying to decode
                if let verifiedAlbums = try? JSONDecoder().decode([Album].self, from: verifyData) {
                    print("✅ [VideoAlbum] Verified decode: \(verifiedAlbums.count) albums")
                } else {
                    print("⚠️ [VideoAlbum] Warning: Saved data cannot be decoded")
                }
            } else {
                print("⚠️ [VideoAlbum] Warning: Could not verify saved data")
            }
            
            // Log album details
            for album in albums {
                print("  - Saved Album '\(album.tag)' with \(album.videos.count) videos, ID: \(album.id)")
            }
            
            // Also save to file as backup
            ensureAlbumsDirectoryExists()
            let fileURL = albumFileURL(for: characterId)
            do {
                try encodedData.write(to: fileURL)
                print("💾 [VideoAlbum] Also saved to file: \(fileURL.lastPathComponent)")
            } catch {
                print("⚠️ [VideoAlbum] Failed to save to file: \(error)")
            }
        } catch {
            print("❌ [VideoAlbum] Failed to encode albums for character \(characterId)")
            print("❌ [VideoAlbum] Encoding error: \(error)")
        }
    }
    
    func loadAlbums(for characterId: String) -> [Album] {
        let key = "video_albums_\(characterId)"
        print("🔍 [VideoAlbum] Session \(sessionId) - Attempting to load albums with key: \(key)")
        print("🔍 [VideoAlbum] Character ID: \(characterId)")
        
        // Check if UserDefaults is accessible
        let userDefaults = UserDefaults.standard
        print("🔍 [VideoAlbum] Using UserDefaults.standard")
        
        // Also check for legacy keys with app ID prefix
        let allKeys = userDefaults.dictionaryRepresentation().keys
        let possibleKeys = allKeys.filter { $0.contains("album") && $0.contains(characterId) }
        if !possibleKeys.isEmpty {
            print("🔍 [VideoAlbum] Found possible album keys containing characterId:")
            for possibleKey in possibleKeys {
                print("  - \(possibleKey)")
                
                // Try to migrate data from legacy keys
                if possibleKey.contains("anime_artwork_albums") && possibleKey.contains(characterId) {
                    print("🔄 [VideoAlbum] Attempting to migrate from legacy key: \(possibleKey)")
                    if let legacyData = userDefaults.data(forKey: possibleKey) {
                        do {
                            // Try to decode as ArtworkAlbum array first
                            if let artworkAlbums = try? JSONDecoder().decode([ArtworkAlbum].self, from: legacyData) {
                                print("🔄 [VideoAlbum] Migrating \(artworkAlbums.count) artwork albums to video albums")
                                // Convert ArtworkAlbum to Album (video album)
                                // This is a placeholder - actual conversion would depend on the data structure
                            } else {
                                // Try to decode as Album array directly
                                let albums = try JSONDecoder().decode([Album].self, from: legacyData)
                                print("🔄 [VideoAlbum] Successfully migrated \(albums.count) albums")
                                // Save to the correct key
                                saveAlbums(for: characterId, albums: albums)
                                // Remove the legacy key
                                userDefaults.removeObject(forKey: possibleKey)
                                userDefaults.synchronize()
                                return albums
                            }
                        } catch {
                            print("🔄 [VideoAlbum] Migration failed: \(error)")
                        }
                    }
                }
            }
        }
        
        // Try both UserDefaults and CFPreferences
        var data = userDefaults.data(forKey: key)
        
        if data == nil {
            print("🔍 [VideoAlbum] Trying CFPreferences...")
            if let cfData = CFPreferencesCopyAppValue(key as CFString, kCFPreferencesCurrentApplication) as? Data {
                data = cfData
                print("📦 [VideoAlbum] Found data via CFPreferences with \(cfData.count) bytes")
            }
        }
        
        if let data = data {
            print("📦 [VideoAlbum] Found data with \(data.count) bytes")
            
            do {
                let decodedAlbums = try JSONDecoder().decode([Album].self, from: data)
                print("📂 [VideoAlbum] Successfully loaded \(decodedAlbums.count) video albums from UserDefaults")
                
                // Log album details for debugging
                for album in decodedAlbums {
                    print("  - Album '\(album.tag)' with \(album.videos.count) videos")
                    print("    Album ID: \(album.id)")
                }
                
                return decodedAlbums
            } catch {
                print("❌ [VideoAlbum] Failed to decode albums: \(error)")
                print("❌ [VideoAlbum] Error details: \(String(describing: error))")
                
                // Try to decode as old format if exists
                print("🔄 [VideoAlbum] Attempting to check data integrity...")
                if let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) {
                    print("📋 [VideoAlbum] Raw JSON: \(jsonObject)")
                }
                
                return []
            }
        } else {
            print("📂 [VideoAlbum] No albums found in UserDefaults for character \(characterId)")
            
            // Try to load from file as fallback
            let fileURL = albumFileURL(for: characterId)
            if FileManager.default.fileExists(atPath: fileURL.path) {
                print("🔍 [VideoAlbum] Found album file: \(fileURL.lastPathComponent)")
                do {
                    let fileData = try Data(contentsOf: fileURL)
                    let albums = try JSONDecoder().decode([Album].self, from: fileData)
                    print("📂 [VideoAlbum] Successfully loaded \(albums.count) albums from file")
                    
                    // Log album details
                    for album in albums {
                        print("  - Loaded Album '\(album.tag)' with \(album.videos.count) videos from file")
                    }
                    
                    // Restore to UserDefaults
                    saveAlbums(for: characterId, albums: albums)
                    
                    return albums
                } catch {
                    print("❌ [VideoAlbum] Failed to load from file: \(error)")
                }
            } else {
                print("📂 [VideoAlbum] No album file found at: \(fileURL.lastPathComponent)")
            }
            
            // List all keys to debug
            let allKeys = userDefaults.dictionaryRepresentation().keys
            let albumKeys = allKeys.filter { $0.contains("album") }
            print("🔍 [VideoAlbum] All album-related keys in UserDefaults: \(albumKeys)")
            print("🔍 [VideoAlbum] Total keys in UserDefaults: \(allKeys.count)")
            
            // Check if the key exists but has nil value
            if userDefaults.object(forKey: key) == nil {
                print("⚠️ [VideoAlbum] Key '\(key)' does not exist in UserDefaults")
            } else {
                print("⚠️ [VideoAlbum] Key '\(key)' exists but data is nil")
            }
            
            return []
        }
    }
    
    // MARK: - Debug Utilities
    
    func debugPrintAllAlbumKeys() {
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys
        let albumKeys = allKeys.filter { $0.contains("video_albums_") }
        
        print("🔧 [VideoAlbum DEBUG] === UserDefaults Album Keys Debug ===")
        print("🔧 [VideoAlbum DEBUG] Total keys in UserDefaults: \(allKeys.count)")
        print("🔧 [VideoAlbum DEBUG] Album-related keys: \(albumKeys.count)")
        
        for key in albumKeys {
            if let data = userDefaults.data(forKey: key) {
                print("🔧 [VideoAlbum DEBUG] Key: \(key) - Data size: \(data.count) bytes")
                
                // Try to decode to check validity
                if let albums = try? JSONDecoder().decode([Album].self, from: data) {
                    print("🔧 [VideoAlbum DEBUG]   ✅ Valid data: \(albums.count) albums")
                    for album in albums {
                        print("🔧 [VideoAlbum DEBUG]     - Album '\(album.tag)' with \(album.videos.count) videos")
                    }
                } else {
                    print("🔧 [VideoAlbum DEBUG]   ❌ Invalid/corrupted data")
                }
            } else {
                print("🔧 [VideoAlbum DEBUG] Key: \(key) - No data")
            }
        }
        print("🔧 [VideoAlbum DEBUG] =================================")
    }
    
    func testAlbumPersistence(characterId: String) {
        print("🧪 [VideoAlbum TEST] === Testing Album Persistence ===")
        print("🧪 [VideoAlbum TEST] Character ID: \(characterId)")
        
        // Create test album
        let testVideo = MemoryVideo(
            id: UUID(),
            characterId: UUID(uuidString: characterId) ?? UUID(),
            videoPath: "test",
            thumbnailData: nil,
            title: "Test Video",
            tags: ["test"],
            date: Date(),
            youtubeURL: nil,
            youtubeThumbnailURL: nil,
            viewCount: 0
        )
        
        let testAlbum = Album(tag: "Test Album", videos: [testVideo])
        print("🧪 [VideoAlbum TEST] Created test album with ID: \(testAlbum.id)")
        
        // Save it
        saveAlbums(for: characterId, albums: [testAlbum])
        
        // Try to load it back immediately
        let loadedAlbums = loadAlbums(for: characterId)
        print("🧪 [VideoAlbum TEST] Loaded \(loadedAlbums.count) albums immediately after save")
        
        if loadedAlbums.count > 0 {
            print("🧪 [VideoAlbum TEST] ✅ Persistence test PASSED")
        } else {
            print("🧪 [VideoAlbum TEST] ❌ Persistence test FAILED")
            
            // Additional debugging
            let key = "video_albums_\(characterId)"
            if let data = UserDefaults.standard.data(forKey: key) {
                print("🧪 [VideoAlbum TEST] Data exists but decode failed")
                print("🧪 [VideoAlbum TEST] Data size: \(data.count) bytes")
            } else {
                print("🧪 [VideoAlbum TEST] No data found for key: \(key)")
            }
        }
        
        print("🧪 [VideoAlbum TEST] =================================")
    }
    
    // Clean up any corrupted or duplicate album keys
    func cleanupAlbumData() {
        print("🧹 [VideoAlbum CLEANUP] Starting album data cleanup...")
        
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys
        let albumKeys = allKeys.filter { $0.contains("video_albums_") }
        
        var validKeys: Set<String> = []
        var corruptedKeys: [String] = []
        
        for key in albumKeys {
            if let data = userDefaults.data(forKey: key) {
                // Try to decode
                if let _ = try? JSONDecoder().decode([Album].self, from: data) {
                    validKeys.insert(key)
                } else {
                    corruptedKeys.append(key)
                    print("🧹 [VideoAlbum CLEANUP] Found corrupted key: \(key)")
                }
            }
        }
        
        // Remove corrupted keys
        for key in corruptedKeys {
            userDefaults.removeObject(forKey: key)
            print("🧹 [VideoAlbum CLEANUP] Removed corrupted key: \(key)")
        }
        
        if corruptedKeys.count > 0 {
            userDefaults.synchronize()
            print("🧹 [VideoAlbum CLEANUP] Cleanup complete. Removed \(corruptedKeys.count) corrupted keys")
        } else {
            print("🧹 [VideoAlbum CLEANUP] No corrupted keys found")
        }
    }
    
    // MARK: - Debug and Testing
    
    func testAlbumPersistence(for characterId: String) {
        print("🧪 [VideoAlbum] Starting persistence test for character: \(characterId)")
        
        // Use a test-specific ID to avoid conflicts
        let testCharacterId = "TEST_\(characterId)"
        
        // Create a test album
        let testVideo = MemoryVideo(
            id: UUID(),
            characterId: UUID(uuidString: characterId) ?? UUID(),
            videoPath: "test_path",
            thumbnailData: nil,
            title: "Test Video",
            tags: ["test"],
            date: Date(),
            youtubeURL: nil,
            youtubeThumbnailURL: nil,
            viewCount: 0
        )
        
        let testAlbum = Album(tag: "test", videos: [testVideo])
        
        // Save the test album with test ID
        print("🧪 [VideoAlbum] Saving test album with test ID...")
        saveAlbums(for: testCharacterId, albums: [testAlbum])
        
        // Immediately try to load it
        print("🧪 [VideoAlbum] Loading test album...")
        let loadedAlbums = loadAlbums(for: testCharacterId)
        
        if loadedAlbums.count == 1 && loadedAlbums[0].tag == "test" {
            print("✅ [VideoAlbum] Persistence test PASSED")
            print("✅ [VideoAlbum] Test album successfully saved and loaded")
        } else {
            print("❌ [VideoAlbum] Persistence test FAILED")
            print("❌ [VideoAlbum] Expected 1 album with tag 'test', got \(loadedAlbums.count) albums")
        }
        
        // Clean up test data
        print("🧪 [VideoAlbum] Cleaning up test data...")
        UserDefaults.standard.removeObject(forKey: "video_albums_\(testCharacterId)")
        UserDefaults.standard.synchronize()
        
        // Also clean up test file
        let testFileURL = albumFileURL(for: testCharacterId)
        try? FileManager.default.removeItem(at: testFileURL)
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