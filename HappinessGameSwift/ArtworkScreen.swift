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
    let id: UUID
    let tag: String
    var videos: [Artwork]
    let characterImageName: String
    
    var count: Int { videos.count }
    var firstImagePath: String? { videos.first?.imagePath }
    
    init(tag: String, videos: [Artwork], characterImageName: String = "") {
        self.id = UUID()
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
    @State private var refreshID = UUID()
    @State private var showIconAdjustment = false
    @State private var addButtonID = UUID() // ボタンの再描画を強制するためのID
    @State private var showAddPhotoFullScreen = false // iPad用のfullScreenCover制御
    
    // 最新のキャラクター情報を取得
    private var currentCharacter: Character {
        characterManager.characters.first(where: { $0.id == character.id }) ?? character
    }
    
    // Enum to manage sheet presentations
    enum SheetType: Identifiable {
        case addPhoto
        case tagInput
        
        var id: String {
            switch self {
            case .addPhoto: return "addPhoto"
            case .tagInput: return "tagInput"
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
        let bannerWidth = UIScreen.main.bounds.width - 32
        let bannerHeight: CGFloat = 60
        
        return Button(action: {
            showIconAdjustment = true
        }) {
            Group {
                if let imageIdentifier = currentCharacter.imageIdentifier {
                    OptimizedFileImage(
                        path: imageIdentifier,
                        targetSize: CGSize(width: bannerWidth * UIScreen.main.scale, height: bannerHeight * UIScreen.main.scale * 2)
                    )
                    .aspectRatio(contentMode: .fill)
                    .frame(width: bannerWidth, height: bannerHeight)
                    .scaleEffect(CGFloat(currentCharacter.iconScale))
                    .offset(x: CGFloat(currentCharacter.iconOffsetX), y: CGFloat(currentCharacter.iconOffsetY))
                    .clipped()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(maxWidth: .infinity, maxHeight: bannerHeight)
                }
            }
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal, 16)
        .contentShape(Rectangle())
        .id("\(currentCharacter.id)_\(currentCharacter.iconScale)_\(currentCharacter.iconOffsetX)_\(currentCharacter.iconOffsetY)")
    }
    
    // Profile icon view
    @ViewBuilder
    private var profileIconView: some View {
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
    }
    
    // Profile info view
    private var profileInfoView: some View {
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
    }
    
    // Profile section
    private var profileSection: some View {
        HStack(spacing: 12) {
            profileIconView
            profileInfoView
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
    
    // Main content view
    private var mainContentView: some View {
        ScrollView {
            VStack(spacing: 0) {
                // バナー (no header)
                bannerView
                
                // Profile section
                profileSection
                
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
                AddArtworkButton(
                    showAlbum: showAlbum,
                    activeSheet: $activeSheet,
                    action: {
                        if showAlbum {
                            showTagInput = true
                        } else {
                            photoTitle = ""
                            photoTags = ""
                        }
                    }
                )
                .id(addButtonID) // ボタンにIDを付けて再描画を制御
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .zIndex(999) // ボタンを最前面に配置
                
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
                .zIndex(1) // Ensure tab buttons are above content
                
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
                        .fullScreenCover(item: $selectedAlbum) { album in
                            AlbumArtworkListScreenTemp(
                                artworks: album.videos, 
                                tag: album.tag,
                                character: character,
                                anime: nil,
                                onArtworkDeleted: { deletedArtwork in
                                    if let idx = artworks.firstIndex(where: { $0.id == deletedArtwork.id }) {
                                        // Delete the actual image file and thumbnail
                                        ArtworkStorage.shared.deleteArtwork(artworkId: deletedArtwork.id.uuidString, imagePath: deletedArtwork.imagePath)
                                        
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
                                },
                                onAlbumDeleted: {
                                    // アルバム全体を削除
                                    deleteArtworkAlbum(album)
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
                                VStack(spacing: 32) {
                                    ForEach(artworks, id: \.id) { artwork in
                                            Button(action: {
                                                selectedArtwork = artwork
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
    
    var body: some View {
        ZStack(alignment: .bottom) {
            mainContentView
            
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
                            Text(NSLocalizedString("back", comment: "Back"))
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
            // print("🎨 [ArtworkScreen] onAppear called for character: \(character.name)")
            loadArtworks()
            loadAlbumsFromUserDefaults()
            // print("🎨 [ArtworkScreen] Loaded \(artworks.count) artworks and \(albums.count) albums")
        }
        .onChange(of: activeSheet) { newValue in
            print("🔄 [activeSheet] Changed to: \(String(describing: newValue))")
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ArtworkDataUpdated"))) { notification in
            // Only reload if the notification is from a different source
            if let userInfo = notification.userInfo, 
               let source = userInfo["source"] as? String,
               source != "currentView" {
                // print("🔄 [ArtworkScreen] Received ArtworkDataUpdated notification from \(source) - reloading data")
                loadArtworks()
                loadAlbumsFromUserDefaults()
                refreshID = UUID()
            }
        }
        .fullScreenCover(isPresented: $showAbout) {
            AboutView(characters: $characterManager.characters, characterId: character.id, onClose: { showAbout = false })
                .environmentObject(characterManager)
        }
        .sheet(item: Binding<ArtworkScreen.SheetType?>(
            get: { UIDevice.current.userInterfaceIdiom == .pad ? nil : activeSheet },
            set: { activeSheet = $0 }
        ), onDismiss: {
            print("📋 [Sheet] Dismissed")
        }) { sheetType in
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
                    Text(NSLocalizedString("create_album_instruction", comment: "Create album from same tag"))
                        .font(.headline)
                    TextField(NSLocalizedString("tag_name_placeholder", comment: "#Tag name"), text: $newTag)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal, 24)
                    HStack(spacing: 16) {
                        Button(NSLocalizedString("cancel", comment: "Cancel")) {
                            activeSheet = nil
                        }
                        .foregroundColor(.red)
                        .font(.headline)
                        
                        Button(NSLocalizedString("save", comment: "Save")) {
                            let tag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !tag.isEmpty {
                                let tagArtworks = artworks.filter { $0.tags.contains(where: { $0 == tag }) }
                                if !tagArtworks.isEmpty {
                                    // Check if album already exists
                                    if !albums.contains(where: { $0.tag == tag }) {
                                        let newAlbum = ArtworkAlbum(tag: tag, videos: tagArtworks, characterImageName: "")
                                        albums.append(newAlbum)
                                        saveAlbumsToUserDefaults()
                                        print("Created album '\(tag)' with \(tagArtworks.count) artworks")
                                        print("Total albums: \(albums.count)")
                                    } else {
                                        print("Album '\(tag)' already exists")
                                    }
                                } else {
                                    print("No artworks found with tag '\(tag)'")
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
                    }
                }
                .padding(32)
            }
        }
        .alert(isPresented: $showDeleteArtworkAlbumAlert) {
            Alert(
                title: Text(NSLocalizedString("delete_album_confirm_title", comment: "Delete album?")),
                message: Text(NSLocalizedString("delete_album_confirm_message", comment: "Delete permanently")),
                primaryButton: .destructive(Text(NSLocalizedString("delete", comment: "Delete"))) {
                    if let album = deletingArtworkAlbum {
                        deleteArtworkAlbum(album)
                    }
                    deletingArtworkAlbum = nil
                },
                secondaryButton: .cancel(Text(NSLocalizedString("cancel", comment: "Cancel"))) {
                    deletingArtworkAlbum = nil
                }
            )
        }
        .alert(NSLocalizedString("r18_images_deleted", comment: ""), isPresented: $showR18Alert) {
            Button("OK") {
                showR18Alert = false
                r18ArtworkTitles.removeAll()
            }
        } message: {
            Text(NSLocalizedString("r18_images_removed", comment: "R18 images removed message").replacingOccurrences(of: "%@", with: r18ArtworkTitles.joined(separator: "\n")))
        }
        .sheet(isPresented: $showTagInput) {
            VStack(spacing: 24) {
                Text(NSLocalizedString("create_album_instruction", comment: "Create album from same tag"))
                    .font(.headline)
                TextField(NSLocalizedString("tag_name_placeholder", comment: "#Tag name"), text: $newTag)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal, 24)
                HStack(spacing: 16) {
                    Button(NSLocalizedString("cancel", comment: "Cancel")) {
                        showTagInput = false
                    }
                    .foregroundColor(.red)
                    .font(.headline)
                    
                    Button(NSLocalizedString("save", comment: "Save")) {
                        let tag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
                        if !tag.isEmpty {
                            let tagArtworks = artworks.filter { $0.tags.contains(where: { $0 == tag }) }
                            if !tagArtworks.isEmpty {
                                // Check if album already exists
                                if !albums.contains(where: { $0.tag == tag }) {
                                    let newAlbum = ArtworkAlbum(tag: tag, videos: tagArtworks, characterImageName: "")
                                    albums.append(newAlbum)
                                    saveAlbumsToUserDefaults()
                                    print("Created album '\(tag)' with \(tagArtworks.count) artworks")
                                    print("Total albums: \(albums.count)")
                                } else {
                                    print("Album '\(tag)' already exists")
                                }
                            } else {
                                print("No artworks found with tag '\(tag)'")
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
                }
            }
            .padding(32)
        }
        .fullScreenCover(isPresented: Binding<Bool>(
            get: { UIDevice.current.userInterfaceIdiom == .pad && activeSheet == .addPhoto },
            set: { if !$0 { activeSheet = nil } }
        )) {
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
        }
        .fullScreenCover(item: $selectedArtwork) { artwork in
            ArtworkPlayerScreen(
                artwork: artwork,
                character: character,
                anime: nil,
                allArtworks: artworks,
                onDelete: {
                    if let idx = artworks.firstIndex(where: { $0.id == artwork.id }) {
                        // Delete the actual image file and thumbnail
                        ArtworkStorage.shared.deleteArtwork(artworkId: artwork.id.uuidString, imagePath: artwork.imagePath)
                        
                        artworks.remove(at: idx)
                        updateAlbumsAfterArtworkDeletion(deletedArtworkId: artwork.id)
                        saveArtworksToUserDefaults()
                        saveAlbumsToUserDefaults()
                    }
                },
                onEdit: { title, tags in
                    if let idx = artworks.firstIndex(where: { $0.id == artwork.id }) {
                        artworks[idx].title = title
                        artworks[idx].tags = tags
                        updateAlbumsAfterArtworkEdit(editedArtwork: artworks[idx])
                        saveArtworksToUserDefaults()
                    }
                }
            )
        }
        .sheet(isPresented: $showIconAdjustment, onDismiss: {
            // アイコン調整後にUIを更新
            characterManager.refreshUI()
            refreshID = UUID()
        }) {
            CharacterIconAdjustmentView(
                character: Binding(
                    get: { currentCharacter },
                    set: { updatedCharacter in
                        if let idx = characterManager.characters.firstIndex(where: { $0.id == updatedCharacter.id }) {
                            characterManager.characters[idx] = updatedCharacter
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
        // Notify data update with source info
        NotificationCenter.default.post(
            name: NSNotification.Name("ArtworkDataUpdated"), 
            object: nil,
            userInfo: ["source": "currentView"]
        )
    }
    
    private func saveAlbumsToUserDefaults() {
        let key = "artwork_albums_\(character.id.uuidString)"
        if let encodedData = try? JSONEncoder().encode(albums) {
            // Save using UserDefaultsHelper to ensure consistency
            UserDefaultsHelper.shared.setData(encodedData, forKey: key)
            print("📝 [ArtworkScreen] Saved \(albums.count) albums to UserDefaults with key: \(key)")
        }
    }
    
    private func loadAlbumsFromUserDefaults() {
        let key = "artwork_albums_\(character.id.uuidString)"
        // Load from UserDefaultsHelper
        if let data = UserDefaultsHelper.shared.getData(forKey: key),
           let decodedAlbums = try? JSONDecoder().decode([ArtworkAlbum].self, from: data) {
            // Rebuild albums with current artworks to ensure they're up to date
            albums = decodedAlbums.map { album in
                let currentArtworks = artworks.filter { artwork in
                    artwork.tags.contains(album.tag)
                }
                return ArtworkAlbum(tag: album.tag, videos: currentArtworks, characterImageName: album.characterImageName)
            }
            // print("📖 [ArtworkScreen] Loaded and rebuilt \(albums.count) albums from UserDefaults")
            for album in albums {
                // print("  - Album '\(album.tag)' with \(album.videos.count) artworks")
            }
        } else {
            albums = []
            // print("📖 [ArtworkScreen] No albums found for key: \(key)")
        }
    }
    
    func saveArtwork() {
        print("💾 [SaveArtwork] Starting save process")
        guard let image = selectedImage else { 
            print("⚠️ [SaveArtwork] No selected image, returning")
            return 
        }
        let tags = photoTags.isEmpty ? [] : photoTags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        let fileName = "character_artwork_\(UUID().uuidString).png"
        let path = saveImageToCharacterFolder(image, characterId: character.id.uuidString, fileName: fileName)
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
        print("✅ [SaveArtwork] Artwork saved successfully")
        
        // Reload albums to include the new artwork
        loadAlbumsFromUserDefaults()
        
        // Reset state
        selectedImage = nil
        photoTitle = ""
        photoTags = ""
        
        // メインスレッドで確実にactiveSheetをnilにする
        DispatchQueue.main.async {
            activeSheet = nil
        }
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
        
        // Reload albums to include the new artwork
        loadAlbumsFromUserDefaults()
        
        // Reset state
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

// 独立したボタンコンポーネント
struct AddArtworkButton: View {
    let showAlbum: Bool
    @Binding var activeSheet: ArtworkScreen.SheetType?
    let action: () -> Void
    
    var body: some View {
        // Textビューをタップ可能にする
        Text(showAlbum ? NSLocalizedString("create_album", comment: "Create album") : NSLocalizedString("add_photo", comment: "Add photo"))
            .font(.system(size: 16, weight: .medium))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10.4)
            .background(Color.black)
            .cornerRadius(20)
            .contentShape(Rectangle()) // タップ領域を明示的に設定
            .onTapGesture {
                print("🔘 [AddArtworkButton] onTapGesture - showAlbum: \(showAlbum), activeSheet: \(String(describing: activeSheet))")
                
                if !showAlbum {
                    // アートワークモードの場合
                    if activeSheet == nil {
                        action()
                        // 少し遅延させてからactiveSheetを設定
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            activeSheet = .addPhoto
                        }
                    } else {
                        print("⚠️ [AddArtworkButton] activeSheet is not nil, skipping")
                    }
                } else {
                    // アルバムモードの場合
                    action()
                }
            }
    }
}