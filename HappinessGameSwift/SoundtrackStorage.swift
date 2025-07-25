import Foundation
import AVFoundation

// Helper class to manage soundtrack storage
// Stores soundtrack metadata in UserDefaults and audio/thumbnail data in files
class SoundtrackStorage {
    static let shared = SoundtrackStorage()
    
    private init() {}
    
    // MARK: - Directory Management
    
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    private var soundtracksDirectory: URL {
        documentsDirectory.appendingPathComponent("Soundtracks")
    }
    
    private func ensureDirectoryExists() {
        try? FileManager.default.createDirectory(at: soundtracksDirectory, withIntermediateDirectories: true)
    }
    
    // MARK: - File Management
    
    private func audioURL(for soundtrackId: String) -> URL {
        soundtracksDirectory.appendingPathComponent("\(soundtrackId)_audio.m4a")
    }
    
    private func thumbnailURL(for soundtrackId: String) -> URL {
        soundtracksDirectory.appendingPathComponent("\(soundtrackId)_thumbnail.jpg")
    }
    
    // MARK: - Soundtrack Model for Storage
    
    struct SoundtrackMetadata: Codable {
        let id: UUID
        var title: String
        var hasAudioData: Bool
        var hasThumbnailData: Bool
        var duration: TimeInterval?
        var artist: String?
        var createdAt: Date
    }
    
    // MARK: - Save and Load Functions
    
    func saveSoundtrack(_ soundtrack: Soundtrack) throws -> SoundtrackMetadata {
        ensureDirectoryExists()
        
        // Save audio data if present
        if let audioData = soundtrack.audioData {
            let audioURL = self.audioURL(for: soundtrack.id.uuidString)
            try audioData.write(to: audioURL)
        }
        
        // Save thumbnail data if present
        if let thumbnailData = soundtrack.thumbnailData {
            let thumbnailURL = self.thumbnailURL(for: soundtrack.id.uuidString)
            try thumbnailData.write(to: thumbnailURL)
        }
        
        // Create metadata
        let metadata = SoundtrackMetadata(
            id: soundtrack.id,
            title: soundtrack.title,
            hasAudioData: soundtrack.audioData != nil,
            hasThumbnailData: soundtrack.thumbnailData != nil,
            duration: soundtrack.duration,
            artist: soundtrack.artist,
            createdAt: soundtrack.createdAt
        )
        
        return metadata
    }
    
    func loadSoundtrack(from metadata: SoundtrackMetadata) -> Soundtrack {
        var soundtrack = Soundtrack(
            id: metadata.id,
            title: metadata.title,
            audioData: nil,
            thumbnailData: nil,
            duration: metadata.duration,
            artist: metadata.artist,
            createdAt: metadata.createdAt
        )
        
        // Load audio data if it exists
        if metadata.hasAudioData {
            let audioURL = self.audioURL(for: metadata.id.uuidString)
            soundtrack.audioData = try? Data(contentsOf: audioURL)
        }
        
        // Load thumbnail data if it exists
        if metadata.hasThumbnailData {
            let thumbnailURL = self.thumbnailURL(for: metadata.id.uuidString)
            soundtrack.thumbnailData = try? Data(contentsOf: thumbnailURL)
        }
        
        return soundtrack
    }
    
    func deleteSoundtrack(id: String) {
        let audioURL = self.audioURL(for: id)
        let thumbnailURL = self.thumbnailURL(for: id)
        
        try? FileManager.default.removeItem(at: audioURL)
        try? FileManager.default.removeItem(at: thumbnailURL)
    }
    
    // MARK: - Character Soundtracks
    
    func saveSoundtracks(for characterId: String, soundtracks: [Soundtrack]) {
        var metadataArray: [SoundtrackMetadata] = []
        
        for soundtrack in soundtracks {
            if let metadata = try? saveSoundtrack(soundtrack) {
                metadataArray.append(metadata)
            }
        }
        
        // Save metadata to UserDefaults
        if let data = try? JSONEncoder().encode(metadataArray) {
            UserDefaults.standard.set(data, forKey: "character_soundtracks_metadata_\(characterId)")
        }
    }
    
    func loadSoundtracks(for characterId: String) -> [Soundtrack] {
        // First try new storage method
        if let data = UserDefaults.standard.data(forKey: "character_soundtracks_metadata_\(characterId)"),
           let metadataArray = try? JSONDecoder().decode([SoundtrackMetadata].self, from: data) {
            return metadataArray.map { loadSoundtrack(from: $0) }
        }
        
        // Fallback to old method for migration
        if let data = UserDefaults.standard.data(forKey: "character_soundtracks_\(characterId)"),
           let soundtracks = try? JSONDecoder().decode([Soundtrack].self, from: data) {
            // Migrate to new storage
            saveSoundtracks(for: characterId, soundtracks: soundtracks)
            // Remove old data
            UserDefaults.standard.removeObject(forKey: "character_soundtracks_\(characterId)")
            return soundtracks
        }
        
        return []
    }
    
    // MARK: - Anime Soundtracks
    
    func saveAnimeSoundtracks(for animeId: String, soundtracks: [Soundtrack]) {
        var metadataArray: [SoundtrackMetadata] = []
        
        for soundtrack in soundtracks {
            if let metadata = try? saveSoundtrack(soundtrack) {
                metadataArray.append(metadata)
            }
        }
        
        // Save metadata to UserDefaults
        if let data = try? JSONEncoder().encode(metadataArray) {
            UserDefaults.standard.set(data, forKey: "anime_soundtracks_metadata_\(animeId)")
        }
    }
    
    func loadAnimeSoundtracks(for animeId: String) -> [Soundtrack] {
        // First try new storage method
        if let data = UserDefaults.standard.data(forKey: "anime_soundtracks_metadata_\(animeId)"),
           let metadataArray = try? JSONDecoder().decode([SoundtrackMetadata].self, from: data) {
            return metadataArray.map { loadSoundtrack(from: $0) }
        }
        
        // Fallback to old method for migration
        if let data = UserDefaults.standard.data(forKey: "anime_soundtracks_\(animeId)"),
           let soundtracks = try? JSONDecoder().decode([Soundtrack].self, from: data) {
            // Migrate to new storage
            saveAnimeSoundtracks(for: animeId, soundtracks: soundtracks)
            // Remove old data
            UserDefaults.standard.removeObject(forKey: "anime_soundtracks_\(animeId)")
            return soundtracks
        }
        
        return []
    }
    
    // MARK: - Migration
    
    func migrateAllSoundtracks() {
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys
        
        // Migrate character soundtracks
        let characterSoundtrackKeys = allKeys.filter { $0.hasPrefix("character_soundtracks_") && !$0.contains("metadata") }
        for key in characterSoundtrackKeys {
            let characterId = key.replacingOccurrences(of: "character_soundtracks_", with: "")
            _ = loadSoundtracks(for: characterId) // This will trigger migration
        }
        
        // Migrate anime soundtracks
        let animeSoundtrackKeys = allKeys.filter { $0.hasPrefix("anime_soundtracks_") && !$0.contains("metadata") }
        for key in animeSoundtrackKeys {
            let animeId = key.replacingOccurrences(of: "anime_soundtracks_", with: "")
            _ = loadAnimeSoundtracks(for: animeId) // This will trigger migration
        }
    }
}