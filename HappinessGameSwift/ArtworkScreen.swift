import SwiftUI
import PhotosUI
import Foundation

// Artwork model that can be used for both anime and character artworks
struct Artwork: Identifiable, Codable, Hashable {
    let id: UUID
    let characterId: UUID
    var imagePath: String?
    var title: String
    var tags: [String]
    var createdAt: Date
    var pixivURL: String?
    var twitterURL: String?
    var customThumbnailData: Data?
    var viewCount: Int? = 0
    
    init(id: UUID = UUID(), characterId: UUID, imagePath: String? = nil, title: String, tags: [String] = [], createdAt: Date = Date(), pixivURL: String? = nil, twitterURL: String? = nil, customThumbnailData: Data? = nil, viewCount: Int? = 0) {
        self.id = id
        self.characterId = characterId
        self.imagePath = imagePath
        self.title = title
        self.tags = tags
        self.createdAt = createdAt
        self.pixivURL = pixivURL
        self.twitterURL = twitterURL
        self.customThumbnailData = customThumbnailData
        self.viewCount = viewCount
    }
    
    static func == (lhs: Artwork, rhs: Artwork) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// Album model for grouping artworks by tags
struct ArtworkAlbum: Identifiable, Hashable, Equatable, Codable {
    let id = UUID()
    let tag: String
    var videos: [Artwork]
    let characterImageName: String
    
    var count: Int { videos.count }
    var firstImagePath: String? { videos.first?.imagePath }
    
    init(tag: String, videos: [Artwork], characterImageName: String = "") {
        self.tag = tag
        self.videos = videos
        self.characterImageName = characterImageName
    }
    
