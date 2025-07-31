import Foundation
import UIKit

// Manager to clean up orphaned media files
class MediaCleanupManager {
    static let shared = MediaCleanupManager()
    
    private init() {}
    
    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    }
    
    // MARK: - Cleanup Orphaned Files
    
    func cleanupOrphanedMediaFiles() {
        print("🧹 [MediaCleanup] Starting orphaned media files cleanup...")
        
        // TEMPORARILY DISABLED: Auto cleanup causing issues
        // Use manualCleanup() instead
        print("⚠️ [MediaCleanup] Auto cleanup is disabled. Use manual cleanup instead.")
        return
        
        // Run cleanup in all modes, but with safety restrictions
        print("🧹 [MediaCleanup] Running cleanup - limited to safe directories")
        
        // Log current date/time for debugging
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        print("🧹 [MediaCleanup] Cleanup started at: \(dateFormatter.string(from: Date()))")
        
        let startTime = Date()
        var deletedFilesCount = 0
        var freedSpace: Int64 = 0
        
        // Get all video and image files in documents directory
        let allMediaFiles = getAllMediaFiles()
        
        // Get all referenced files from the app's data
        let referencedFiles = getAllReferencedFiles()
        
        // Find orphaned files (files that exist but are not referenced)
        let orphanedFiles = allMediaFiles.subtracting(referencedFiles)
        
        print("📊 [MediaCleanup] Total media files: \(allMediaFiles.count)")
        print("📊 [MediaCleanup] Referenced files: \(referencedFiles.count)")
        
        // Debug: Show some referenced files
        if !referencedFiles.isEmpty {
            print("📌 [MediaCleanup] Sample referenced files:")
            for (index, file) in referencedFiles.prefix(5).enumerated() {
                print("  \(index + 1). \(file)")
            }
        }
        
        print("📊 [MediaCleanup] Orphaned files: \(orphanedFiles.count)")
        
        // Only delete files in safe directories
        let safeDirectoryPrefixes = ["VideoThumbnails/", "ArtworkThumbnails/", "Soundtracks/", "VideoAlbums/"]
        
        // Delete orphaned files (with safety checks)
        for filePath in orphanedFiles {
            // Safety check: Only delete files in safe directories OR root video files
            let isInSafeDirectory = safeDirectoryPrefixes.contains { filePath.hasPrefix($0) }
            let isRootVideoFile = !filePath.contains("/") && filePath.hasSuffix(".mp4")
            
            if !isInSafeDirectory && !isRootVideoFile {
                print("⚠️ [MediaCleanup] Skipping file not in safe directory: \(filePath)")
                continue
            }
            
            if isRootVideoFile {
                print("🎥 [MediaCleanup] Found orphaned video in root: \(filePath)")
            }
            
            let fileURL = documentsDirectory.appendingPathComponent(filePath)
            
            if FileManager.default.fileExists(atPath: fileURL.path) {
                do {
                    // Get file size before deletion
                    let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                    let fileSize = attributes[.size] as? Int64 ?? 0
                    
                    // Additional safety: Log large files but still delete them if orphaned
                    if fileSize > 50 * 1024 * 1024 {
                        print("⚠️ [MediaCleanup] Large file (>50MB) will be deleted: \(filePath) - Size: \(formatBytes(fileSize))")
                    }
                    
                    // Delete the file
                    try FileManager.default.removeItem(at: fileURL)
                    
                    deletedFilesCount += 1
                    freedSpace += fileSize
                    
                    print("🗑️ [MediaCleanup] Deleted orphaned file: \(filePath) (size: \(formatBytes(fileSize)))")
                } catch {
                    print("❌ [MediaCleanup] Failed to delete file \(filePath): \(error)")
                }
            }
        }
        
        let duration = Date().timeIntervalSince(startTime)
        print("✅ [MediaCleanup] Cleanup completed in \(String(format: "%.2f", duration)) seconds")
        print("✅ [MediaCleanup] Deleted \(deletedFilesCount) orphaned files")
        print("✅ [MediaCleanup] Freed \(formatBytes(freedSpace)) of space")
    }
    
    // MARK: - Helper Methods
    
    private func getAllMediaFiles() -> Set<String> {
        var mediaFiles = Set<String>()
        
        do {
            // First, list all files in Documents directory for debugging
            print("🔍 [MediaCleanup] Scanning Documents directory...")
            let documentsContents = try FileManager.default.contentsOfDirectory(
                at: documentsDirectory,
                includingPropertiesForKeys: nil,
                options: [.skipsHiddenFiles]
            )
            
            print("📁 [MediaCleanup] Files/Folders in Documents:")
            var videoFileCount = 0
            for item in documentsContents {
                let isDirectory = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                let fileName = item.lastPathComponent
                
                if !isDirectory && (fileName.hasSuffix(".mp4") || fileName.hasSuffix(".mov")) {
                    videoFileCount += 1
                }
                
                if documentsContents.firstIndex(of: item)! < 20 {
                    print("  - \(fileName)\(isDirectory ? "/" : "")")
                }
            }
            
            if videoFileCount > 0 {
                print("  🎬 Found \(videoFileCount) video files in root directory")
            }
            
            // Also scan root directory for video files (but with extra safety checks during deletion)
            for item in documentsContents {
                let fileName = item.lastPathComponent
                // Check if it's a file (not a directory)
                let isDirectory = (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                if !isDirectory && isMediaFile(fileName) {
                    mediaFiles.insert(fileName)
                    print("  🎥 Found media file in root: \(fileName)")
                }
            }
            
            // IMPORTANT: Only scan specific safe subdirectories, not root directory
            // This prevents accidental deletion of files in root directory
            let safeSubdirectories = ["VideoThumbnails", "ArtworkThumbnails", "Soundtracks", "VideoAlbums"]
            
            for subdirectory in safeSubdirectories {
                let subdirURL = documentsDirectory.appendingPathComponent(subdirectory)
                
                if FileManager.default.fileExists(atPath: subdirURL.path) {
                    let subFileURLs = try FileManager.default.contentsOfDirectory(
                        at: subdirURL,
                        includingPropertiesForKeys: [.isDirectoryKey],
                        options: [.skipsHiddenFiles]
                    )
                    
                    print("📁 [MediaCleanup] Scanning \(subdirectory) directory...")
                    var mediaFileCount = 0
                    var nonMediaFileCount = 0
                    
                    for fileURL in subFileURLs {
                        // Check if it's a file (not a directory)
                        let isDirectory = (try? fileURL.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory ?? false
                        if isDirectory {
                            continue
                        }
                        
                        let fileName = fileURL.lastPathComponent
                        let relativePath = "\(subdirectory)/\(fileName)"
                        if isMediaFile(fileName) {
                            mediaFiles.insert(relativePath)
                            mediaFileCount += 1
                            if mediaFileCount <= 5 {
                                print("  ✅ Added media file: \(relativePath)")
                            }
                        } else {
                            nonMediaFileCount += 1
                            if nonMediaFileCount <= 5 {
                                print("  ⚠️ Skipped non-media file: \(fileName)")
                            }
                        }
                    }
                    
                    print("📊 [MediaCleanup] \(subdirectory): \(mediaFileCount) media files, \(nonMediaFileCount) non-media files")
                } else {
                    print("⚠️ [MediaCleanup] Directory does not exist: \(subdirectory)")
                }
            }
            
            print("📊 [MediaCleanup] Found \(mediaFiles.count) total media files")
        } catch {
            print("❌ [MediaCleanup] Error scanning for media files: \(error)")
        }
        
        return mediaFiles
    }
    
    private func getAllReferencedFiles() -> Set<String> {
        var referencedFiles = Set<String>()
        
        // Get all characters and their media
        let characters = loadAllCharacters()
        for character in characters {
            // Add character icon reference
            if let imagePath = character.imageIdentifier {
                referencedFiles.insert(normalizeFilePath(imagePath))
            }
            
            // Load videos
            let videos = VideoStorage.shared.loadVideos(for: character.id.uuidString)
            for video in videos {
                // Skip YouTube videos (they have empty videoPath)
                if !video.videoPath.isEmpty {
                    let normalizedPath = normalizeFilePath(video.videoPath)
                    referencedFiles.insert(normalizedPath)
                    
                    // Debug log to see video paths
                    print("📹 [MediaCleanup] Referenced video: \(video.videoPath) -> normalized: \(normalizedPath)")
                } else if video.youtubeURL != nil {
                    print("📹 [MediaCleanup] Skipping YouTube video: \(video.title)")
                }
                
                // Add thumbnail reference
                let thumbnailPath = "VideoThumbnails/\(video.id.uuidString)_thumbnail.jpg"
                referencedFiles.insert(thumbnailPath)
                
                // Also check if the video has a YouTube thumbnail URL (which might be cached)
                if let youtubeThumbnailURL = video.youtubeThumbnailURL, !youtubeThumbnailURL.isEmpty {
                    // YouTube thumbnails might be cached with a different naming pattern
                    let youtubeThumbPath = "VideoThumbnails/youtube_\(video.id.uuidString)_thumbnail.jpg"
                    referencedFiles.insert(youtubeThumbPath)
                }
            }
            
            // Load artworks
            let artworks = ArtworkStorage.shared.loadArtworks(for: character.id.uuidString)
            for artwork in artworks {
                if let imagePath = artwork.imagePath {
                    referencedFiles.insert(normalizeFilePath(imagePath))
                }
                
                // Add custom thumbnail reference
                let thumbnailPath = "ArtworkThumbnails/\(artwork.id.uuidString)_thumbnail.jpg"
                referencedFiles.insert(thumbnailPath)
            }
        }
        
        // Get all anime and their media
        let animeList = loadAllAnime()
        for anime in animeList {
            // Load videos
            let videos = VideoStorage.shared.loadAnimeVideos(for: anime.id.uuidString)
            for video in videos {
                // Skip YouTube videos (they have empty videoPath)
                if !video.videoPath.isEmpty {
                    let normalizedPath = normalizeFilePath(video.videoPath)
                    referencedFiles.insert(normalizedPath)
                    
                    // Debug log to see video paths
                    print("🎬 [MediaCleanup] Referenced anime video: \(video.videoPath) -> normalized: \(normalizedPath)")
                } else if video.youtubeURL != nil {
                    print("🎬 [MediaCleanup] Skipping YouTube video: \(video.title)")
                }
                
                // Add thumbnail reference
                let thumbnailPath = "VideoThumbnails/\(video.id.uuidString)_thumbnail.jpg"
                referencedFiles.insert(thumbnailPath)
                
                // Also check if the video has a YouTube thumbnail URL (which might be cached)
                if let youtubeThumbnailURL = video.youtubeThumbnailURL, !youtubeThumbnailURL.isEmpty {
                    // YouTube thumbnails might be cached with a different naming pattern
                    let youtubeThumbPath = "VideoThumbnails/youtube_\(video.id.uuidString)_thumbnail.jpg"
                    referencedFiles.insert(youtubeThumbPath)
                }
            }
            
            // Load artworks
            let artworks = ArtworkStorage.shared.loadAnimeArtworks(for: anime.id.uuidString)
            for artwork in artworks {
                if let imagePath = artwork.imagePath {
                    referencedFiles.insert(normalizeFilePath(imagePath))
                }
                
                // Add custom thumbnail reference
                let thumbnailPath = "ArtworkThumbnails/\(artwork.id.uuidString)_thumbnail.jpg"
                referencedFiles.insert(thumbnailPath)
            }
            
            // Add anime icon and background images
            if let iconPath = anime.imageIdentifier {
                referencedFiles.insert(normalizeFilePath(iconPath))
            }
            if let bgPath = anime.backgroundImagePath {
                referencedFiles.insert(normalizeFilePath(bgPath))
            }
        }
        
        // Add visit plan images
        let visitPlans = VisitPlanDataStorage.shared.loadAllSavedPlans()
        for plan in visitPlans {
            let planId = plan.id.uuidString
            
            // Add spots images
            for spot in plan.spots {
                // Add main image reference
                let mainImagePath = "VisitPlanData/\(planId)/\(spot.id.uuidString)_main.jpg"
                referencedFiles.insert(mainImagePath)
                
                // Add detail images if they exist
                if let detailImagesData = spot.detailImagesData {
                    for index in 0..<detailImagesData.count {
                        let detailImagePath = "VisitPlanData/\(planId)/\(spot.id.uuidString)_detail_\(index).jpg"
                        referencedFiles.insert(detailImagePath)
                    }
                }
            }
            
            // Add plan thumbnail
            let thumbnailPath = "VisitPlanData/\(planId)/plan_thumbnail.jpg"
            referencedFiles.insert(thumbnailPath)
        }
        
        // Also check draft plans
        let draftPlans = VisitPlanDataStorage.shared.loadAllDraftPlans()
        for plan in draftPlans {
            let planId = plan.id.uuidString
            
            // Add spots images
            for spot in plan.spots {
                // Add main image reference
                let mainImagePath = "VisitPlanData/\(planId)/\(spot.id.uuidString)_main.jpg"
                referencedFiles.insert(mainImagePath)
                
                // Add detail images if they exist
                if let detailImagesData = spot.detailImagesData {
                    for index in 0..<detailImagesData.count {
                        let detailImagePath = "VisitPlanData/\(planId)/\(spot.id.uuidString)_detail_\(index).jpg"
                        referencedFiles.insert(detailImagePath)
                    }
                }
            }
            
            // Add plan thumbnail
            let thumbnailPath = "VisitPlanData/\(planId)/plan_thumbnail.jpg"
            referencedFiles.insert(thumbnailPath)
        }
        
        // Add soundtrack files
        let soundtracks = loadAllSoundtracks()
        for soundtrack in soundtracks {
            // Add audio file reference
            let audioPath = "Soundtracks/\(soundtrack.id.uuidString)_audio.m4a"
            referencedFiles.insert(audioPath)
            
            // Add thumbnail reference
            let thumbnailPath = "Soundtracks/\(soundtrack.id.uuidString)_thumbnail.jpg"
            referencedFiles.insert(thumbnailPath)
        }
        
        return referencedFiles
    }
    
    // MARK: - Path Normalization
    
    private func normalizeFilePath(_ path: String) -> String {
        // Remove any leading slashes or document directory prefix
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
            // Check if this is a video file (mov or mp4)
            if normalizedPath.hasSuffix(".mov") || normalizedPath.hasSuffix(".mp4") {
                // Check if this file exists in VideoAlbums directory
                let videoAlbumsPath = "VideoAlbums/\(normalizedPath)"
                let fullVideoAlbumsURL = documentsDirectory.appendingPathComponent(videoAlbumsPath)
                if FileManager.default.fileExists(atPath: fullVideoAlbumsURL.path) {
                    print("🔧 [MediaCleanup] Found video in VideoAlbums: \(normalizedPath) -> \(videoAlbumsPath)")
                    return videoAlbumsPath
                }
            }
            
            // Check if this file exists in AnirecoImages directory
            let anirecoPath = "AnirecoImages/\(normalizedPath)"
            let fullAnirecoURL = documentsDirectory.appendingPathComponent(anirecoPath)
            if FileManager.default.fileExists(atPath: fullAnirecoURL.path) {
                print("🔧 [MediaCleanup] Found image in AnirecoImages: \(normalizedPath) -> \(anirecoPath)")
                return anirecoPath
            }
            
            // Check if file exists in root Documents directory (legacy icons)
            let rootURL = documentsDirectory.appendingPathComponent(normalizedPath)
            if FileManager.default.fileExists(atPath: rootURL.path) {
                print("🔧 [MediaCleanup] Found legacy file in root: \(normalizedPath)")
                // Return as-is for legacy files in root
                return normalizedPath
            }
        }
        
        return normalizedPath
    }
    
    private func isMediaFile(_ fileName: String) -> Bool {
        let mediaExtensions = ["jpg", "jpeg", "png", "gif", "mp4", "mov", "m4v", "avi", "m4a", "mp3", "wav"]
        let fileExtension = (fileName as NSString).pathExtension.lowercased()
        return mediaExtensions.contains(fileExtension)
    }
    
    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
    
    // MARK: - Data Loading Methods
    
    private func loadAllCharacters() -> [Character] {
        if let data = UserDefaults.standard.data(forKey: "characters"),
           let characters = try? JSONDecoder().decode([Character].self, from: data) {
            return characters
        }
        return []
    }
    
    private func loadAllAnime() -> [Anime] {
        if let data = UserDefaults.standard.data(forKey: "animeList"),
           let animeList = try? JSONDecoder().decode([Anime].self, from: data) {
            return animeList
        }
        return []
    }
    
    private func loadAllSoundtracks() -> [Soundtrack] {
        var allSoundtracks: [Soundtrack] = []
        
        // Load soundtracks for all characters
        let characters = loadAllCharacters()
        for character in characters {
            let soundtracks = SoundtrackStorage.shared.loadSoundtracks(for: character.id.uuidString)
            allSoundtracks.append(contentsOf: soundtracks)
        }
        
        // Load soundtracks for all anime
        let animeList = loadAllAnime()
        for anime in animeList {
            let soundtracks = SoundtrackStorage.shared.loadAnimeSoundtracks(for: anime.id.uuidString)
            allSoundtracks.append(contentsOf: soundtracks)
        }
        
        return allSoundtracks
    }
    
    // MARK: - Debug Functions
    
    private func debugCleanupWithVideoFocus() {
        print("🔍 [MediaCleanup DEBUG] Analyzing video file references...")
        
        // Get all video files in VideoAlbums
        let videoAlbumsURL = documentsDirectory.appendingPathComponent("VideoAlbums")
        var videoFiles: [String] = []
        
        if let files = try? FileManager.default.contentsOfDirectory(at: videoAlbumsURL, includingPropertiesForKeys: nil) {
            for file in files {
                if file.pathExtension == "mov" || file.pathExtension == "mp4" {
                    let relativePath = "VideoAlbums/\(file.lastPathComponent)"
                    videoFiles.append(relativePath)
                    print("📹 [DEBUG] Found video file: \(relativePath)")
                }
            }
        }
        
        print("\n📊 [DEBUG] Total video files in VideoAlbums: \(videoFiles.count)")
        
        // Get all referenced video paths
        var referencedVideoPaths: Set<String> = []
        
        // Check character videos
        let characters = loadAllCharacters()
        for character in characters {
            let videos = VideoStorage.shared.loadVideos(for: character.id.uuidString)
            for video in videos {
                if !video.videoPath.isEmpty {
                    let normalizedPath = normalizeFilePath(video.videoPath)
                    referencedVideoPaths.insert(normalizedPath)
                    print("👤 [DEBUG] Character '\(character.name)' video: \(video.videoPath) -> normalized: \(normalizedPath)")
                } else if video.youtubeURL != nil {
                    print("👤 [DEBUG] Character '\(character.name)' YouTube video: \(video.title)")
                }
            }
        }
        
        // Check anime videos
        let animeList = loadAllAnime()
        for anime in animeList {
            let videos = VideoStorage.shared.loadAnimeVideos(for: anime.id.uuidString)
            for video in videos {
                if !video.videoPath.isEmpty {
                    let normalizedPath = normalizeFilePath(video.videoPath)
                    referencedVideoPaths.insert(normalizedPath)
                    print("🎬 [DEBUG] Anime '\(anime.title)' video: \(video.videoPath) -> normalized: \(normalizedPath)")
                } else if video.youtubeURL != nil {
                    print("🎬 [DEBUG] Anime '\(anime.title)' YouTube video: \(video.title)")
                }
            }
        }
        
        print("\n📊 [DEBUG] Total referenced video paths: \(referencedVideoPaths.count)")
        
        // Find orphaned videos
        let videoFilesSet = Set(videoFiles)
        let orphanedVideos = videoFilesSet.subtracting(referencedVideoPaths)
        
        print("\n⚠️ [DEBUG] Videos that would be deleted: \(orphanedVideos.count)")
        for video in orphanedVideos {
            print("  🗑️ Would delete: \(video)")
            
            // Check if this file actually exists in any reference with different format
            let filename = URL(fileURLWithPath: video).lastPathComponent
            print("    🔍 Checking for references to filename: \(filename)")
            
            // Search in all referenced paths
            for refPath in referencedVideoPaths {
                if refPath.contains(filename) {
                    print("    ⚠️ FOUND reference with different path format: \(refPath)")
                }
            }
        }
        
        // Additional check: Show some sample video references to understand format
        print("\n📋 [DEBUG] Sample video references (first 5):")
        for (index, refPath) in referencedVideoPaths.prefix(5).enumerated() {
            print("  \(index + 1). \(refPath)")
        }
    }
    
    private func debugCleanup() {
        print("🔍 [MediaCleanup DEBUG] Starting debug analysis...")
        
        // Get all media files
        let allMediaFiles = getAllMediaFiles()
        print("📊 [MediaCleanup DEBUG] Total media files found: \(allMediaFiles.count)")
        
        // Get all referenced files
        let referencedFiles = getAllReferencedFiles()
        print("📊 [MediaCleanup DEBUG] Total referenced files: \(referencedFiles.count)")
        
        // Find orphaned files
        let orphanedFiles = allMediaFiles.subtracting(referencedFiles)
        print("📊 [MediaCleanup DEBUG] Orphaned files that would be deleted: \(orphanedFiles.count)")
        
        // Show sample of files that would be deleted
        if !orphanedFiles.isEmpty {
            print("🗑️ [MediaCleanup DEBUG] Files that would be deleted:")
            for (index, file) in orphanedFiles.prefix(10).enumerated() {
                print("  \(index + 1). \(file)")
            }
            if orphanedFiles.count > 10 {
                print("  ... and \(orphanedFiles.count - 10) more files")
            }
        }
        
        // Show AnirecoImages files specifically
        let anirecoOrphaned = orphanedFiles.filter { $0.hasPrefix("AnirecoImages/") }
        if !anirecoOrphaned.isEmpty {
            print("⚠️ [MediaCleanup DEBUG] AnirecoImages files that would be deleted: \(anirecoOrphaned.count)")
            for file in anirecoOrphaned.prefix(5) {
                print("  - \(file)")
            }
        }
        
        // Check for path format mismatches
        print("\n🔍 [MediaCleanup DEBUG] Checking for path format issues...")
        
        // Sample some referenced files to check their format
        for (index, refFile) in referencedFiles.prefix(5).enumerated() {
            print("📌 Referenced file \(index + 1): \(refFile)")
            
            // Check if this file actually exists
            let fullPath = documentsDirectory.appendingPathComponent(refFile)
            if FileManager.default.fileExists(atPath: fullPath.path) {
                print("  ✅ File exists")
            } else {
                print("  ❌ File does NOT exist at expected path")
                
                // Try to find it in other locations
                if refFile.contains("/") {
                    let filename = URL(fileURLWithPath: refFile).lastPathComponent
                    print("  🔍 Looking for filename: \(filename)")
                    
                    // Check if it exists in root
                    let rootPath = documentsDirectory.appendingPathComponent(filename)
                    if FileManager.default.fileExists(atPath: rootPath.path) {
                        print("  ⚠️ Found in root directory (path mismatch!)")
                    }
                }
            }
        }
    }
    
    // MARK: - Manual Cleanup
    
    func manualCleanup() {
        print("🧹 [MediaCleanup] Starting MANUAL cleanup...")
        
        // Get all media files
        let allMediaFiles = getAllMediaFiles()
        
        // Get all referenced files
        let referencedFiles = getAllReferencedFiles()
        
        // Find orphaned files
        let orphanedFiles = allMediaFiles.subtracting(referencedFiles)
        
        print("📊 [MediaCleanup] Manual cleanup summary:")
        print("  - Total media files: \(allMediaFiles.count)")
        print("  - Referenced files: \(referencedFiles.count)")
        print("  - Orphaned files to delete: \(orphanedFiles.count)")
        
        // Only delete files in safe directories
        let safeDirectoryPrefixes = ["VideoThumbnails/", "ArtworkThumbnails/", "Soundtracks/", "VideoAlbums/"]
        
        var deletedCount = 0
        var freedSpace: Int64 = 0
        
        for filePath in orphanedFiles {
            // Safety check: Only delete files in safe directories
            let isInSafeDirectory = safeDirectoryPrefixes.contains { filePath.hasPrefix($0) }
            
            if isInSafeDirectory {
                let fileURL = documentsDirectory.appendingPathComponent(filePath)
                
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    do {
                        let attributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
                        let fileSize = attributes[.size] as? Int64 ?? 0
                        
                        try FileManager.default.removeItem(at: fileURL)
                        
                        deletedCount += 1
                        freedSpace += fileSize
                        
                        print("🗑️ [MediaCleanup] Deleted: \(filePath) (size: \(formatBytes(fileSize)))")
                    } catch {
                        print("❌ [MediaCleanup] Failed to delete: \(filePath) - \(error)")
                    }
                }
            }
        }
        
        print("✅ [MediaCleanup] Manual cleanup completed:")
        print("  - Deleted \(deletedCount) files")
        print("  - Freed \(formatBytes(freedSpace)) of space")
    }
    
    // MARK: - Automatic Cleanup
    
    func scheduleAutomaticCleanup() {
        // DISABLED: Automatic cleanup is disabled
        print("⚠️ [MediaCleanup] Automatic cleanup is disabled")
        // cleanupOrphanedMediaFiles()
        
        // Periodic cleanup is disabled to prevent unexpected deletions
        // Timer-based cleanup can be re-enabled if needed in the future
    }
}