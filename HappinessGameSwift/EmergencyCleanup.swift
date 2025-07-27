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
        
        // Specifically target soundtrack and video keys
        let problematicPrefixes = [
            "anime_soundtracks_",
            "character_soundtracks_",
            "videos_",
            "anime_videos_",
            "artworks_",
            "anime_artworks_",
            "video_albums_",
            "artwork_albums_"
        ]
        
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
                
                // Remove if it's a soundtrack or large data key
                if key.contains("soundtrack") || size > 100_000 {
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
    
    // Remove all soundtracks from UserDefaults
    static func removeAllSoundtracksFromUserDefaults() {
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys
        
        let soundtrackKeys = allKeys.filter { 
            $0.contains("soundtrack") || 
            $0.contains("soundtracks")
        }
        
        #if DEBUG
        print("Found \(soundtrackKeys.count) soundtrack keys to remove")
        #endif
        
        for key in soundtrackKeys {
            userDefaults.removeObject(forKey: key)
            #if DEBUG
            print("Removed soundtrack key: \(key)")
            #endif
        }
        
        userDefaults.synchronize()
    }
}