    static func == (lhs: ArtworkAlbum, rhs: ArtworkAlbum) -> Bool {
        lhs.id == rhs.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// Typealias to use the actual screens
typealias AlbumArtworkListScreenTemp = AlbumArtworkListScreen
typealias ArtworkPlayerScreenTemp = ArtworkPlayerScreen

struct ArtworkScreen: View {
    let character: Character
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var characterManager: CharacterManager
    @State private var artworks: [Artwork] = []
    @State private var showAddSheet = false
    @State private var selectedImage: UIImage? = nil
    @State private var photoTitle: String = ""
    @State private var photoTags: String = ""
    @State private var showAlbum = false
    @State private var showAbout = false
    @State private var showTagInput = false
    @State private var newTag: String = ""
    @State private var filteredTags: [String] = []
    @State private var showActionSheet = false
    @State private var selectedArtwork: Artwork? = nil
    @State private var showEditTitle = false
    @State private var showEditTags = false
    @State private var editText = ""
    @State private var showDeleteAlert = false
    @State private var showEditMenu = false
    @State private var deletingArtworkID: UUID? = nil
    @State private var albums: [ArtworkAlbum] = []
    @State private var selectedAlbum: ArtworkAlbum? = nil
    @State private var showFullscreenImage = false
    @State private var showPixivRedirect = false
    @State private var pixivRedirectURL: String = ""
    @State private var pixivRedirectArtwork: Artwork? = nil
    @State private var showDeleteArtworkAlbumAlert = false
    @State private var deletingArtworkAlbum: ArtworkAlbum? = nil
    @State private var showR18Alert = false
    @State private var r18ArtworkTitles: [String] = []
    @State private var isShowingFullDescription = false
    @State private var showFullscreenArtwork = false
    @State private var fullscreenArtwork: Artwork? = nil
    @State private var showEditMenuInFullscreen = false
    @State private var isLoadingImage = false
    @State private var preloadedImage: UIImage? = nil
    @State private var showIconAdjustment = false
    
    // 最新のキャラクター情報を取得
    private var currentCharacter: Character {
        characterManager.characters.first(where: { $0.id == character.id }) ?? character
    }
    
    // Enum to manage sheet presentations
    enum SheetType: Identifiable {
        case addPhoto
        case tagInput
        case artworkDetail(Artwork)
        
        var id: String {
            switch self {
            case .addPhoto: return "addPhoto"
            case .tagInput: return "tagInput"
            case .artworkDetail(let artwork): return "artworkDetail_\(artwork.id)"
            }
        }
    }
    @State private var activeSheet: SheetType? = nil
    
    // ヘッダービュー
    var headerView: some View {
        HStack {
            // 戻るボタン（矢印）
            Button(action: { 
                dismiss() 
            }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.black)
                    .font(.system(size: 18, weight: .bold))
            }
            .buttonStyle(PlainButtonStyle())
            .frame(width: 60, alignment: .leading)
            
            Spacer()
            
            Spacer()
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.white)
    }
    
    // バナービュー
    var bannerView: some View {
        Group {
            if let imageIdentifier = currentCharacter.imageIdentifier {
                OptimizedFileImage(
                    path: imageIdentifier,
                    targetSize: CGSize(width: UIScreen.main.bounds.width, height: 60)
                )
                .aspectRatio(contentMode: .fill)
                .frame(width: UIScreen.main.bounds.width - 32, height: 60)
                .scaleEffect(CGFloat(currentCharacter.iconScale))
                .offset(x: CGFloat(currentCharacter.iconOffsetX), y: CGFloat(currentCharacter.iconOffsetY))
                .frame(maxWidth: .infinity, maxHeight: 60)
                .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(maxWidth: .infinity, maxHeight: 60)
            }
        }
        .cornerRadius(12)
        .padding(.horizontal, 16)
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 0) {
                    // バナー (no header)
                    bannerView
                        .contentShape(Rectangle())
                        .onTapGesture {
                            showIconAdjustment = true
                        }
                
                // Profile section
                HStack(spacing: 12) {
                    // Character icon
                    if let imageIdentifier = currentCharacter.imageIdentifier {
                        OptimizedFileImage(
                            path: imageIdentifier,
                            targetSize: CGSize(width: 67, height: 67)
                        )
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 67, height: 67)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 67, height: 67)
                            .overlay(
                                Image(systemName: "person")
                                    .font(.system(size: 33))
                                    .foregroundColor(.gray)
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(currentCharacter.name)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.black)
                        Text("@\(currentCharacter.name)")
                            .font(.system(size: 12.7))
                            .foregroundColor(.black)
                        Text(String(format: NSLocalizedString("artwork_count", comment: ""), artworks.count, albums.count))
                            .font(.system(size: 15.4))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                // Description section
                if let customFields = currentCharacter.customFields,
                   let descriptionField = customFields.first(where: { $0.name == NSLocalizedString("description", comment: "Description") }),
                   !descriptionField.value.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        if descriptionField.value.count > 13 && !isShowingFullDescription {
                            HStack(spacing: 0) {
                                Text(String(descriptionField.value.prefix(13)) + "... ")
                                    .font(.system(size: 14))
                                    .foregroundColor(.black)
                                Text(NSLocalizedString("show_more", comment: ""))
                                    .font(.system(size: 14))
                                    .foregroundColor(.black)
                                    .underline()
                                    .onTapGesture {
                                        isShowingFullDescription = true
                                    }
                            }
                        } else {
                            Text(descriptionField.value)
                                .font(.system(size: 14))
                                .foregroundColor(.black)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
                            
                            if descriptionField.value.count > 13 {
                                Text(NSLocalizedString("collapse", comment: ""))
                                    .font(.system(size: 14))
                                    .foregroundColor(.black)
                                    .underline()
                                    .onTapGesture {
                                        isShowingFullDescription = false
                                    }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 16)
                    .padding(.trailing, 16)
                    .padding(.bottom, 12)
                }
                
                // Add button moved here - changes based on tab
                Button(action: { 
                    if showAlbum {
                        // アルバムタブの場合：アルバム作成
                        showTagInput = true
                    } else {
                        // アートワークタブの場合：画像追加
                        photoTitle = ""
                        photoTags = ""
                        activeSheet = .addPhoto
                    }
                }) {
                    Text(showAlbum ? NSLocalizedString("create_album", comment: "Create album") : NSLocalizedString("add_photo", comment: "Add photo"))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10.4)  // 12 / 1.15 = 10.4
                        .background(Color.black)
                        .cornerRadius(20)
                }
                .padding(.horizontal, 16)  // Same as banner padding
                .padding(.bottom, 16)

                // タブバー - カプセル型デザイン（左寄せ）
                HStack {
                    HStack(spacing: 12) {
                        Button(action: { showAlbum = false }) {
                            Text(NSLocalizedString("artwork", comment: "Artwork"))
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(!showAlbum ? .white : .black)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(!showAlbum ? Color(.darkGray) : Color(.systemGray5))
                                )
                        }
                        
                        Button(action: { showAlbum = true }) {
                            Text(NSLocalizedString("album", comment: "Album"))
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(showAlbum ? .white : .black)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(showAlbum ? Color(.darkGray) : Color(.systemGray5))
                                )
                        }
                    }
                    .padding(.leading, 16)
                    Spacer()
                }
                .padding(.vertical, 8)
                
