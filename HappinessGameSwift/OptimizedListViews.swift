import SwiftUI

// MARK: - Lazy Loading Grid View
struct OptimizedArtworkGrid: View {
    let artworks: [Artwork]
    let columns = [
        GridItem(.flexible(), spacing: 1),
        GridItem(.flexible(), spacing: 1),
        GridItem(.flexible(), spacing: 1)
    ]
    
    @State private var visibleArtworks: Set<UUID> = []
    
    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 1) {
                ForEach(artworks, id: \.id) { artwork in
                    OptimizedArtworkCell(
                        artwork: artwork,
                        isVisible: visibleArtworks.contains(artwork.id)
                    )
                    .onAppear {
                        visibleArtworks.insert(artwork.id)
                    }
                    .onDisappear {
                        // Keep a small buffer of recently viewed items
                        if visibleArtworks.count > 30 {
                            visibleArtworks.remove(artwork.id)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Optimized Artwork Cell
struct OptimizedArtworkCell: View {
    let artwork: Artwork
    let isVisible: Bool
    
    @State private var thumbnail: UIImage?
    @State private var isLoading = false
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if isVisible {
                    if let thumbnail = thumbnail {
                        Image(uiImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.width)
                            .clipped()
                    } else {
                        Color.gray.opacity(0.2)
                            .overlay(
                                ProgressView()
                                    .opacity(isLoading ? 1 : 0)
                            )
                    }
                } else {
                    // Placeholder for off-screen items
                    Color.gray.opacity(0.1)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.width)
        }
        .aspectRatio(1, contentMode: .fit)
        .onChange(of: isVisible) { _, newValue in
            if newValue && thumbnail == nil {
                loadThumbnail()
            }
        }
    }
    
    private func loadThumbnail() {
        isLoading = true
        
        Task {
            if let imagePath = artwork.imagePath {
                // Use cached thumbnail
                let thumbnailKey = "thumb_\(artwork.id.uuidString)"
                
                if let cached = ImageCache.shared.image(for: thumbnailKey) {
                    await MainActor.run {
                        self.thumbnail = cached
                        self.isLoading = false
                    }
                    return
                }
                
                // Generate thumbnail asynchronously
                if let thumbnail = await generateThumbnail(for: imagePath) {
                    ImageCache.shared.store(thumbnail, for: thumbnailKey)
                    await MainActor.run {
                        self.thumbnail = thumbnail
                        self.isLoading = false
                    }
                }
            } else if let customThumbnail = artwork.customThumbnailData,
                      let image = UIImage(data: customThumbnail) {
                await MainActor.run {
                    self.thumbnail = image
                    self.isLoading = false
                }
            }
        }
    }
    
    private func generateThumbnail(for path: String) async -> UIImage? {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let imagePath = documentsPath.appendingPathComponent(path)
                
                guard let image = UIImage(contentsOfFile: imagePath.path) else {
                    continuation.resume(returning: nil)
                    return
                }
                
                // Generate small thumbnail
                let thumbnailSize = CGSize(width: 300, height: 300)
                UIGraphicsBeginImageContextWithOptions(thumbnailSize, true, 1.0)
                
                // Fill with background color
                UIColor.white.setFill()
                UIRectFill(CGRect(origin: .zero, size: thumbnailSize))
                
                // Calculate aspect fill rect
                let scale = max(thumbnailSize.width / image.size.width,
                               thumbnailSize.height / image.size.height)
                let scaledSize = CGSize(width: image.size.width * scale,
                                       height: image.size.height * scale)
                let drawRect = CGRect(
                    x: (thumbnailSize.width - scaledSize.width) / 2,
                    y: (thumbnailSize.height - scaledSize.height) / 2,
                    width: scaledSize.width,
                    height: scaledSize.height
                )
                
                image.draw(in: drawRect)
                let thumbnail = UIGraphicsGetImageFromCurrentImageContext()
                UIGraphicsEndImageContext()
                
                continuation.resume(returning: thumbnail)
            }
        }
    }
}

