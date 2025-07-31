import Foundation

// Debug helper to analyze media file references
class MediaCleanupDebugger {
    static let shared = MediaCleanupDebugger()
    
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    func debugMediaFiles() {
        print("\n🔍 ===== MEDIA CLEANUP DEBUGGER =====")
        
        // List all files in documents directory
        print("\n📁 Files in Documents Directory:")
        listFilesInDirectory(documentsDirectory)
        
        // List files in subdirectories
        let subdirectories = ["VideoThumbnails", "ArtworkThumbnails", "AnirecoImages", "Soundtracks", "VisitPlanData", "VideoAlbums"]
        for subdir in subdirectories {
            let subdirURL = documentsDirectory.appendingPathComponent(subdir)
            if FileManager.default.fileExists(atPath: subdirURL.path) {
                print("\n📁 Files in \(subdir):")
                listFilesInDirectory(subdirURL, relativeTo: documentsDirectory)
            }
        }
        
        // Show sample references
        print("\n📌 Sample Referenced Files:")
        showSampleReferences()
        
        // Compare path formats
        print("\n🔄 Path Format Comparison:")
        comparePathFormats()
        
        print("\n=====================================\n")
    }
    
    private func listFilesInDirectory(_ directory: URL, relativeTo baseURL: URL? = nil) {
        do {
            let files = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            for file in files.prefix(10) { // Show first 10 files
                if let base = baseURL {
                    let relativePath = file.path.replacingOccurrences(of: base.path + "/", with: "")
                    print("  - \(relativePath)")
                } else {
                    print("  - \(file.lastPathComponent)")
                }
            }
            if files.count > 10 {
                print("  ... and \(files.count - 10) more files")
            }
        } catch {
            print("  Error listing directory: \(error)")
        }
    }
    
    private func showSampleReferences() {
        // Get sample character
        if let data = UserDefaults.standard.data(forKey: "characters"),
           let characters = try? JSONDecoder().decode([Character].self, from: data),
           let firstCharacter = characters.first {
            
            print("\nSample Character: \(firstCharacter.name)")
            if let imagePath = firstCharacter.imageIdentifier {
                print("  - Icon path in data: '\(imagePath)'")
                
                // Check if it's absolute or relative path
                if imagePath.hasPrefix("/") {
                    print("    ⚠️ This is an absolute path!")
                } else {
                    print("    ✅ This is a relative path")
                }
                
                // Try to find the actual file
                let fullPath = documentsDirectory.appendingPathComponent(imagePath)
                if FileManager.default.fileExists(atPath: fullPath.path) {
                    print("    ✅ File exists at: \(fullPath.path)")
                } else {
                    print("    ❌ File NOT found at: \(fullPath.path)")
                    
                    // Try just the filename
                    let filename = (imagePath as NSString).lastPathComponent
                    let anirecoPath = documentsDirectory.appendingPathComponent("AnirecoImages/\(filename)")
                    if FileManager.default.fileExists(atPath: anirecoPath.path) {
                        print("    ✅ File found in AnirecoImages: \(anirecoPath.path)")
                    }
                }
            }
            
            // Check video thumbnails
            let videos = VideoStorage.shared.loadVideos(for: firstCharacter.id.uuidString)
            if let firstVideo = videos.first {
                print("\nSample Video: \(firstVideo.title)")
                let thumbnailPath = "VideoThumbnails/\(firstVideo.id.uuidString)_thumbnail.jpg"
                print("  - Expected thumbnail path: '\(thumbnailPath)'")
                
                let fullThumbPath = documentsDirectory.appendingPathComponent(thumbnailPath)
                if FileManager.default.fileExists(atPath: fullThumbPath.path) {
                    print("    ✅ Thumbnail exists")
                } else {
                    print("    ❌ Thumbnail NOT found")
                }
            }
        }
    }
    
