import SwiftUI

@main
struct HappinessGameSwiftApp: App {
    
    init() {
        cleanupLargeUserDefaultsEntries()
    }
    
    var body: some Scene {
        WindowGroup {
            TitleScreen()
        }
    }
    
    func cleanupLargeUserDefaultsEntries() {
        let userDefaults = UserDefaults.standard
        let keys = userDefaults.dictionaryRepresentation().keys
        for key in keys {
            if key.hasPrefix("artworks_") || key.hasPrefix("videos_") {
                if let data = userDefaults.data(forKey: key), data.count >= 4_000_000 {
                    userDefaults.removeObject(forKey: key)
                    print("[CLEANUP] Removed large UserDefaults entry: \(key), size: \(data.count)")
                }
            }
        }
    }
} 