// MARK: - Optimized Character List
struct OptimizedCharacterList: View {
    let characters: [Character]
    @State private var visibleCharacters: Set<UUID> = []
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(characters, id: \.id) { character in
                    OptimizedCharacterRow(
                        character: character,
                        isVisible: visibleCharacters.contains(character.id)
                    )
                    .onAppear {
                        visibleCharacters.insert(character.id)
                    }
                    .onDisappear {
                        if visibleCharacters.count > 20 {
                            visibleCharacters.remove(character.id)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Optimized Character Row
struct OptimizedCharacterRow: View {
    let character: Character
    let isVisible: Bool
    
    @State private var profileImage: UIImage?
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile image with lazy loading
            Group {
                if isVisible {
                    if let profileImage = profileImage {
                        Image(uiImage: profileImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 56, height: 56)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    } else if let imageName = character.profileImageName {
                        // Load image asynchronously
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 56, height: 56)
                            .onAppear {
                                loadProfileImage(imageName)
                            }
                    } else {
                        // Default placeholder
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LinearGradient(
                                colors: [Color.purple.opacity(0.6), Color.blue.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 56, height: 56)
                            .overlay(
                                Text(String(character.name.prefix(1)))
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)
                            )
                    }
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 56, height: 56)
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(character.name)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                Text("#\(character.tag)")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Birthday info
            VStack(alignment: .trailing, spacing: 2) {
                Image(systemName: "gift")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                
                Text(character.birthday, style: .date)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(UIColor.systemBackground))
    }
    
    private func loadProfileImage(_ imageName: String) {
        Task {
            if let cachedImage = ImageCache.shared.image(for: imageName) {
                await MainActor.run {
                    self.profileImage = cachedImage
                }
                return
            }
            
            // Load from documents directory
            await loadImageFromDocuments(imageName)
        }
    }
    
    private func loadImageFromDocuments(_ imageName: String) async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
                let imagePath = documentsPath.appendingPathComponent(imageName)
                
                if let image = UIImage(contentsOfFile: imagePath.path) {
                    // Create smaller version for list display
                    let targetSize = CGSize(width: 112, height: 112) // 2x display size
                    
                    UIGraphicsBeginImageContextWithOptions(targetSize, false, 1.0)
                    image.draw(in: CGRect(origin: .zero, size: targetSize))
                    let resizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
                    UIGraphicsEndImageContext()
                    
                    ImageCache.shared.store(resizedImage, for: imageName)
                    
                    DispatchQueue.main.async {
                        self.profileImage = resizedImage
                        continuation.resume()
                    }
                } else {
                    continuation.resume()
                }
            }
        }
    }
}

// MARK: - Pagination Helper
struct PaginatedList<Content: View, Item: Identifiable>: View {
    let items: [Item]
    let pageSize: Int
    let content: (Item) -> Content
    
    @State private var currentPage = 0
    @State private var isLoadingMore = false
    
    init(items: [Item], pageSize: Int = 20, @ViewBuilder content: @escaping (Item) -> Content) {
        self.items = items
        self.pageSize = pageSize
        self.content = content
    }
    
    private var displayedItems: [Item] {
        let endIndex = min((currentPage + 1) * pageSize, items.count)
        return Array(items.prefix(endIndex))
    }
    
    private var hasMorePages: Bool {
        displayedItems.count < items.count
    }
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(displayedItems) { item in
                    content(item)
                }
                
                if hasMorePages {
                    HStack {
                        if isLoadingMore {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        } else {
                            Text("Load More")
                                .foregroundColor(.blue)
                        }
                    }
                    .frame(height: 60)
                    .frame(maxWidth: .infinity)
                    .onAppear {
                        loadMore()
                    }
                }
            }
        }
    }
    
    private func loadMore() {
        guard !isLoadingMore && hasMorePages else { return }
        
        isLoadingMore = true
        
        // Simulate async loading
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            currentPage += 1
            isLoadingMore = false
        }
    }
}