                // 画像リスト or Album
                ZStack {
                    if showAlbum {
                        Group {
                            if albums.isEmpty {
                                VStack(spacing: 20) {
                                    Spacer()
                                        .frame(maxHeight: 100)
                                    
                                    Image(systemName: "folder.badge.plus")
                                        .font(.system(size: 60))
                                        .foregroundColor(.purple)
                                    
                                    Text(NSLocalizedString("no_albums_yet", comment: "No albums yet"))
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                    
                                    Text(NSLocalizedString("create_album_from_artworks", comment: "Create album from artworks with same tag"))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                    
                                    Button(action: {
                                        showTagInput = true
                                    }) {
                                        Label(NSLocalizedString("create_album", comment: "Create album"), systemImage: "plus.circle.fill")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 12)
                                            .background(Color.purple)
                                            .cornerRadius(25)
                                    }
                                    
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else {
                                ScrollView {
                                    VStack(spacing: 12) {
                                        ForEach(albums) { album in
                                            Button(action: {
                                                selectedAlbum = album
                                            }) {
                                                ZStack {
                                                    // 背景画像
                                                    if let firstArtwork = album.videos.first {
                                                        if let imagePath = firstArtwork.imagePath, let uiImage = loadImageFromPath(imagePath) {
                                                            Image(uiImage: uiImage)
                                                                .resizable()
                                                                .aspectRatio(contentMode: .fill)
                                                                .frame(height: 180)
                                                                .clipped()
                                                        } else if let pixivURL = firstArtwork.pixivURL {
                                                            if let customThumbnailData = firstArtwork.customThumbnailData,
                                                               let uiImage = UIImage(data: customThumbnailData) {
                                                                Image(uiImage: uiImage)
                                                                    .resizable()
                                                                    .aspectRatio(contentMode: .fill)
                                                                    .frame(height: 180)
                                                                    .clipped()
                                                            } else {
                                                                PixivThumbnailView(pixivURL: pixivURL)
                                                                    .frame(height: 180)
                                                                    .clipped()
                                                            }
                                                        } else {
                                                            Rectangle()
                                                                .fill(
                                                                    LinearGradient(
                                                                        gradient: Gradient(colors: [Color.purple.opacity(0.7), Color.blue.opacity(0.7)]),
                                                                        startPoint: .topLeading,
                                                                        endPoint: .bottomTrailing
                                                                    )
                                                                )
                                                                .frame(height: 180)
                                                        }
                                                    } else {
                                                        Rectangle()
                                                            .fill(
                                                                LinearGradient(
                                                                    gradient: Gradient(colors: [Color.purple.opacity(0.7), Color.blue.opacity(0.7)]),
                                                                    startPoint: .topLeading,
                                                                    endPoint: .bottomTrailing
                                                                )
                                                            )
                                                            .frame(height: 180)
                                                    }
                                                    
                                                    // グラデーションオーバーレイ
                                                    Rectangle()
                                                        .fill(
                                                            LinearGradient(
                                                                gradient: Gradient(colors: [Color.black.opacity(0.4), Color.clear]),
                                                                startPoint: .bottom,
                                                                endPoint: .top
                                                            )
                                                        )
                                                        .frame(height: 180)
                                                    
                                                    // テキスト情報
                                                    VStack(alignment: .leading, spacing: 4) {
                                                        Spacer()
                                                        HStack {
                                                            VStack(alignment: .leading, spacing: 2) {
                                                                Text(album.tag)
                                                                    .font(.system(size: 20, weight: .bold))
                                                                    .foregroundColor(.white)
                                                                Text("\(album.videos.count)個のアートワーク")
                                                                    .font(.system(size: 14))
                                                                    .foregroundColor(.white.opacity(0.8))
                                                            }
                                                            Spacer()
                                                            
                                                            // 3点ボタン
                                                            Button(action: {
                                                                deletingArtworkAlbum = album
                                                                showDeleteArtworkAlbumAlert = true
                                                            }) {
                                                                Image(systemName: "ellipsis")
                                                                    .font(.system(size: 18))
                                                                    .foregroundColor(.white)
                                                                    .rotationEffect(.degrees(90))
                                                                    .frame(width: 44, height: 44)
                                                                    .contentShape(Rectangle())
                                                            }
                                                            .contentShape(Rectangle())
                                                        }
                                                        .padding(.horizontal, 16)
                                                        .padding(.bottom, 12)
                                                    }
                                                }
                                                .cornerRadius(12)
                                                .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            .padding(.horizontal, 16)
                                        }
                                    }
                                    .padding(.top, 8)
                                    .padding(.bottom, 8)
                                }
                            }
                        }
                        .fullScreenCover(item: $selectedAlbum) { album in
                            AlbumArtworkListScreenTemp(
                                artworks: album.videos, 
                                tag: album.tag,
                                onArtworkDeleted: { deletedArtwork in
                                    if let idx = artworks.firstIndex(where: { $0.id == deletedArtwork.id }) {
                                        artworks.remove(at: idx)
                                        updateAlbumsAfterArtworkDeletion(deletedArtworkId: deletedArtwork.id)
                                        saveArtworksToUserDefaults()
                                    }
                                },
                                onArtworkEdited: { editedArtwork in
                                    if let idx = artworks.firstIndex(where: { $0.id == editedArtwork.id }) {
                                        artworks[idx] = editedArtwork
                                        updateAlbumsAfterArtworkEdit(editedArtwork: editedArtwork)
                                        saveArtworksToUserDefaults()
                                    }
                                }
                            )
                        }
                    } else {
                        Group {
                            if artworks.isEmpty {
                                VStack(spacing: 20) {
                                    Spacer()
                                        .frame(maxHeight: 100)
                                    
                                    Image(systemName: "photo.on.rectangle.angled")
                                        .font(.system(size: 60))
                                        .foregroundColor(.purple)
                                    
                                    Text(NSLocalizedString("no_artworks_yet", comment: "No artworks yet"))
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                    
                                    Text(NSLocalizedString("add_artwork_instruction", comment: "Add artwork instruction"))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                    
                                    Button(action: {
                                        activeSheet = .addPhoto
                                    }) {
                                        Label(NSLocalizedString("add_artwork", comment: "Add artwork"), systemImage: "plus.circle.fill")
                                            .font(.headline)
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 20)
                                            .padding(.vertical, 12)
                                            .background(Color.purple)
                                            .cornerRadius(25)
                                    }
                                    
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            } else {
                                ScrollView {
                                    VStack(spacing: 32) {
                                        ForEach(artworks, id: \.id) { artwork in
                                            Button(action: {
                                                
                                                // Preload image before showing fullscreen
                                                isLoadingImage = true
                                                
                                                // Load image in background
                                                DispatchQueue.global(qos: .userInitiated).async {
                                                    var loadedImage: UIImage? = nil
                                                    
                                                    if let imagePath = artwork.imagePath {
                                                        loadedImage = loadImageFromPath(imagePath)
                                                    }
                                                    
                                                    DispatchQueue.main.async {
                                                        preloadedImage = loadedImage
                                                        fullscreenArtwork = artwork
                                                        isLoadingImage = false
                                                        showFullscreenArtwork = true
                                                    }
                                                }
                                            }) {
                                                VStack(alignment: .leading, spacing: 0) {
                                                    ZStack {
                                                        Color.white
                                                        if let imagePath = artwork.imagePath {
                                                            OptimizedFileImage(
                                                                path: imagePath,
                                                                targetSize: CGSize(width: UIScreen.main.bounds.width, height: UIDevice.current.userInterfaceIdiom == .pad ? 466 : 233)
                                                            )
                                                            .aspectRatio(contentMode: .fill)
                                                            .frame(width: UIScreen.main.bounds.width, height: UIDevice.current.userInterfaceIdiom == .pad ? 466 : 233)
                                                        } else if let pixivURL = artwork.pixivURL {
                                                            if let customThumbnailData = artwork.customThumbnailData {
                                                                OptimizedThumbnailView(
                                                                    imageData: customThumbnailData,
                                                                    size: CGSize(width: UIScreen.main.bounds.width, height: UIDevice.current.userInterfaceIdiom == .pad ? 466 : 233)
                                                                )
                                                            } else {
                                                                PixivThumbnailView(pixivURL: pixivURL)
                                                                    .frame(width: UIScreen.main.bounds.width, height: UIDevice.current.userInterfaceIdiom == .pad ? 466 : 233)
                                                                    .aspectRatio(contentMode: .fill)
                                                            }
                                                        } else {
                                                            Rectangle()
                                                                .fill(Color.gray.opacity(0.2))
                                                                .frame(width: UIScreen.main.bounds.width, height: UIDevice.current.userInterfaceIdiom == .pad ? 466 : 233)
                                                                .overlay(
                                                                    VStack {
                                                                        Image(systemName: "photo")
                                                                            .font(.largeTitle)
                                                                            .foregroundColor(.gray)
                                                                        Text("画像なし")
                                                                            .foregroundColor(.gray)
                                                                    }
                                                                )
                                                        }
                                                    }
                                                    .frame(width: UIScreen.main.bounds.width, height: UIDevice.current.userInterfaceIdiom == .pad ? 466 : 233)
                                                    .clipped()
                                                    .padding(.bottom, 0)
                                                    HStack(alignment: .center, spacing: 12) {
                                                        if let imageIdentifier = currentCharacter.imageIdentifier, let image = loadImageFromPath(imageIdentifier) {
                                                            Image(uiImage: image)
                                                                .resizable()
                                                                .aspectRatio(contentMode: .fill)
                                                                .frame(width: 40, height: 40)
                                                                .clipShape(Circle())
                                                        } else {
                                                            Circle()
                                                                .fill(Color.gray.opacity(0.3))
                                                                .frame(width: 40, height: 40)
                                                                .overlay(
                                                                    Image(systemName: "person")
                                                                        .font(.system(size: 20))
                                                                        .foregroundColor(.gray)
                                                                )
                                                        }
                                                        VStack(alignment: .leading, spacing: 2) {
                                                            Text(artwork.title)
                                                                .font(.headline)
                                                                .foregroundColor(.black)
                                                            Text(artwork.tags.isEmpty ? "#nakajimaginsei" : "#" + artwork.tags.joined(separator: " #"))
                                                                .font(.caption)
                                                                .foregroundColor(.gray)
                                                        }
                                                        Spacer()
                                                    }
                                                    .padding(.top, 8)
                                                    .padding(.leading, 8)
                                                }
                                                .padding(.vertical, 8)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                    .padding(.top, 8)
                                }
                            }
                        }
                    }
                    }
                }
            }
            
            
            // Navigation bar at bottom
            VStack {
                Spacer()
                HStack(spacing: 0) {
                    // Back button
                    Button(action: {
                        dismiss()
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 24))
                            Text("戻る")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(.gray)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(ArtworkNavigationButtonStyle())
                    
                    // Artwork button
                    Button(action: {
                        showAlbum = false
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "photo")
                                .font(.system(size: 24))
                            Text(NSLocalizedString("artwork", comment: "Artwork"))
                                .font(.system(size: 10))
                        }
                        .foregroundColor(!showAlbum ? .black : .gray)
                        .frame(maxWidth: .infinity)
                    }
                    
                    // Album button
                    Button(action: {
                        // Navigate to album view
                        showAlbum = true
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "rectangle.grid.2x2")
                                .font(.system(size: 24))
                            Text(NSLocalizedString("album", comment: "Album"))
                                .font(.system(size: 10))
                        }
                        .foregroundColor(showAlbum ? .black : .gray)
                        .frame(maxWidth: .infinity)
                    }
                    
                    // About button
                    Button(action: {
                        showAbout = true
                    }) {
                        VStack(spacing: 4) {
                            if let imageIdentifier = currentCharacter.imageIdentifier, 
                               let image = loadImageFromPath(imageIdentifier) {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 24, height: 24)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle")
                                    .font(.system(size: 24))
                            }
                            Text(NSLocalizedString("about", comment: "About"))
                                .font(.system(size: 10))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, 8)
                .background(Color.white)
                .overlay(
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 0.5),
                    alignment: .top
                )
            }
        }
        // サントラプレイヤーを表示
        .overlay(
            VStack {
                Spacer()
                SoundtrackPlayerView()
                    .padding(.bottom, 70)
            }
        )
        .onAppear {
            loadArtworks()
            loadAlbumsFromUserDefaults()
        }
        .fullScreenCover(isPresented: $showAbout) {
            AboutView(characters: $characterManager.characters, characterId: character.id, onClose: { showAbout = false })
                .environmentObject(characterManager)
        }
        .sheet(item: $activeSheet) { sheetType in
            switch sheetType {
            case .addPhoto:
                AddPhotoView(
                    selectedImage: $selectedImage, 
                    photoTitle: $photoTitle, 
                    photoTags: $photoTags,
                    onSave: {
                        if !photoTitle.trimmingCharacters(in: .whitespaces).isEmpty && !photoTags.trimmingCharacters(in: .whitespaces).isEmpty {
                            saveArtwork()
                        }
                    },
                    onPixivSave: { pixivURL, title, imageURL, tags in
                        savePixivArtwork(pixivURL: pixivURL, title: title, imageURL: imageURL, tags: tags)
                    }
                )
            case .tagInput:
                VStack(spacing: 24) {
                    Text("同じタグからアルバムを作れます")
                        .font(.headline)
                    TextField("#タグ名", text: $newTag)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal, 24)
                    Button("保存") {
                        let tag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !tag.isEmpty {
                            let tagArtworks = artworks.filter { $0.tags.contains(where: { $0 == tag }) }
                            if !tagArtworks.isEmpty {
                                albums.append(ArtworkAlbum(tag: tag, videos: tagArtworks, characterImageName: ""))
                                saveAlbumsToUserDefaults()
                            }
                        }
                        newTag = ""
                        activeSheet = nil
                    }
                    .font(.headline)
                    .padding(.horizontal, 32)
                    .padding(.vertical, 10)
                    .background(Color.black)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    Button("キャンセル") {
                        activeSheet = nil
                    }
                    .foregroundColor(.red)
                }
                .padding(32)
            case .artworkDetail(let artwork):
                GeometryReader { geometry in
                    ZStack {
                        VStack(spacing: 0) {
                            HStack {
                                Spacer()
                                Button(action: {
                                    showEditMenu = true
                                }) {
                                    Text("編集")
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.top, 16)
                            .padding(.bottom, 8)
                            
                            if let imagePath = artwork.imagePath, let uiImage = loadImageFromPath(imagePath) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .onTapGesture {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            showFullscreenImage = true
                                        }
                                    }
                            } else if let pixivURL = artwork.pixivURL {
                                PixivFullscreenView(pixivURL: pixivURL)
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .onTapGesture {
                                        withAnimation(.easeInOut(duration: 0.3)) {
                                            showFullscreenImage = true
                                        }
                                    }
                            } else {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .overlay(
                                        VStack {
                                            Image(systemName: "photo")
                                                .font(.largeTitle)
                                                .foregroundColor(.gray)
                                            Text("画像なし")
                                                .foregroundColor(.gray)
                                        }
                                    )
                            }
                            
                            VStack(alignment: .leading, spacing: 12) {
                                Text(artwork.title)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 16)
                                
                                if !artwork.tags.isEmpty {
                                    Text("タグ: " + artwork.tags.joined(separator: ", "))
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 16)
                                }
                                
                                if let pixivURL = artwork.pixivURL {
                                    Button(action: {
                                        if let url = URL(string: pixivURL) {
                                            UIApplication.shared.open(url)
                                        }
                                    }) {
                                        HStack {
                                            Image(systemName: "link")
                                            Text("Pixivで開く")
                                        }
                                        .foregroundColor(.blue)
                                        .padding(.horizontal, 16)
                                    }
                                }
                            }
                            .padding(.bottom, 16)
                        }
                        
