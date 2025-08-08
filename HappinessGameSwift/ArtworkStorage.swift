import Foundation

// Helper class to manage artwork storage
// Stores artwork metadata in UserDefaults and custom thumbnail data in files
class ArtworkStorage {
    static let shared = ArtworkStorage()
    
    private init() {}
    
    // MARK: - Directory Management
    
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    private var artworkThumbnailsDirectory: URL {
        documentsDirectory.appendingPathComponent("ArtworkThumbnails")
    }
    
    // New directory structure
    private func characterArtworksDirectory(for characterId: String) -> URL {
        documentsDirectory.appendingPathComponent("AnirecoImages/characters/\(characterId)/artworks")
    }
    
    private func animeArtworksDirectory(for animeId: String) -> URL {
        documentsDirectory.appendingPathComponent("AnirecoImages/anime/\(animeId)/artworks")
    }
    
    private func ensureDirectoryExists() {
        try? FileManager.default.createDirectory(at: artworkThumbnailsDirectory, withIntermediateDirectories: true)
    }
    
    private func ensureDirectoryExists(at url: URL) {
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }
    
    // MARK: - File Management
    
    private func thumbnailURL(for artworkId: String) -> URL {
        artworkThumbnailsDirectory.appendingPathComponent("\(artworkId)_thumbnail.jpg")
    }
    
    // MARK: - Artwork Metadata for Storage
    
    struct ArtworkMetadata: Codable {
        let id: UUID
        let characterId: UUID
        var imagePath: String?
        var title: String
        var tags: [String]
        let createdAt: Date
        var pixivURL: String?
        var twitterURL: String?
        var hasCustomThumbnail: Bool
        var viewCount: Int?
    }
    
    // MARK: - Save and Load Functions for Characters
    
