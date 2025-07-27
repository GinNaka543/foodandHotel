import SwiftUI

// MARK: - Optimized Character Screen
struct OptimizedCharaScreen: View {
    @EnvironmentObject var mainTab: MainTabSelection
    @EnvironmentObject var characterManager: CharacterManager
    
    @State private var searchText = ""
    @State private var showAddSheet = false
    @State private var selectedCharacter: Character? = nil
    @State private var showNavigationMenu = false
    @State private var showCharacterOrderModal = false
    @State private var showPrivacyPolicy = false
    
    // Banner state - only what's needed
    @State private var bannerVideos: [MemoryVideo] = []
    @State private var currentBannerIndex = 0
    
    // Computed property instead of storing filtered results
    private var filteredCharacters: [Character] {
        if searchText.isEmpty {
            return characterManager.characters
        }
        return characterManager.characters.filter { character in
            character.name.localizedCaseInsensitiveContains(searchText) ||
            character.tag.localizedCaseInsensitiveContains(searchText) ||
            character.birthday.formatted(.dateTime.year().month().day()).contains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            // Search bar
            searchBarView
            
            // Ad banner
            SimpleAdBannerView()
                .padding(.vertical, 2)
            
            // Banner view - lazy loaded
            if !bannerVideos.isEmpty {
                OptimizedBannerView(videos: bannerVideos, currentIndex: $currentBannerIndex)
                    .frame(height: 176)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
            }
            
            // Character list with virtualization
            OptimizedCharacterList(characters: filteredCharacters)
                .environmentObject(characterManager)
        }
        .sheet(isPresented: $showAddSheet) {
            AddCharacterSheet(characters: $characterManager.characters)
                .environmentObject(characterManager)
                .onDisappear {
                    // Only reload if actually added a character
                    if characterManager.characters.count > filteredCharacters.count {
                        characterManager.loadCharacters()
                    }
                }
        }
        .fullScreenCover(item: $selectedCharacter) { character in
            CharacterDetailView(
                character: Binding(
                    get: { character },
                    set: { newCharacter in
                        if let idx = characterManager.characters.firstIndex(where: { $0.id == character.id }) {
                            characterManager.characters[idx] = newCharacter
                            characterManager.updateCharacter(newCharacter)
                        }
                    }
                ),
                characters: $characterManager.characters,
                onDismiss: {
                    selectedCharacter = nil
                }
            )
            .environmentObject(characterManager)
        }
        .overlay(navigationMenuOverlay)
        .task {
            // Load banner videos asynchronously
            await loadBannerVideos()
        }
    }
    
    // MARK: - Subviews
    
    private var headerView: some View {
        HStack {
            Button(action: { showNavigationMenu.toggle() }) {
                Image(systemName: "line.horizontal.3")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.black)
            }
            
            Spacer()
            
            Text("キャラ")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.black)
            
            Spacer()
            
            Button(action: { showAddSheet = true }) {
                Image(systemName: "plus")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.black)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }
    
    private var searchBarView: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color(.systemGray3))
                .font(.system(size: 18))
            
            TextField("Search", text: $searchText)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .font(.system(size: 16))
                .foregroundColor(.black)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 10)
        .background(Color.white)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .frame(height: 38)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    @ViewBuilder
    private var navigationMenuOverlay: some View {
        if showNavigationMenu {
            NavigationMenuView(
                isPresented: $showNavigationMenu,
                onShowCharacterOrder: {
                    showCharacterOrderModal = true
                },
                onShowAnimeOrder: nil,
                onShowPrivacyPolicy: {
                    showPrivacyPolicy = true
                }
            )
            .transition(.opacity)
            .zIndex(2)
        }
    }
    
    // MARK: - Methods
    
    private func loadBannerVideos() async {
        // Load videos from all characters efficiently
        await withTaskGroup(of: [MemoryVideo].self) { group in
            for character in characterManager.characters {
                group.addTask {
                    VideoStorage.shared.loadVideos(for: character.id.uuidString)
                        .filter { $0.youtubeURL != nil }
                }
            }
            
            var allVideos: [MemoryVideo] = []
            for await videos in group {
                allVideos.append(contentsOf: videos)
            }
            
            // Update on main thread
            await MainActor.run {
                self.bannerVideos = allVideos.shuffled()
            }
        }
    }
}

// MARK: - Optimized Banner View
struct OptimizedBannerView: View {
    let videos: [MemoryVideo]
    @Binding var currentIndex: Int
    
    private let timer = Timer.publish(every: 10, on: .main, in: .common).autoconnect()
    
    var body: some View {
        TabView(selection: $currentIndex) {
            ForEach(Array(videos.prefix(5).enumerated()), id: \.offset) { index, video in
                BannerVideoCard(video: video)
                    .tag(index)
            }
        }
        .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
        .onReceive(timer) { _ in
            withAnimation {
                currentIndex = (currentIndex + 1) % min(videos.count, 5)
            }
        }
    }
}

// MARK: - Banner Video Card
struct BannerVideoCard: View {
    let video: MemoryVideo
    @State private var thumbnailImage: UIImage?
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background image
            if let thumbnailImage = thumbnailImage {
                Image(uiImage: thumbnailImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else if let youtubeThumbnailURL = video.youtubeThumbnailURL {
                CachedAsyncImage(url: URL(string: youtubeThumbnailURL))
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.2))
            }
            
            // Overlay gradient
            LinearGradient(
                colors: [Color.black.opacity(0.7), Color.clear],
                startPoint: .bottom,
                endPoint: .center
            )
            
            // Video info
            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(2)
                
                if !video.tags.isEmpty {
                    Text(video.tags.joined(separator: ", "))
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(1)
                }
            }
            .padding(12)
        }
        .cornerRadius(12)
        .task {
            await loadThumbnail()
        }
    }
    
    private func loadThumbnail() async {
        guard let thumbnailData = video.thumbnailData else { return }
        
        await MainActor.run {
            self.thumbnailImage = UIImage(data: thumbnailData)
        }
    }
}

// MARK: - Memory-Efficient Character Row
struct OptimizedCharacterRowView: View {
    let character: Character
    @State private var profileImage: UIImage?
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile image
            profileImageView
            
            // Character info
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
        .task {
            await loadProfileImage()
        }
    }
    
    @ViewBuilder
    private var profileImageView: some View {
        if let profileImage = profileImage {
            Image(uiImage: profileImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 56, height: 56)
                .clipShape(RoundedRectangle(cornerRadius: 12))
        } else if character.profileImageName != nil {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.2))
                .frame(width: 56, height: 56)
                .overlay(
                    ProgressView()
                        .scaleEffect(0.6)
                )
        } else {
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
    }
    
    private func loadProfileImage() async {
        guard let imageName = character.profileImageName else { return }
        
        // Check cache first
        if let cached = ImageCache.shared.image(for: "profile_\(character.id)") {
            await MainActor.run {
                self.profileImage = cached
            }
            return
        }
        
        // Load and cache
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let imagePath = documentsPath.appendingPathComponent(imageName)
        
        if let image = await ImageOptimizer.shared.generateThumbnail(
            from: imagePath.path,
            size: CGSize(width: 112, height: 112)
        ) {
            ImageCache.shared.store(image, for: "profile_\(character.id)")
            await MainActor.run {
                self.profileImage = image
            }
        }
    }
}