                        if showEditMenu {
                            VStack {
                                Spacer()
                                VStack(spacing: 0) {
                                    Button(action: {
                                        showEditTitle = true
                                        editText = artwork.title
                                        showEditMenu = false
                                    }) {
                                        HStack {
                                            Image(systemName: "pencil")
                                            Text("タイトルを編集")
                                        }
                                        .foregroundColor(.blue)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                    }
                                    
                                    Divider()
                                    
                                    Button(action: {
                                        showEditTags = true
                                        editText = artwork.tags.joined(separator: ", ")
                                        showEditMenu = false
                                    }) {
                                        HStack {
                                            Image(systemName: "tag")
                                            Text("タグを編集")
                                        }
                                        .foregroundColor(.blue)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                    }
                                    
                                    Divider()
                                    
                                    Button(action: {
                                        showDeleteAlert = true
                                        deletingArtworkID = artwork.id
                                        showEditMenu = false
                                    }) {
                                        HStack {
                                            Image(systemName: "trash")
                                            Text("削除")
                                        }
                                        .foregroundColor(.red)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                    }
                                }
                                .background(Color.white)
                                .cornerRadius(12)
                                .shadow(radius: 8)
                                .padding(.horizontal, 32)
                                .padding(.bottom, 32)
                            }
                        }
                        