    func saveArtworks(for characterId: String, artworks: [Artwork]) {
        ensureDirectoryExists()
        let artworksDir = characterArtworksDirectory(for: characterId)
        ensureDirectoryExists(at: artworksDir)
        
        var metadataArray: [ArtworkMetadata] = []
        
        for artwork in artworks {
            // Save custom thumbnail if present
            if let thumbnailData = artwork.customThumbnailData {
                let thumbnailURL = self.thumbnailURL(for: artwork.id.uuidString)
                try? thumbnailData.write(to: thumbnailURL)
            }
            
            // Create metadata
            let metadata = ArtworkMetadata(
                id: artwork.id,
                characterId: artwork.characterId,
                imagePath: artwork.imagePath,
                title: artwork.title,
                tags: artwork.tags,
                createdAt: artwork.createdAt,
                pixivURL: artwork.pixivURL,
                twitterURL: artwork.twitterURL,
                hasCustomThumbnail: artwork.customThumbnailData != nil,
                viewCount: artwork.viewCount
            )
            
            metadataArray.append(metadata)
        }
        
        // Save metadata to UserDefaults
        let key = "character_artworks_metadata_\(characterId)"
        if let data = try? JSONEncoder().encode(metadataArray) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    func loadArtworks(for characterId: String) -> [Artwork] {
        // First try new storage method
        let metadataKey = "character_artworks_metadata_\(characterId)"
        if let data = UserDefaults.standard.data(forKey: metadataKey),
           let metadataArray = try? JSONDecoder().decode([ArtworkMetadata].self, from: data) {
            
            return metadataArray.map { metadata in
                var customThumbnailData: Data? = nil
                if metadata.hasCustomThumbnail {
                    let thumbnailURL = self.thumbnailURL(for: metadata.id.uuidString)
                    customThumbnailData = try? Data(contentsOf: thumbnailURL)
                }
                
                return Artwork(
                    id: metadata.id,
                    characterId: metadata.characterId,
                    imagePath: metadata.imagePath,
                    title: metadata.title,
                    tags: metadata.tags,
                    createdAt: metadata.createdAt,
                    pixivURL: metadata.pixivURL,
                    twitterURL: metadata.twitterURL,
                    customThumbnailData: customThumbnailData,
                    viewCount: metadata.viewCount
                )
            }
        }
        
        // Fallback to old method for migration
        let oldKey = "character_artworks_\(characterId)"
        if let data = UserDefaults.standard.data(forKey: oldKey),
           let artworks = try? JSONDecoder().decode([Artwork].self, from: data) {
            // Migrate to new storage
            saveArtworks(for: characterId, artworks: artworks)
            // Remove old data
            UserDefaults.standard.removeObject(forKey: oldKey)
            return artworks
        }
        
        // Even older key format
        let veryOldKey = "artworks_\(characterId)"
        if let data = UserDefaults.standard.data(forKey: veryOldKey),
           let artworks = try? JSONDecoder().decode([Artwork].self, from: data) {
            // Migrate to new storage
            saveArtworks(for: characterId, artworks: artworks)
            // Remove old data
            UserDefaults.standard.removeObject(forKey: veryOldKey)
            return artworks
        }
        
        return []
    }
    
    // MARK: - Save and Load Functions for Anime
    
    func saveAnimeArtworks(for animeId: String, artworks: [Artwork]) {
        ensureDirectoryExists()
        let artworksDir = animeArtworksDirectory(for: animeId)
        ensureDirectoryExists(at: artworksDir)
        
        var metadataArray: [ArtworkMetadata] = []
        
        for artwork in artworks {
            // Save custom thumbnail if present
            if let thumbnailData = artwork.customThumbnailData {
                let thumbnailURL = self.thumbnailURL(for: artwork.id.uuidString)
                try? thumbnailData.write(to: thumbnailURL)
            }
            
            // Create metadata
            let metadata = ArtworkMetadata(
                id: artwork.id,
                characterId: artwork.characterId,
                imagePath: artwork.imagePath,
                title: artwork.title,
                tags: artwork.tags,
                createdAt: artwork.createdAt,
                pixivURL: artwork.pixivURL,
                twitterURL: artwork.twitterURL,
                hasCustomThumbnail: artwork.customThumbnailData != nil,
                viewCount: artwork.viewCount
            )
            
            metadataArray.append(metadata)
        }
        
        // Save metadata to UserDefaults
        let key = "anime_artworks_metadata_\(animeId)"
        if let data = try? JSONEncoder().encode(metadataArray) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }
    
    func loadAnimeArtworks(for animeId: String) -> [Artwork] {
        // First try new storage method
        let metadataKey = "anime_artworks_metadata_\(animeId)"
        if let data = UserDefaults.standard.data(forKey: metadataKey),
           let metadataArray = try? JSONDecoder().decode([ArtworkMetadata].self, from: data) {
            
            return metadataArray.map { metadata in
                var customThumbnailData: Data? = nil
                if metadata.hasCustomThumbnail {
                    let thumbnailURL = self.thumbnailURL(for: metadata.id.uuidString)
                    customThumbnailData = try? Data(contentsOf: thumbnailURL)
                }
                
                return Artwork(
                    id: metadata.id,
                    characterId: metadata.characterId,
                    imagePath: metadata.imagePath,
                    title: metadata.title,
                    tags: metadata.tags,
                    createdAt: metadata.createdAt,
                    pixivURL: metadata.pixivURL,
                    twitterURL: metadata.twitterURL,
                    customThumbnailData: customThumbnailData,
                    viewCount: metadata.viewCount
                )
            }
        }
        
        // Fallback to old method for migration
        let oldKey = "anime_artworks_\(animeId)"
        if let data = UserDefaults.standard.data(forKey: oldKey),
           let artworks = try? JSONDecoder().decode([Artwork].self, from: data) {
            // Migrate to new storage
            saveAnimeArtworks(for: animeId, artworks: artworks)
            // Remove old data
            UserDefaults.standard.removeObject(forKey: oldKey)
            return artworks
        }
        
        // Even older key format
        let veryOldKey = "artworks_\(animeId)"
        if let data = UserDefaults.standard.data(forKey: veryOldKey),
           let artworks = try? JSONDecoder().decode([Artwork].self, from: data) {
            // Migrate to new storage
            saveAnimeArtworks(for: animeId, artworks: artworks)
            // Remove old data
            UserDefaults.standard.removeObject(forKey: veryOldKey)
            return artworks
        }
        
        return []
    }
    
    // MARK: - Delete Functions
    
    func deleteArtwork(artworkId: String, imagePath: String? = nil) {
        // Delete custom thumbnail
        let thumbnailURL = self.thumbnailURL(for: artworkId)
        try? FileManager.default.removeItem(at: thumbnailURL)
        
        // Delete actual image file if path is provided
        if let imagePath = imagePath {
            let imageURL = documentsDirectory.appendingPathComponent(imagePath)
            if FileManager.default.fileExists(atPath: imageURL.path) {
                do {
                    try FileManager.default.removeItem(at: imageURL)
                    // print("✅ [ArtworkStorage] Deleted image file: \(imagePath)")
                } catch {
                    // print("❌ [ArtworkStorage] Failed to delete image file: \(error)")
                }
            }
        }
    }
    
    // MARK: - Helper Functions
    
    func createCharacterFolder(for characterId: String) {
        let artworksDir = characterArtworksDirectory(for: characterId)
        ensureDirectoryExists(at: artworksDir)
    }
    
    func createAnimeFolder(for animeId: String) {
        let artworksDir = animeArtworksDirectory(for: animeId)
        ensureDirectoryExists(at: artworksDir)
    }
    
    // MARK: - Migration
    
    func migrateAllArtworks() {
        print("🔄 Starting migration to new folder structure...")
        
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys
        
        // Migrate character artworks
        let characterArtworkKeys = allKeys.filter { 
            ($0.hasPrefix("character_artworks_") || $0.hasPrefix("artworks_")) && 
            !$0.contains("metadata") && 
            !$0.contains("anime") 
        }
        
        print("📁 Creating folders for \(characterArtworkKeys.count) character collections...")
        for key in characterArtworkKeys {
            let characterId: String
            if key.hasPrefix("character_artworks_") {
                characterId = key.replacingOccurrences(of: "character_artworks_", with: "")
            } else {
                characterId = key.replacingOccurrences(of: "artworks_", with: "")
            }
            
            // Just create the folder structure for now
            createCharacterFolder(for: characterId)
        }
        
        // Migrate anime artworks
        let animeArtworkKeys = allKeys.filter { 
            $0.hasPrefix("anime_artworks_") && !$0.contains("metadata")
        }
        
        print("📁 Creating folders for \(animeArtworkKeys.count) anime collections...")
        for key in animeArtworkKeys {
            let animeId = key.replacingOccurrences(of: "anime_artworks_", with: "")
            createAnimeFolder(for: animeId)
        }
        
        print("✅ Folder structure created for organized storage")
    }
}