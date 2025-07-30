import Foundation

// MARK: - Emergency Cleanup for Large UserDefaults Data
final class EmergencyCleanup {
    static func performEmergencyCleanup() {
        #if DEBUG
        print("=== Starting Emergency UserDefaults Cleanup ===")
        #endif
        
        let userDefaults = UserDefaults.standard
        let dictionary = userDefaults.dictionaryRepresentation()
        
        var removedCount = 0
        var totalRemovedSize = 0
        
        // Specifically target large data keys but exclude metadata
        let problematicPrefixes = [
            "videos_",
            "anime_videos_",
            "artworks_",
            "anime_artworks_",
            "video_albums_",
            "artwork_albums_"
        ]
        // Note: Removed soundtrack prefixes to preserve metadata
        
        for (key, value) in dictionary {
            // Check if key matches problematic patterns
            let shouldRemove = problematicPrefixes.contains { key.hasPrefix($0) }
            
            if shouldRemove {
                // Estimate size
                var size = 0
                if let data = value as? Data {
                    size = data.count
                } else if let dict = value as? [String: Any],
                          let jsonData = try? JSONSerialization.data(withJSONObject: dict) {
                    size = jsonData.count
                }
                
                // Remove if it's large data but NOT soundtrack metadata
                // Soundtrack metadata keys should be preserved as they are small
                let isSoundtrackMetadata = key.contains("soundtracks_metadata")
                
                if !isSoundtrackMetadata && size > 100_000 {
                    #if DEBUG
                    print("Removing key: \(key) (size: \(formatBytes(size)))")
                    #endif
                    userDefaults.removeObject(forKey: key)
                    removedCount += 1
                    totalRemovedSize += size
                }
            }
        }
        
        // Force synchronization
        userDefaults.synchronize()
        
        #if DEBUG
        print("=== Emergency Cleanup Complete ===")
        print("Removed \(removedCount) keys")
        print("Total size removed: \(formatBytes(totalRemovedSize))")
        #endif
        
        // Clear all caches to free memory
        ImageCache.shared.clearAllCache()
        URLCache.shared.removeAllCachedResponses()
    }
    
    private static func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    // Remove only large soundtrack data from UserDefaults, preserve metadata
    static func removeAllSoundtracksFromUserDefaults() {
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys
        
        let soundtrackKeys = allKeys.filter { 
            ($0.contains("soundtrack") || $0.contains("soundtracks")) &&
            !$0.contains("metadata") // Preserve metadata keys
        }
        
        #if DEBUG
        print("Found \(soundtrackKeys.count) soundtrack data keys to remove (preserving metadata)")
        #endif
        
        for key in soundtrackKeys {
            // Only remove if it's large data
            if let data = userDefaults.data(forKey: key), data.count > 100_000 {
                userDefaults.removeObject(forKey: key)
                #if DEBUG
                print("Removed large soundtrack key: \(key) (size: \(data.count) bytes)")
                #endif
            }
        }
        
        userDefaults.synchronize()
    }
}