                        if showEditTitle {
                            VStack(spacing: 16) {
                                Text("タイトルを編集")
                                    .font(.headline)
                                    .padding(.top, 16)
                                
                                TextField("タイトル", text: $editText)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .padding(.horizontal, 16)
                                
                                HStack(spacing: 12) {
                                    Button(action: {
                                        showEditTitle = false
                                    }) {
                                        Text("キャンセル")
                                            .foregroundColor(.gray)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                    }
                                    
                                    Button(action: {
                                        if let idx = artworks.firstIndex(where: { $0.id == artwork.id }) {
                                            artworks[idx].title = editText
                                            saveArtworksToUserDefaults()
                                        }
                                        showEditTitle = false
                                    }) {
                                        Text("保存")
                                            .foregroundColor(.blue)
                                            .fontWeight(.bold)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 16)
                            }
                            .background(Color.white)
                            .cornerRadius(18)
                            .shadow(radius: 16)
                            .frame(maxWidth: 340)
                            .padding(.horizontal, 32)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        }
                        
                        if showEditTags {
                            VStack(spacing: 16) {
                                Text("タグを編集")
                                    .font(.headline)
                                    .padding(.top, 16)
                                
                                TextField("タグ（カンマ区切り）", text: $editText)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .padding(.horizontal, 16)
                                
                                HStack(spacing: 12) {
                                    Button(action: {
                                        showEditTags = false
                                    }) {
                                        Text("キャンセル")
                                            .foregroundColor(.gray)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                    }
                                    
                                    Button(action: {
                                        if let idx = artworks.firstIndex(where: { $0.id == artwork.id }) {
                                            artworks[idx].tags = editText.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                                            saveArtworksToUserDefaults()
                                        }
                                        showEditTags = false
                                    }) {
                                        Text("保存")
                                            .foregroundColor(.blue)
                                            .fontWeight(.bold)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 16)
                            }
                            .background(Color.white)
                            .cornerRadius(18)
                            .shadow(radius: 16)
                            .frame(maxWidth: 340)
                            .padding(.horizontal, 32)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        }
                        
                        if showDeleteAlert {
                            VStack(spacing: 16) {
                                Text("削除確認")
                                    .font(.headline)
                                    .padding(.top, 16)
                                
                                Text("このアートワークを削除しますか？")
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 16)
                                
                                HStack(spacing: 12) {
                                    Button(action: {
                                        showDeleteAlert = false
                                    }) {
                                        Text("キャンセル")
                                            .foregroundColor(.gray)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                    }
                                    
                                    Button(action: {
                                        if let deletingID = deletingArtworkID,
                                           let idx = artworks.firstIndex(where: { $0.id == deletingID }) {
                                            artworks.remove(at: idx)
                                            updateAlbumsAfterArtworkDeletion(deletedArtworkId: deletingID)
                                            saveArtworksToUserDefaults()
                                            saveAlbumsToUserDefaults()
                                        }
                                        showDeleteAlert = false
                                    }) {
                                        Text("削除")
                                            .foregroundColor(.red)
                                            .fontWeight(.bold)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 16)
                            }
                            .background(Color.white)
                            .cornerRadius(18)
                            .shadow(radius: 16)
                            .frame(maxWidth: 340)
                            .padding(.horizontal, 32)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        }
                        
                        if showFullscreenImage {
                            ZStack {
                                Color.black
                                    .edgesIgnoringSafeArea(.all)
                                
                                if let imagePath = artwork.imagePath, let uiImage = loadImageFromPath(imagePath) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                } else if let pixivURL = artwork.pixivURL {
                                    PixivFullscreenView(pixivURL: pixivURL)
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                }
                                
                                VStack {
                                    HStack {
                                        Spacer()
                                        Button(action: {
                                            withAnimation(.easeInOut(duration: 0.3)) {
                                                showFullscreenImage = false
                                            }
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .font(.system(size: 30))
                                                .foregroundColor(.white)
                                                .background(Color.black.opacity(0.5))
                                                .clipShape(Circle())
                                        }
                                        .padding(.top, 50)
                                        .padding(.trailing, 20)
                                    }
                                    Spacer()
                                }
                            }
                            .transition(.opacity)
                        }
                    }
                }
            }
        }
        .alert(isPresented: $showDeleteArtworkAlbumAlert) {
            Alert(
                title: Text("アルバムを削除しますか？"),
                message: Text("このアルバムは完全に削除されます。"),
                primaryButton: .destructive(Text("削除")) {
                    if let album = deletingArtworkAlbum {
                        deleteArtworkAlbum(album)
                    }
                    deletingArtworkAlbum = nil
                },
                secondaryButton: .cancel(Text("キャンセル")) {
                    deletingArtworkAlbum = nil
                }
            )
        }
        .alert("読み込めない画像を削除しました", isPresented: $showR18Alert) {
            Button("OK") {
                showR18Alert = false
                r18ArtworkTitles.removeAll()
            }
        } message: {
            Text("以下の画像は読み込めないため削除されました：\n\(r18ArtworkTitles.joined(separator: "\n"))\n\nR18作品のサムネイルは表示できないため、自動的に削除されます。")
        }
        .sheet(isPresented: $showTagInput) {
            VStack(spacing: 24) {
                Text("同じタグからアルバムを作れます")
                    .font(.headline)
                TextField("#タグ名", text: $newTag)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal, 24)
                Button("保存") {
                    let tag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !tag.isEmpty {
                        let tagArtworks = artworks.filter { $0.tags.contains(where: { $0 == tag }) }
                        if !tagArtworks.isEmpty {
                            albums.append(ArtworkAlbum(tag: tag, videos: tagArtworks, characterImageName: ""))
                            saveAlbumsToUserDefaults()
                        }
                    }
                    newTag = ""
                    showTagInput = false
                }
                .font(.headline)
                .padding(.horizontal, 32)
                .padding(.vertical, 10)
                .background(Color.black)
                .foregroundColor(.white)
                .cornerRadius(10)
                Button("キャンセル") {
                    showTagInput = false
                }
                .foregroundColor(.red)
            }
            .padding(32)
        }
        // Loading overlay
        .overlay(
            Group {
                if isLoadingImage {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 20) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .black))
                                .scaleEffect(2.0)
                            
                            Text("ローディング中...")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.black)
                        }
                        .frame(width: 200, height: 150)
                        .background(Color.white)
                        .cornerRadius(12)
                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                    }
                }
            }
        )
        .fullScreenCover(isPresented: $showFullscreenArtwork) {
            ZStack {
                // Always show black background first
                Color.black
                    .ignoresSafeArea()
                
                if let artwork = fullscreenArtwork {
                    FullscreenArtworkView(
                        artwork: artwork,
                        preloadedImage: preloadedImage,
                        onEdit: {
                            showEditMenuInFullscreen = true
                        },
                        onDelete: {
                            if let idx = artworks.firstIndex(where: { $0.id == artwork.id }) {
                                artworks.remove(at: idx)
                                updateAlbumsAfterArtworkDeletion(deletedArtworkId: artwork.id)
                                saveArtworksToUserDefaults()
                                saveAlbumsToUserDefaults()
                            }
                            showFullscreenArtwork = false
                            fullscreenArtwork = nil
                            preloadedImage = nil
                        },
                        onClose: {
                            showFullscreenArtwork = false
                            fullscreenArtwork = nil
                            preloadedImage = nil
                        }
                    )
                }
            }
            .preferredColorScheme(.dark)
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showIconAdjustment) {
            CharacterIconAdjustmentView(
                character: Binding(
                    get: { currentCharacter },
                    set: { updatedCharacter in
                        if let index = characterManager.characters.firstIndex(where: { $0.id == character.id }) {
                            characterManager.characters[index] = updatedCharacter
                            characterManager.updateCharacter(updatedCharacter)
                        }
                    }
                ),
                characterManager: characterManager
            )
        }
    }
    
    // MARK: - Helper Functions
    
    func loadArtworks() {
        artworks = ArtworkStorage.shared.loadArtworks(for: character.id.uuidString)
        checkPixivArtworks()
    }
    
    func checkPixivArtworks() {
        Task {
            var problematicArtworks: [(id: UUID, title: String)] = []
            
            for artwork in artworks {
                if let pixivURL = artwork.pixivURL,
                   artwork.customThumbnailData == nil {
                    // Check if we can load the thumbnail
                    if let artworkId = extractPixivArtworkId(from: pixivURL) {
                        let testURL = "https://embed.pixiv.net/artwork.php?illust_id=\(artworkId)"
                        
                        do {
                            if let url = URL(string: testURL) {
                                let (data, response) = try await URLSession.shared.data(from: url)
                                if let httpResponse = response as? HTTPURLResponse,
                                   httpResponse.statusCode != 200 {
                                    problematicArtworks.append((id: artwork.id, title: artwork.title))
                                } else if data.count < 1000 { // Too small response might indicate blocked content
                                    problematicArtworks.append((id: artwork.id, title: artwork.title))
                                }
                            }
                        } catch {
                            problematicArtworks.append((id: artwork.id, title: artwork.title))
                        }
                    }
                }
            }
            
            if !problematicArtworks.isEmpty {
                await MainActor.run {
                    r18ArtworkTitles = problematicArtworks.map { $0.title }
                    // Remove problematic artworks
                    artworks.removeAll { artwork in
                        problematicArtworks.contains { $0.id == artwork.id }
                    }
                    saveArtworksToUserDefaults()
                    showR18Alert = true
                }
            }
        }
    }
    
    private func extractPixivArtworkId(from url: String) -> String? {
        let pattern = "artworks/(\\d+)"
        if let regex = try? NSRegularExpression(pattern: pattern, options: []),
           let match = regex.firstMatch(in: url, options: [], range: NSRange(location: 0, length: url.count)),
           let range = Range(match.range(at: 1), in: url) {
            return String(url[range])
        }
        return nil
    }
    
    func saveArtworksToUserDefaults() {
        ArtworkStorage.shared.saveArtworks(for: character.id.uuidString, artworks: artworks)
    }
    
    private func saveAlbumsToUserDefaults() {
        let key = "artwork_albums_\(character.id.uuidString)"
        if let encodedData = try? JSONEncoder().encode(albums) {
            UserDefaultsHelper.shared.setData(encodedData, forKey: key)
        }
    }
    
    private func loadAlbumsFromUserDefaults() {
        let key = "artwork_albums_\(character.id.uuidString)"
        if let data = UserDefaultsHelper.shared.getData(forKey: key),
           let decodedAlbums = try? JSONDecoder().decode([ArtworkAlbum].self, from: data) {
            albums = decodedAlbums
        }
    }
    
    func saveArtwork() {
        guard let image = selectedImage else { return }
        let tags = photoTags.isEmpty ? [] : photoTags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let fileName = "character_artwork_\(UUID().uuidString).png"
        let path = saveImageToDocuments(image, fileName: fileName)
        let newArtwork = Artwork(
            id: UUID(),
            characterId: character.id,
            imagePath: path,
            title: photoTitle,
            tags: tags,
            createdAt: Date()
        )
        artworks.insert(newArtwork, at: 0)
        saveArtworksToUserDefaults()
        selectedImage = nil
        photoTitle = ""
        photoTags = ""
        activeSheet = nil
    }
    
    func savePixivArtwork(pixivURL: String, title: String, imageURL: String?, tags: String) {
        let tagsArray = tags.isEmpty ? [] : tags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        let newArtwork = Artwork(
            id: UUID(),
            characterId: character.id,
            imagePath: nil,
            title: title,
            tags: tagsArray,
            createdAt: Date(),
            pixivURL: pixivURL,
            twitterURL: nil
        )
        
        artworks.insert(newArtwork, at: 0)
        saveArtworksToUserDefaults()
        
        photoTitle = ""
        photoTags = ""
        activeSheet = nil
    }
    
    func updateAlbumsAfterArtworkDeletion(deletedArtworkId: UUID) {
        albums = albums.compactMap { album in
            let updatedArtworks = album.videos.filter { $0.id != deletedArtworkId }
            if updatedArtworks.isEmpty {
                return nil
            }
            return ArtworkAlbum(tag: album.tag, videos: updatedArtworks, characterImageName: "")
        }
    }
    
    func deleteArtworkAlbum(_ album: ArtworkAlbum) {
        if let index = albums.firstIndex(where: { $0.id == album.id }) {
            albums.remove(at: index)
            saveAlbumsToUserDefaults()
        }
    }
    
    func updateAlbumsAfterArtworkEdit(editedArtwork: Artwork) {
        albums = albums.map { album in
            let updatedArtworks = album.videos.map { artwork in
                if artwork.id == editedArtwork.id {
                    return editedArtwork
                } else {
                    return artwork
                }
            }
            return ArtworkAlbum(tag: album.tag, videos: updatedArtworks, characterImageName: "")
        }
    }
}

