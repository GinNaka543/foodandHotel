import SwiftUI

struct CharacterOrderModal: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var characterManager: CharacterManager
    @State private var characters: [Character] = []
    @State private var showingDeleteAlert = false
    @State private var characterToDelete: Character?
    
    var body: some View {
        NavigationView {
            VStack {
                VStack(spacing: 8) {
                    Text(NSLocalizedString("character_order_title", comment: "Character order title"))
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(NSLocalizedString("drag_drop_to_reorder", comment: "Drag and drop instruction"))
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding()
                
                List {
                    ForEach(characters, id: \.id) { character in
                        HStack {
                            if let imageIdentifier = character.imageIdentifier, let image = loadImageFromPath(imageIdentifier) {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 50, height: 50)
                                    .clipShape(Circle())
                            } else {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 50, height: 50)
                                    .clipShape(Circle())
                            }
                            
                            VStack(alignment: .leading) {
                                Text(character.name)
                                    .font(.headline)
                                Text(character.favoriteFood)
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .onMove(perform: moveCharacter)
                    .onDelete(perform: deleteCharacter)
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
            loadCharacters()
        }
        .alert(isPresented: $showingDeleteAlert) {
            Alert(
                title: Text(NSLocalizedString("delete", comment: "Delete")),
                message: Text(NSLocalizedString("delete_character_confirmation", comment: "Delete character confirmation")),
                primaryButton: .destructive(Text(NSLocalizedString("delete", comment: "Delete"))) {
                    if let character = characterToDelete {
                        performDelete(character)
                    }
                },
                secondaryButton: .cancel(Text(NSLocalizedString("cancel", comment: "Cancel")))
            )
        }
    }
    
    private func loadCharacters() {
        // 名前のないキャラクターを除外してソート
        characters = characterManager.characters
            .filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted(by: { $0.order < $1.order })
    }
    
    private func moveCharacter(from source: IndexSet, to destination: Int) {
        characters.move(fromOffsets: source, toOffset: destination)
        
        // 順番を更新
        for index in 0..<characters.count {
            characters[index].order = index
        }
    }
    
    private func saveOrder() {
        for (index, var character) in characters.enumerated() {
            character.order = index
            characterManager.updateCharacter(character)
        }
        characterManager.saveCharacters()
        characterManager.refreshUI()
    }
    
    private func loadImageFromPath(_ imagePath: String) -> UIImage? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imageURL = documentsPath.appendingPathComponent(imagePath)
        return UIImage(contentsOfFile: imageURL.path)
    }
    
    private func isCharacterArtwork(_ fileURL: URL, character: Character) -> Bool {
        // Check if this artwork belongs to the character being deleted
        let artworkStorage = ArtworkStorage.shared
        let artworks = artworkStorage.loadArtworks(for: character.id.uuidString)
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
    
    private func isOrphanedIcon(_ fileURL: URL, character: Character) -> Bool {
        // Check if this icon file is referenced by any existing character
        let filename = fileURL.lastPathComponent
        
        // If this file is the character's current icon, don't delete it
        if let currentIcon = character.imageIdentifier {
            if currentIcon.contains(filename) || filename == currentIcon.components(separatedBy: "/").last {
                return false
            }
        }
        
        // Check if any other character is using this icon
        for otherChar in characterManager.characters where otherChar.id != character.id {
            if let icon = otherChar.imageIdentifier,
               (icon.contains(filename) || filename == icon.components(separatedBy: "/").last) {
                return false
            }
        }
        
        // If no character references this icon, it's orphaned
        return true
    }
    
    private func deleteCharacter(at offsets: IndexSet) {
        guard let index = offsets.first else { return }
        characterToDelete = characters[index]
        showingDeleteAlert = true
    }
    
    private func performDelete(_ character: Character) {
        // Delete associated photos and videos
        deleteAssociatedMedia(for: character)
        
        // Remove from local array
        if let index = characters.firstIndex(where: { $0.id == character.id }) {
            characters.remove(at: index)
        }
        
        // Delete from manager
        characterManager.deleteCharacter(character)
        
        // Update order for remaining characters
        for (index, var char) in characters.enumerated() {
            char.order = index
            characterManager.updateCharacter(char)
        }
        
        characterManager.saveCharacters()
        characterManager.refreshUI()
    }
    
    private func deleteAssociatedMedia(for character: Character) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        
        print("🗑️ Starting deletion for character: \(character.name) (ID: \(character.id.uuidString))")
        
        // Delete artworks using ArtworkStorage
        let artworkStorage = ArtworkStorage.shared
        let artworks = artworkStorage.loadArtworks(for: character.id.uuidString)
        print("🗑️ Found \(artworks.count) artworks to delete")
        
        // Collect all artwork filenames for this character
        var artworkFilenames: Set<String> = []
        
        for artwork in artworks {
            // Delete the actual image file and track filenames
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
            
            // Also use the artwork ID to find related files
            artworkFilenames.insert("character_artwork_\(artwork.id.uuidString).jpg")
            artworkFilenames.insert("character_artwork_\(artwork.id.uuidString).png")
            artworkFilenames.insert("character_artwork_\(artwork.id.uuidString).jpeg")
        }
        // Clear artwork metadata
        artworkStorage.saveArtworks(for: character.id.uuidString, artworks: [])
        print("✅ Cleared artwork metadata for character")
        
        // Delete character's profile image if exists
        if let imageIdentifier = character.imageIdentifier {
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
        
        // Delete character's background image if exists
        if let bgPath = character.backgroundImagePath {
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
        let videos = videoStorage.loadVideos(for: character.id.uuidString)
        for video in videos {
            videoStorage.deleteVideo(videoId: video.id.uuidString, videoPath: video.videoPath)
        }
        
        // Clear the saved videos metadata for this character
        videoStorage.saveVideos(for: character.id.uuidString, videos: [])
        
        // Delete photos from MemoryScreen storage
        // Photos are stored in UserDefaults with key "memory_photos_\(characterId)"
        let photoKey = "memory_photos_\(character.id.uuidString)"
        UserDefaults.standard.removeObject(forKey: photoKey)
        
        // Delete any photo files in documents directory
        let photosPath = documentsPath.appendingPathComponent("photos")
        if let photoFiles = try? FileManager.default.contentsOfDirectory(at: photosPath, includingPropertiesForKeys: nil) {
            for photoFile in photoFiles {
                // Check if photo is associated with this character (by ID or name in filename)
                let filename = photoFile.lastPathComponent
                if filename.contains(character.id.uuidString) ||
                   filename.contains(character.name.replacingOccurrences(of: " ", with: "_")) {
                    try? FileManager.default.removeItem(at: photoFile)
                }
            }
        }
        
        // Delete character's dedicated folder
        let characterFolder = documentsPath.appendingPathComponent("AnirecoImages/characters/\(character.id.uuidString)")
        if FileManager.default.fileExists(atPath: characterFolder.path) {
            do {
                try FileManager.default.removeItem(at: characterFolder)
                print("🗑️ Deleted character folder: \(characterFolder.lastPathComponent)")
            } catch {
                print("❌ Failed to delete character folder: \(error)")
            }
        }
        
        // Clean up any remaining files in old AnirecoImages root directory
        let anirecoPath = documentsPath.appendingPathComponent("AnirecoImages")
        if let anirecoFiles = try? FileManager.default.contentsOfDirectory(at: anirecoPath, includingPropertiesForKeys: nil) {
            print("🔍 Scanning \(anirecoFiles.count) files in AnirecoImages root folder for cleanup")
            
            for file in anirecoFiles {
                // Skip directories
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: file.path, isDirectory: &isDirectory),
                   isDirectory.boolValue {
                    continue
                }
                
                let filename = file.lastPathComponent
                let filenameLower = filename.lowercased()
                let characterIdLower = character.id.uuidString.lowercased()
                let characterNameLower = character.name.lowercased()
                let characterNameNoSpace = character.name.replacingOccurrences(of: " ", with: "").lowercased()
                let characterNameUnderscore = character.name.replacingOccurrences(of: " ", with: "_").lowercased()
                
                // Check if this file matches any of our tracked artwork filenames
                let isTrackedArtwork = artworkFilenames.contains(filename)
                
                // Check multiple patterns for character association
                let shouldDelete = isTrackedArtwork ||
                                  filenameLower.contains(characterIdLower) ||
                                  filenameLower.contains(characterNameLower) ||
                                  filenameLower.contains(characterNameNoSpace) ||
                                  filenameLower.contains(characterNameUnderscore) ||
                                  filenameLower.contains("character_\(characterIdLower)") ||
                                  filenameLower.hasPrefix("character_artwork_")
                
                if shouldDelete {
                    // Double-check this isn't used by another character
                    var isUsedByOther = false
                    if filenameLower.hasPrefix("character_artwork_") {
                        // Extract the UUID from the filename if possible
                        let components = filename.components(separatedBy: "_")
                        if components.count >= 3 {
                            let possibleUUID = components[2].replacingOccurrences(of: ".jpg", with: "")
                                .replacingOccurrences(of: ".png", with: "")
                                .replacingOccurrences(of: ".jpeg", with: "")
                            
                            // Check if any other character has artworks with this UUID
                            for otherChar in characterManager.characters where otherChar.id != character.id {
                                let otherArtworks = artworkStorage.loadArtworks(for: otherChar.id.uuidString)
                                for otherArtwork in otherArtworks {
                                    if otherArtwork.id.uuidString.lowercased() == possibleUUID.lowercased() {
                                        isUsedByOther = true
                                        print("⚠️ File \(filename) is used by \(otherChar.name), skipping")
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
        
        // Delete old character-specific folders if they exist
        let oldCharacterFolder = documentsPath.appendingPathComponent("characters/\(character.id.uuidString)")
        if FileManager.default.fileExists(atPath: oldCharacterFolder.path) {
            try? FileManager.default.removeItem(at: oldCharacterFolder)
            print("🗑️ Deleted old character folder: \(oldCharacterFolder.lastPathComponent)")
        }
    }
}

#Preview {
    CharacterOrderModal()
}