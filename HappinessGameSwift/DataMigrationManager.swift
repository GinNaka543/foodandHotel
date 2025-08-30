import Foundation

// Manager to handle migration of large data from UserDefaults to file storage
class DataMigrationManager {
    static let shared = DataMigrationManager()
    
    private init() {}
    
    private let migrationCompleteKey = "DataMigrationCompleted_v3" // Force re-migration to clean up large soundtracks
    
    // Call this on app launch
    func performMigrationIfNeeded() {
        // Check if migration has already been completed
        if UserDefaults.standard.bool(forKey: migrationCompleteKey) {
            return
        }
        
        print("Starting data migration from UserDefaults to file storage...")
        
        // Migrate visit plans
        migrateVisitPlans()
        
        // Migrate soundtracks
        migrateSoundtracks()
        
        // Migrate videos
        migrateVideos()
        
        // Migrate artworks
        migrateArtworks()
        
        // Mark migration as complete
        UserDefaults.standard.set(true, forKey: migrationCompleteKey)
        
        print("Data migration completed successfully")
    }
    
    private func migrateVisitPlans() {
        // Visit機能は削除されました
        print("Visit plans migration skipped - feature removed")
    }
    
    private func migrateSoundtracks() {
        print("Migrating soundtracks...")
        SoundtrackStorage.shared.migrateAllSoundtracks()
    }
    
    private func migrateVideos() {
        print("Migrating videos...")
        VideoStorage.shared.migrateAllVideos()
    }
    
    private func migrateArtworks() {
        print("Migrating artworks...")
        ArtworkStorage.shared.migrateAllArtworks()
    }
    
    // Utility method to check UserDefaults size (for debugging)
    func estimateUserDefaultsSize() -> String {
        let userDefaults = UserDefaults.standard
        let dictionary = userDefaults.dictionaryRepresentation()
        
        var totalSize = 0
        var largeKeys: [(key: String, size: Int)] = []
        
        for (key, value) in dictionary {
            do {
                // Skip non-serializable types
                if JSONSerialization.isValidJSONObject(value) {
                    let data = try JSONSerialization.data(withJSONObject: value, options: [])
                    let size = data.count
                    totalSize += size
                    
                    // Track keys larger than 100KB
                    if size > 100_000 {
                        largeKeys.append((key: key, size: size))
                    }
                } else {
                    // For non-JSON serializable objects, estimate size
                    if let data = value as? Data {
                        let size = data.count
                        totalSize += size
                        if size > 100_000 {
                            largeKeys.append((key: key, size: size))
                        }
                    }
                }
            } catch {
                print("Error serializing key \(key): \(error)")
            }
        }
        
        // Sort by size descending
        largeKeys.sort { $0.size > $1.size }
        
        var report = "UserDefaults Total Size: \(formatBytes(totalSize))\n"
        
        if !largeKeys.isEmpty {
            report += "\nLarge Keys (>100KB):\n"
            for item in largeKeys {
                report += "- \(item.key): \(formatBytes(item.size))\n"
            }
        }
        
        return report
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(bytes))
    }
    
    // Clean up old data after successful migration
    func cleanupOldData() {
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys
        
        // Remove old visit plan data with Base64 images
        let visitPlanKeys = allKeys.filter { $0.hasPrefix("visit_plan_") }
        for key in visitPlanKeys {
            if let planData = userDefaults.dictionary(forKey: key),
               let spotsData = planData["spots"] as? [[String: Any]] {
                // Check if it contains Base64 image data
                for spotData in spotsData {
                    if spotData["imageDataBase64"] != nil {
                        // This is old format, remove it
                        userDefaults.removeObject(forKey: key)
                        print("Removed old visit plan data: \(key)")
                        break
                    }
                }
            }
        }
        
        // Old soundtrack keys are already removed during migration
    }
    
    // Enforce UserDefaults size limit by removing large entries
    func enforceUserDefaultsSizeLimit(maxSizeInBytes: Int = 3_500_000) {
        let userDefaults = UserDefaults.standard
        let dictionary = userDefaults.dictionaryRepresentation()
        
        var keysToRemove: [(key: String, size: Int)] = []
        
        for (key, value) in dictionary {
            do {
                var size = 0
                
                if JSONSerialization.isValidJSONObject(value) {
                    let data = try JSONSerialization.data(withJSONObject: value, options: [])
                    size = data.count
                } else if let data = value as? Data {
                    size = data.count
                }
                
                // Remove any individual key larger than 500KB
                if size > 500_000 {
                    keysToRemove.append((key: key, size: size))
                }
            } catch {
                print("Error checking size for key \(key): \(error)")
                // Remove problematic keys
                keysToRemove.append((key: key, size: 0))
            }
        }
        
        // Sort by size descending and remove the largest entries
        keysToRemove.sort { $0.size > $1.size }
        
        for item in keysToRemove {
            print("Removing large UserDefaults entry: \(item.key) (size: \(formatBytes(item.size)))")
            userDefaults.removeObject(forKey: item.key)
            
            // Trigger migration for specific data types
            if item.key.contains("artworks_") || item.key.contains("artwork_") {
                print("Triggering artwork migration due to large entry removal")
                migrateArtworks()
            } else if item.key.contains("videos_") || item.key.contains("video_") {
                print("Triggering video migration due to large entry removal")
                migrateVideos()
            } else if item.key.contains("visit_plan") || item.key.contains("savedPlans") {
                print("Triggering visit plan migration due to large entry removal")
                migrateVisitPlans()
            }
        }
        
        userDefaults.synchronize()
    }
}