// Navigation button style that highlights on press
struct ArtworkNavigationButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(configuration.isPressed ? .black : .gray)
    }
}

// Fullscreen artwork view with edit functionality
struct FullscreenArtworkView: View {
    let artwork: Artwork
    let preloadedImage: UIImage?
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onClose: () -> Void
    
    @State private var showDeleteAlert = false
    @State private var orientation = UIDevice.current.orientation
    
    var body: some View {
        
        return GeometryReader { geometry in
            ZStack {
            // Black background - always visible
            Color.black
                .ignoresSafeArea()
            
            // Image display
            if let uiImage = preloadedImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let pixivURL = artwork.pixivURL {
                    if let customThumbnailData = artwork.customThumbnailData,
                       let uiImage = UIImage(data: customThumbnailData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        PixivFullscreenView(pixivURL: pixivURL)
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .overlay(
                            VStack {
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                                Text("画像なし")
                                    .foregroundColor(.gray)
                            }
                        )
                }
            
            // Top bar with close and edit buttons
            VStack {
                HStack {
                    // Close button
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    // Edit button
                    Button(action: {
                        showDeleteAlert = true
                    }) {
                        Text("編集")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.5))
                            .cornerRadius(20)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 50)
                
                Spacer()
            }
        }
        }
        .edgesIgnoringSafeArea(.all)
        .statusBar(hidden: true)
        .alert(isPresented: $showDeleteAlert) {
            Alert(
                title: Text("削除確認"),
                message: Text("この画像を削除しますか？"),
                primaryButton: .destructive(Text("削除")) {
                    onDelete()
                },
                secondaryButton: .cancel(Text("キャンセル"))
            )
        }
        .onAppear {
            // Enable all orientations for fullscreen view
            AppDelegate.orientationLock = .all
            
            // Force device to reconsider orientation
            UIViewController.attemptRotationToDeviceOrientation()
            
            // Listen to orientation changes
            NotificationCenter.default.addObserver(
                forName: UIDevice.orientationDidChangeNotification,
                object: nil,
                queue: .main
            ) { _ in
                orientation = UIDevice.current.orientation
            }
        }
        .onDisappear {
            // Restore portrait only orientation
            AppDelegate.orientationLock = .portrait
            
            // Force back to portrait
            UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
            UIViewController.attemptRotationToDeviceOrientation()
            
            // Remove observer
            NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
        }
    }
}