    private func comparePathFormats() {
        // Get a sample character
        if let data = UserDefaults.standard.data(forKey: "characters"),
           let characters = try? JSONDecoder().decode([Character].self, from: data),
           let firstCharacter = characters.first {
            
            print("\n📊 Analyzing path formats for: \(firstCharacter.name)")
            
            // Check character icon
            if let imagePath = firstCharacter.imageIdentifier {
                analyzePathFormat(imagePath, label: "Character Icon")
            }
            
            // Check videos
            let videos = VideoStorage.shared.loadVideos(for: firstCharacter.id.uuidString)
            if let firstVideo = videos.first {
                analyzePathFormat(firstVideo.videoPath, label: "Video Path")
            }
            
            // Check artworks
            let artworks = ArtworkStorage.shared.loadArtworks(for: firstCharacter.id.uuidString)
            if let firstArtwork = artworks.first, let imagePath = firstArtwork.imagePath {
                analyzePathFormat(imagePath, label: "Artwork Path")
            }
        }
        
        // Check anime
        if let data = UserDefaults.standard.data(forKey: "animeList"),
           let animeList = try? JSONDecoder().decode([Anime].self, from: data),
           let firstAnime = animeList.first {
            
            print("\n📊 Analyzing path formats for anime: \(firstAnime.title)")
            
            if let iconPath = firstAnime.imageIdentifier {
                analyzePathFormat(iconPath, label: "Anime Icon")
            }
            
            if let bgPath = firstAnime.backgroundImagePath {
                analyzePathFormat(bgPath, label: "Anime Background")
            }
        }
    }
    
    private func analyzePathFormat(_ path: String, label: String) {
        print("\n  \(label):")
        print("    Raw path: '\(path)'")
        
        // Check path characteristics
        if path.hasPrefix("/") {
            print("    ⚠️ Absolute path detected")
        }
        
        if path.contains("/Documents/") {
            print("    ⚠️ Contains Documents directory")
        }
        
        if !path.contains("/") {
            print("    📄 Filename only (no directory)")
        }
        
        // Show normalized version
        let normalized = normalizeFilePath(path)
        if normalized != path {
            print("    ✅ Normalized to: '\(normalized)'")
        } else {
            print("    ✅ Already normalized")
        }
        
        // Check if file exists
        let fullPath = documentsDirectory.appendingPathComponent(normalized)
        if FileManager.default.fileExists(atPath: fullPath.path) {
            print("    ✅ File exists at normalized path")
        } else {
            print("    ❌ File NOT found at normalized path")
            // Try other possible locations
            tryAlternateLocations(path)
        }
    }
    
    private func tryAlternateLocations(_ path: String) {
        let filename = (path as NSString).lastPathComponent
        let possibleLocations = [
            "AnirecoImages/\(filename)",
            "VideoAlbums/\(filename)",
            "VideoThumbnails/\(filename)",
            "ArtworkThumbnails/\(filename)",
            filename // Root directory
        ]
        
        for location in possibleLocations {
            let fullPath = documentsDirectory.appendingPathComponent(location)
            if FileManager.default.fileExists(atPath: fullPath.path) {
                print("      ➡️ Found at: '\(location)'")
                break
            }
        }
    }
    
    private func normalizeFilePath(_ path: String) -> String {
        // Same normalization logic as MediaCleanupManager
        var normalizedPath = path
        
        // Remove documents directory path if present
        if let range = normalizedPath.range(of: "/Documents/") {
            normalizedPath = String(normalizedPath[range.upperBound...])
        }
        
        // Remove leading slash
        if normalizedPath.hasPrefix("/") {
            normalizedPath = String(normalizedPath.dropFirst())
        }
        
        // Handle cases where only filename is stored
        if !normalizedPath.contains("/") {
            // Check if this file exists in AnirecoImages directory
            let anirecoPath = "AnirecoImages/\(normalizedPath)"
            let fullAnirecoURL = documentsDirectory.appendingPathComponent(anirecoPath)
            if FileManager.default.fileExists(atPath: fullAnirecoURL.path) {
                return anirecoPath
            }
        }
        
        return normalizedPath
    }
}