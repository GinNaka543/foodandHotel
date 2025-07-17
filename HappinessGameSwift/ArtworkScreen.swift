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
    
    init(id: UUID = UUID(), characterId: UUID, imagePath: String? = nil, title: String, tags: [String] = [], createdAt: Date = Date(), pixivURL: String? = nil, twitterURL: String? = nil) {
        self.id = id
        self.characterId = characterId
        self.imagePath = imagePath
        self.title = title
        self.tags = tags
        self.createdAt = createdAt
        self.pixivURL = pixivURL
        self.twitterURL = twitterURL
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
            
            // タイトル
            Text(currentCharacter.name)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            // 追加ボタン
            Button(action: { 
                photoTitle = ""
                photoTags = ""
                activeSheet = .addPhoto
            }) {
                Text("追加")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.purple)
                    .clipShape(Capsule())
            }
            .frame(width: 60, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.white)
    }
    
    // バナービュー
    var bannerView: some View {
        Button(action: { activeSheet = .addPhoto }) {
            if let imageIdentifier = currentCharacter.imageIdentifier, let image = loadImageFromPath(imageIdentifier) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: 120)
                    .clipped()
                    .overlay(
                        Color.black.opacity(0.4)
                    )
                    .overlay(
                        VStack {
                            Spacer()
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("アートワーク")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Text(currentCharacter.name)
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.white.opacity(0.9))
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                        }
                    )
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(maxWidth: .infinity, maxHeight: 120)
                    .overlay(
                        VStack {
                            Spacer()
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("アートワーク")
                                        .font(.system(size: 24, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Text(currentCharacter.name)
                                        .font(.system(size: 18, weight: .medium))
                                        .foregroundColor(.white.opacity(0.9))
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                        }
                    )
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // ヘッダー
                headerView
                    .zIndex(2)
                // バナー
                bannerView
                    .allowsHitTesting(false)
                    .zIndex(1)

                // タブバー - カプセル型デザイン（左寄せ）
                HStack {
                    HStack(spacing: 12) {
                        Button(action: { showAlbum = false }) {
                            Text("ArtWork")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(!showAlbum ? .white : .black)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
                                        .fill(!showAlbum ? Color(.darkGray) : Color(.systemGray5))
                                )
                        }
                        
                        Button(action: { showAlbum = true }) {
                            Text("Album")
                                .font(.system(size: 16, weight: .regular))
                                .foregroundColor(showAlbum ? .white : .black)
                                .padding(.horizontal, 18)
                                .padding(.vertical, 8)
                                .background(
                                    Capsule()
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
                                    
                                    Text("まだアルバムがありません")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                    
                                    Text("同じタグのアートワークからアルバムを作成できます")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                    
                                    Button(action: {
                                        showTagInput = true
                                    }) {
                                        Label("アルバムを作成", systemImage: "plus.circle.fill")
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
                                    VStack(spacing: 4) {
                                        Spacer().frame(height: 5)
                                        ForEach(albums) { album in
                                            Button(action: {
                                                selectedAlbum = album
                                            }) {
                                                HStack(spacing: 12) {
                                                    // サムネイル
                                                    if let firstArtwork = album.videos.first {
                                                        if let imagePath = firstArtwork.imagePath, let uiImage = loadImageFromPath(imagePath) {
                                                            Image(uiImage: uiImage)
                                                                .resizable()
                                                                .aspectRatio(contentMode: .fill)
                                                                .frame(width: 160, height: 90)
                                                                .clipped()
                                                                .cornerRadius(8)
                                                        } else if let pixivURL = firstArtwork.pixivURL {
                                                            PixivThumbnailView(pixivURL: pixivURL)
                                                                .frame(width: 160, height: 90)
                                                                .aspectRatio(contentMode: .fill)
                                                                .clipped()
                                                                .cornerRadius(8)
                                                        } else {
                                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                                .fill(Color.gray.opacity(0.3))
                                                                .frame(width: 160, height: 90)
                                                        }
                                                    } else {
                                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                            .fill(Color.gray.opacity(0.3))
                                                            .frame(width: 160, height: 90)
                                                    }
                                                    
                                                    // 右側のコンテンツ
                                                    VStack(alignment: .leading, spacing: 4) {
                                                        Text("#" + album.tag)
                                                            .font(.system(size: 16, weight: .semibold))
                                                            .foregroundColor(.black)
                                                        
                                                        if let firstArtwork = album.videos.first {
                                                            Text(firstArtwork.tags.isEmpty ? "タグなし" : firstArtwork.tags.joined(separator: ", "))
                                                                .font(.system(size: 14))
                                                                .foregroundColor(.gray)
                                                                .lineLimit(2)
                                                        }
                                                        
                                                        Text("\(album.videos.count)件")
                                                            .font(.system(size: 12))
                                                            .foregroundColor(.gray)
                                                    }
                                                    
                                                    Spacer()
                                                    
                                                    // 3点ボタン
                                                    Button(action: {
                                                        deletingArtworkAlbum = album
                                                        showDeleteArtworkAlbumAlert = true
                                                    }) {
                                                        Image(systemName: "ellipsis")
                                                            .font(.system(size: 16, weight: .bold))
                                                            .foregroundColor(.white)
                                                            .frame(width: 32, height: 32)
                                                            .background(Color.black.opacity(0.7))
                                                            .clipShape(Circle())
                                                            .shadow(radius: 4)
                                                    }
                                                }
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 8)
                                                .background(Color.white)
                                                .cornerRadius(8)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                        }
                                    }
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
                                    
                                    Text("まだアートワークがありません")
                                        .font(.title2)
                                        .fontWeight(.semibold)
                                    
                                    Text("右上の追加ボタンからアートワークを追加できます")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal)
                                    
                                    Button(action: {
                                        activeSheet = .addPhoto
                                    }) {
                                        Label("アートワークを追加", systemImage: "plus.circle.fill")
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
                                            VStack(alignment: .leading, spacing: 0) {
                                                ZStack {
                                                    Color.white
                                                    if let imagePath = artwork.imagePath, let uiImage = loadImageFromPath(imagePath) {
                                                        Image(uiImage: uiImage)
                                                            .resizable()
                                                            .aspectRatio(contentMode: .fill)
                                                            .frame(width: UIScreen.main.bounds.width, height: 233)
                                                    } else if let pixivURL = artwork.pixivURL {
                                                        PixivThumbnailView(pixivURL: pixivURL)
                                                            .frame(width: UIScreen.main.bounds.width, height: 233)
                                                            .aspectRatio(contentMode: .fill)
                                                    } else {
                                                        Rectangle()
                                                            .fill(Color.gray.opacity(0.2))
                                                            .frame(width: UIScreen.main.bounds.width, height: 233)
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
                                                .frame(width: UIScreen.main.bounds.width, height: 233)
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
                                            .contentShape(Rectangle())
                                            .onTapGesture {
                                                if let pixivURL = artwork.pixivURL {
                                                    pixivRedirectURL = pixivURL
                                                    pixivRedirectArtwork = artwork
                                                    showPixivRedirect = true
                                                } else {
                                                    selectedArtwork = artwork
                                                }
                                            }
                                        }
                                    }
                                    .padding(.top, 8)
                                }
                            }
                        }
                        .fullScreenCover(item: $selectedArtwork) { artwork in
                            ArtworkPlayerScreenTemp(
                                artwork: artwork, 
                                allArtworks: artworks,
                                onDelete: {
                                    if let idx = artworks.firstIndex(where: { $0.id == artwork.id }) {
                                        artworks.remove(at: idx)
                                        updateAlbumsAfterArtworkDeletion(deletedArtworkId: artwork.id)
                                        saveArtworksToUserDefaults()
                                        saveAlbumsToUserDefaults()
                                    }
                                }, 
                                onEdit: { newTitle, newTags in
                                    if let idx = artworks.firstIndex(where: { $0.id == artwork.id }) {
                                        artworks[idx].title = newTitle
                                        artworks[idx].tags = newTags
                                        saveArtworksToUserDefaults()
                                    }
                                },
                                onArtworkChange: { newArtwork in
                                    selectedArtwork = newArtwork
                                }
                            )
                        }
                    }
                }
            }
            // Albumタブ時のみ右下に＋ボタン
            if showAlbum && !albums.isEmpty {
                Button(action: { showTagInput = true }) {
                    Text("#")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.black)
                        .clipShape(Circle())
                        .shadow(radius: 6)
                        .padding(.bottom, 32)
                        .padding(.trailing, 24)
                }
            }
        }
        .onAppear {
            loadArtworks()
            loadAlbumsFromUserDefaults()
        }
        .fullScreenCover(isPresented: $showPixivRedirect) {
            PixivRedirectView(
                pixivURL: pixivRedirectURL,
                artwork: pixivRedirectArtwork,
                onEdit: { newTitle, newTags in
                    if let artwork = pixivRedirectArtwork,
                       let idx = artworks.firstIndex(where: { $0.id == artwork.id }) {
                        artworks[idx].title = newTitle
                        artworks[idx].tags = newTags
                        saveArtworksToUserDefaults()
                    }
                },
                onDelete: {
                    if let artwork = pixivRedirectArtwork,
                       let idx = artworks.firstIndex(where: { $0.id == artwork.id }) {
                        artworks.remove(at: idx)
                        updateAlbumsAfterArtworkDeletion(deletedArtworkId: artwork.id)
                        saveArtworksToUserDefaults()
                        saveAlbumsToUserDefaults()
                    }
                    showPixivRedirect = false
                }
            )
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
    }
    
    // MARK: - Helper Functions
    
    func loadArtworks() {
        let key = "character_artworks_\(character.id.uuidString)"
        if let data = UserDefaults.standard.data(forKey: key),
           let decodedArtworks = try? JSONDecoder().decode([Artwork].self, from: data) {
            artworks = decodedArtworks
        }
    }
    
    func saveArtworksToUserDefaults() {
        let key = "character_artworks_\(character.id.uuidString)"
        if let encodedData = try? JSONEncoder().encode(artworks) {
            UserDefaults.standard.set(encodedData, forKey: key)
        }
    }
    
    private func saveAlbumsToUserDefaults() {
        let key = "artwork_albums_\(character.id.uuidString)"
        if let encodedData = try? JSONEncoder().encode(albums) {
            UserDefaults.standard.set(encodedData, forKey: key)
            print("[DEBUG] ArtworkScreen: アルバムをUserDefaultsに保存しました")
        }
    }
    
    private func loadAlbumsFromUserDefaults() {
        let key = "artwork_albums_\(character.id.uuidString)"
        if let data = UserDefaults.standard.data(forKey: key),
           let decodedAlbums = try? JSONDecoder().decode([ArtworkAlbum].self, from: data) {
            albums = decodedAlbums
            print("[DEBUG] ArtworkScreen: アルバムをUserDefaultsから読み込みました - 件数: \(albums.count)")
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
            print("[DEBUG] ArtworkScreen: アルバム削除完了 - 残りAlbum数: \(albums.count)")
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