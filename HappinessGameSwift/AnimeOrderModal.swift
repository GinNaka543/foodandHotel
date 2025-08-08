import SwiftUI

struct AnimeOrderModal: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var animeManager: AnimeManager
    @State private var animes: [Anime] = []
    @State private var selectedTab: AnimeTab = .all
    @State private var showingDeleteAlert = false
    @State private var animeToDelete: Anime?
    
    // Available tabs for reordering - Use AnimeTab from AnimeScreen
    private let availableTabs: [AnimeTab] = AnimeTab.allCases
    
    var body: some View {
        NavigationView {
            VStack {
                VStack(spacing: 8) {
                    Text(NSLocalizedString("anime_order_title", comment: "Anime order title"))
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(NSLocalizedString("drag_drop_to_reorder", comment: "Drag and drop instruction"))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding()
                
                // Tab Selection
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(availableTabs, id: \.self) { tab in
                            Button(action: {
                                selectedTab = tab
                                loadAnimesForTab(tab)
                            }) {
                                Text(localizedTabName(for: tab))
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(selectedTab == tab ? .white : .primary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(
                                        RoundedRectangle(cornerRadius: 20)
                                            .fill(selectedTab == tab ? Color.blue : Color(.systemGray6))
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 8)
                
                List {
                    ForEach(animes, id: \.id) { anime in
                        HStack {
                            if let imageIdentifier = anime.imageIdentifier, let image = loadImageFromPath(imageIdentifier) {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 50, height: 50)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 50, height: 50)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            
                            VStack(alignment: .leading) {
                                Text(anime.title)
                                    .font(.headline)
                                Text(anime.hashtag)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .onMove(perform: moveAnime)
                    .onDelete(perform: deleteAnime)
                }
                .listStyle(PlainListStyle())
                .environment(\.editMode, .constant(.active))
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("cancel", comment: "Cancel button")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("save", comment: "Save button")) {
                        saveOrder()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            loadAnimesForTab(selectedTab)
        }
        .alert(isPresented: $showingDeleteAlert) {
            Alert(
                title: Text(NSLocalizedString("delete", comment: "Delete")),
                message: Text(NSLocalizedString("delete_anime_confirmation", comment: "Delete anime confirmation")),
                primaryButton: .destructive(Text(NSLocalizedString("delete", comment: "Delete"))) {
                    if let anime = animeToDelete {
                        performDelete(anime)
                    }
                },
                secondaryButton: .cancel(Text(NSLocalizedString("cancel", comment: "Cancel")))
            )
        }
    }
    
    // Helper function from AnimeScreen
    private func localizedTabName(for tab: AnimeTab) -> String {
        switch tab {
        case .all:
            return NSLocalizedString("all", comment: "")
        case .watching:
            return NSLocalizedString("watching_status", comment: "")
        case .thisTerm:
            return NSLocalizedString("this_term_status", comment: "")
        case .willWatch:
            return NSLocalizedString("will_watch_status", comment: "")
        case .watchAgain:
            return NSLocalizedString("watch_again_status", comment: "")
        case .romcom:
            return NSLocalizedString("romcom", comment: "")
        case .isekai:
            return NSLocalizedString("isekai", comment: "")
        case .sf:
            return NSLocalizedString("sf", comment: "")
        case .sports:
            return NSLocalizedString("sports", comment: "")
        case .healing:
            return NSLocalizedString("healing", comment: "")
        }
    }
    
    private func loadAnimes() {
        loadAnimesForTab(selectedTab)
    }
    
    private func loadAnimesForTab(_ tab: AnimeTab) {
        // Use the filtering logic from AnimeScreen
        let animesWithTitles = animeManager.animes.filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        let result: [Anime]
        switch tab {
        case .all:
            result = animesWithTitles
        case .watching:
            result = animesWithTitles.filter { $0.watchStatuses.contains(.watching) }
        case .willWatch:
            result = animesWithTitles.filter { $0.watchStatuses.contains(.willWatch) }
        case .watchAgain:
            result = animesWithTitles.filter { $0.watchStatuses.contains(.watchAgain) }
        case .thisTerm:
            result = animesWithTitles.filter { $0.watchStatuses.contains(.thisTerm) }
        // Genre filters
        case .romcom:
            result = animesWithTitles.filter { $0.genres.contains(.romcom) }
        case .isekai:
            result = animesWithTitles.filter { $0.genres.contains(.isekai) }
        case .sf:
            result = animesWithTitles.filter { $0.genres.contains(.sf) }
        case .sports:
            result = animesWithTitles.filter { $0.genres.contains(.sports) }
        case .healing:
            result = animesWithTitles.filter { $0.genres.contains(.healing) }
        }
        
        animes = result.sorted(by: { $0.order < $1.order })
    }
    
    private func moveAnime(from source: IndexSet, to destination: Int) {
        animes.move(fromOffsets: source, toOffset: destination)
        
        // Update order
        for index in 0..<animes.count {
            animes[index].order = index
        }
    }
    
    private func saveOrder() {
        for (index, var anime) in animes.enumerated() {
            anime.order = index
            animeManager.updateAnime(anime)
        }
        animeManager.saveAnimes()
        animeManager.refreshUI()
    }
    
    private func loadImageFromPath(_ imagePath: String) -> UIImage? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imageURL = documentsPath.appendingPathComponent(imagePath)
        return UIImage(contentsOfFile: imageURL.path)
    }
    
    private func isOrphanedAnimeIcon(_ fileURL: URL, anime: Anime) -> Bool {
        let filename = fileURL.lastPathComponent
        
        // If this file is the anime's current icon, don't delete it
        if let currentIcon = anime.imageIdentifier {
            if currentIcon.contains(filename) || filename == currentIcon.components(separatedBy: "/").last {
                return false
            }
        }
        
        // Check if any other anime is using this icon
        for otherAnime in animeManager.animes where otherAnime.id != anime.id {
            if let icon = otherAnime.imageIdentifier,
               (icon.contains(filename) || filename == icon.components(separatedBy: "/").last) {
                return false
            }
        }
        
        return true
    }
    
    private func isAnimeArtwork(_ fileURL: URL, anime: Anime) -> Bool {
        // Check if this artwork belongs to the anime being deleted
        let artworkStorage = ArtworkStorage.shared
        let artworks = artworkStorage.loadAnimeArtworks(for: anime.id.uuidString)
        let filename = fileURL.lastPathComponent
        
        for artwork in artworks {
            if let imagePath = artwork.imagePath {
                let pathComponents = imagePath.components(separatedBy: "/")
                if let lastComponent = pathComponents.last, lastComponent == filename {
                    return true
                }
            }
        }
        
        return false
    }
    
    private func isRelatedToAnimeCharacters(_ filename: String, anime: Anime) -> Bool {
        // Check if this artwork belongs to characters associated with this anime
        let artworkStorage = ArtworkStorage.shared
        
        for characterId in anime.characterIds {
            let artworks = artworkStorage.loadArtworks(for: characterId.uuidString)
            for artwork in artworks {
                // Check if this filename matches the artwork
                if filename.lowercased().contains(artwork.id.uuidString.lowercased()) {
                    return true
                }
                if let imagePath = artwork.imagePath {
                    let artworkFilename = URL(fileURLWithPath: imagePath).lastPathComponent
                    if artworkFilename == filename {
                        return true
                    }
                }
            }
        }
        
        return false
    }
    
    private func isOrphanedAnimeArtwork(_ fileURL: URL, anime: Anime) -> Bool {
        let filename = fileURL.lastPathComponent
        
        // Check if any anime is referencing this artwork
        for otherAnime in animeManager.animes where otherAnime.id != anime.id {
            if let icon = otherAnime.imageIdentifier,
               (icon.contains(filename) || filename == icon.components(separatedBy: "/").last) {
                return false
            }
            if let bg = otherAnime.backgroundImagePath,
               (bg.contains(filename) || filename == bg.components(separatedBy: "/").last) {
                return false
            }
        }
        
        return true
    }
    
    private func deleteAnime(at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        animeToDelete = animes[index]
        showingDeleteAlert = true
    }
    
    private func performDelete(_ anime: Anime) {
        // Delete associated photos and videos
        deleteAssociatedMedia(for: anime)
        
        // Remove from local array
        if let index = animes.firstIndex(where: { $0.id == anime.id }) {
            animes.remove(at: index)
        }
        
        // Delete from manager
        animeManager.deleteAnime(anime)
        
        // Update order for remaining animes
        for (index, var ani) in animes.enumerated() {
            ani.order = index
            animeManager.updateAnime(ani)
        }
        
        animeManager.saveAnimes()
        animeManager.refreshUI()
    }
    
    private func deleteAssociatedMedia(for anime: Anime) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        print("🗑️ Starting deletion for anime: \(anime.title) (ID: \(anime.id.uuidString))")
        
        // Delete artworks using ArtworkStorage
        let artworkStorage = ArtworkStorage.shared
        // For anime, check both anime-specific artworks and character artworks
        let animeArtworks = artworkStorage.loadAnimeArtworks(for: anime.id.uuidString)
        print("🗑️ Found \(animeArtworks.count) anime artworks to delete")
        
        // Collect all artwork filenames
        var artworkFilenames: Set<String> = []
        
        for artwork in animeArtworks {
            // Delete the actual image file
            if let imagePath = artwork.imagePath {
                print("🗑️ Deleting artwork: \(imagePath)")
                
                // Extract just the filename
                let filename = URL(fileURLWithPath: imagePath).lastPathComponent
                artworkFilenames.insert(filename)
                
                if imagePath.contains("AnirecoImages") {
                    let imageURL = documentsPath.appendingPathComponent(imagePath)
                    if FileManager.default.fileExists(atPath: imageURL.path) {
                        try? FileManager.default.removeItem(at: imageURL)
                        print("✅ Deleted: \(imageURL.lastPathComponent)")
                    }
                } else {
                    // Try multiple possible locations
                    let imageURL = documentsPath.appendingPathComponent(imagePath)
                    if FileManager.default.fileExists(atPath: imageURL.path) {
                        try? FileManager.default.removeItem(at: imageURL)
                        print("✅ Deleted: \(imageURL.lastPathComponent)")
                    }
                    
                    // Also check in AnirecoImages with just the filename
                    let anirecoURL = documentsPath.appendingPathComponent("AnirecoImages/\(filename)")
                    if FileManager.default.fileExists(atPath: anirecoURL.path) {
                        try? FileManager.default.removeItem(at: anirecoURL)
                        print("✅ Deleted from AnirecoImages: \(filename)")
                    }
                    
                    // Check with full path in AnirecoImages
                    let anirecoFullURL = documentsPath.appendingPathComponent("AnirecoImages/\(imagePath)")
                    if FileManager.default.fileExists(atPath: anirecoFullURL.path) {
                        try? FileManager.default.removeItem(at: anirecoFullURL)
                        print("✅ Deleted from AnirecoImages: \(imagePath)")
                    }
                }
            }
            
            // Also track artwork files by ID
            artworkFilenames.insert("anime_artwork_\(artwork.id.uuidString).jpg")
            artworkFilenames.insert("anime_artwork_\(artwork.id.uuidString).png")
            artworkFilenames.insert("anime_artwork_\(artwork.id.uuidString).jpeg")
        }
        // Clear anime artwork metadata
        artworkStorage.saveAnimeArtworks(for: anime.id.uuidString, artworks: [])
        print("✅ Cleared anime artwork metadata")
        
        // Delete anime's profile image if exists
        if let imageIdentifier = anime.imageIdentifier {
            // Check if it's in AnirecoImages folder
            if imageIdentifier.contains("AnirecoImages") {
                let imageURL = documentsPath.appendingPathComponent(imageIdentifier)
                try? FileManager.default.removeItem(at: imageURL)
            } else {
                // Try both direct path and AnirecoImages path
                let imageURL = documentsPath.appendingPathComponent(imageIdentifier)
                try? FileManager.default.removeItem(at: imageURL)
                
                let anirecoURL = documentsPath.appendingPathComponent("AnirecoImages/\(imageIdentifier)")
                try? FileManager.default.removeItem(at: anirecoURL)
            }
        }
        
        // Delete anime's background image if exists
        if let bgPath = anime.backgroundImagePath {
            // Check if it's in AnirecoImages folder
            if bgPath.contains("AnirecoImages") {
                let bgURL = documentsPath.appendingPathComponent(bgPath)
                try? FileManager.default.removeItem(at: bgURL)
            } else {
                // Try both direct path and AnirecoImages path
                let bgURL = documentsPath.appendingPathComponent(bgPath)
                try? FileManager.default.removeItem(at: bgURL)
                
                let anirecoBgURL = documentsPath.appendingPathComponent("AnirecoImages/\(bgPath)")
                try? FileManager.default.removeItem(at: anirecoBgURL)
            }
        }
        
        // Delete videos using VideoStorage
        let videoStorage = VideoStorage.shared
        
        // Delete anime-specific videos
        let animeVideos = videoStorage.loadAnimeVideos(for: anime.id.uuidString)
        for video in animeVideos {
            videoStorage.deleteVideo(videoId: video.id.uuidString, videoPath: video.videoPath)
        }
        
        // Clear the saved anime videos metadata
        videoStorage.saveAnimeVideos(for: anime.id.uuidString, videos: [])
        
        // Also delete videos from associated characters
        for characterId in anime.characterIds {
            let characterVideos = videoStorage.loadVideos(for: characterId.uuidString)
            // Filter and delete videos that are related to this anime
            let filteredVideos = characterVideos.filter { video in
                // Check if video title or tags contain anime info
                let isRelated = video.title.contains(anime.title) ||
                               video.title.contains(anime.hashtag) ||
                               video.tags.contains(anime.title) ||
                               video.tags.contains(anime.hashtag)
                
                if isRelated {
                    videoStorage.deleteVideo(videoId: video.id.uuidString, videoPath: video.videoPath)
                }
                return !isRelated
            }
            // Save the filtered videos back
            videoStorage.saveVideos(for: characterId.uuidString, videos: filteredVideos)
        }
        
        // Delete photos from storage
        let photoKey = "anime_photos_\(anime.id.uuidString)"
        UserDefaults.standard.removeObject(forKey: photoKey)
        
        // Delete any photo files in documents directory
        let photosPath = documentsPath.appendingPathComponent("photos")
        if let photoFiles = try? FileManager.default.contentsOfDirectory(at: photosPath, includingPropertiesForKeys: nil) {
            for photoFile in photoFiles {
                let filename = photoFile.lastPathComponent
                if filename.contains(anime.id.uuidString) ||
                   filename.contains(anime.title.replacingOccurrences(of: " ", with: "_")) ||
                   filename.contains(anime.hashtag.replacingOccurrences(of: "#", with: "")) {
                    try? FileManager.default.removeItem(at: photoFile)
                }
            }
        }
        
        // Delete anime's dedicated folder
        let animeFolder = documentsPath.appendingPathComponent("AnirecoImages/anime/\(anime.id.uuidString)")
        if FileManager.default.fileExists(atPath: animeFolder.path) {
            do {
                try FileManager.default.removeItem(at: animeFolder)
                print("🗑️ Deleted anime folder: \(animeFolder.lastPathComponent)")
            } catch {
                print("❌ Failed to delete anime folder: \(error)")
            }
        }
        
        // Clean up any remaining files in old AnirecoImages root directory
        let anirecoPath = documentsPath.appendingPathComponent("AnirecoImages")
        if let anirecoFiles = try? FileManager.default.contentsOfDirectory(at: anirecoPath, includingPropertiesForKeys: nil) {
            print("🔍 Scanning \(anirecoFiles.count) files in AnirecoImages root folder for cleanup")
            
            // Also collect character artwork filenames for safety
            for characterId in anime.characterIds {
                let charArtworks = artworkStorage.loadArtworks(for: characterId.uuidString)
                for artwork in charArtworks {
                    if let imagePath = artwork.imagePath {
                        let filename = URL(fileURLWithPath: imagePath).lastPathComponent
                        artworkFilenames.insert(filename)
                        artworkFilenames.insert("character_artwork_\(artwork.id.uuidString).jpg")
                        artworkFilenames.insert("character_artwork_\(artwork.id.uuidString).png")
                        artworkFilenames.insert("character_artwork_\(artwork.id.uuidString).jpeg")
                    }
                }
            }
            
            for file in anirecoFiles {
                // Skip directories
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: file.path, isDirectory: &isDirectory),
                   isDirectory.boolValue {
                    continue
                }
                
                let filename = file.lastPathComponent
                let filenameLower = filename.lowercased()
                let animeIdLower = anime.id.uuidString.lowercased()
                let animeTitleLower = anime.title.lowercased()
                let animeTitleNoSpace = anime.title.replacingOccurrences(of: " ", with: "").lowercased()
                let animeTitleUnderscore = anime.title.replacingOccurrences(of: " ", with: "_").lowercased()
                let animeHashtagClean = anime.hashtag.replacingOccurrences(of: "#", with: "").lowercased()
                
                // Check if this file matches any tracked artwork
                let isTrackedArtwork = artworkFilenames.contains(filename)
                
                // Check multiple patterns for anime association
                let shouldDelete = isTrackedArtwork ||
                                  filenameLower.contains(animeIdLower) ||
                                  filenameLower.contains(animeTitleLower) ||
                                  filenameLower.contains(animeTitleNoSpace) ||
                                  filenameLower.contains(animeTitleUnderscore) ||
                                  filenameLower.contains(animeHashtagClean) ||
                                  filenameLower.contains("anime_\(animeIdLower)") ||
                                  filenameLower.hasPrefix("anime_artwork_") ||
                                  (filenameLower.hasPrefix("character_artwork_") && isRelatedToAnimeCharacters(filename, anime: anime))
                
                if shouldDelete {
                    // Double-check this isn't used by another anime
                    var isUsedByOther = false
                    if filenameLower.hasPrefix("anime_artwork_") || filenameLower.hasPrefix("character_artwork_") {
                        // Extract the UUID from the filename if possible
                        let components = filename.components(separatedBy: "_")
                        if components.count >= 3 {
                            let possibleUUID = components[2].replacingOccurrences(of: ".jpg", with: "")
                                .replacingOccurrences(of: ".png", with: "")
                                .replacingOccurrences(of: ".jpeg", with: "")
                            
                            // Check if any other anime has artworks with this UUID
                            for otherAnime in animeManager.animes where otherAnime.id != anime.id {
                                let otherArtworks = artworkStorage.loadAnimeArtworks(for: otherAnime.id.uuidString)
                                for otherArtwork in otherArtworks {
                                    if otherArtwork.id.uuidString.lowercased() == possibleUUID.lowercased() {
                                        isUsedByOther = true
                                        print("⚠️ File \(filename) is used by \(otherAnime.title), skipping")
                                        break
                                    }
                                }
                                if isUsedByOther { break }
                            }
                        }
                    }
                    
                    if !isUsedByOther {
                        try? FileManager.default.removeItem(at: file)
                        print("🗑️ Deleted from AnirecoImages root: \(file.lastPathComponent)")
                    }
                }
            }
        }
        
        // Delete old anime-specific folders if they exist
        let oldAnimeFolder = documentsPath.appendingPathComponent("anime/\(anime.id.uuidString)")
        if FileManager.default.fileExists(atPath: oldAnimeFolder.path) {
            try? FileManager.default.removeItem(at: oldAnimeFolder)
            print("🗑️ Deleted old anime folder: \(oldAnimeFolder.lastPathComponent)")
        }
    }
}

#Preview {
    AnimeOrderModal()
}