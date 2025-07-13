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
struct ArtworkAlbum: Identifiable, Hashable, Equatable {
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
    @Environment(\.presentationMode) var presentationMode
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
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 0) {
                    // 戻るボタン
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.black)
                            .font(.system(size: 24, weight: .bold))
                            .padding(.leading, 8)
                            .offset(x: -19)
                    }
                    Spacer()
                    // キャラクター名
                    HStack {
                        Spacer().frame(width: 0)
                        Text(character.name)
                            .font(.system(size: 25, weight: .bold))
                            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 2)
                            .offset(x: -15)
                        Spacer()
                    }
                    // Uploadボタン（右端に揃える）
                    Button(action: { activeSheet = .addPhoto }) {
                        Text("Upload")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Color.black)
                            .cornerRadius(8)
                    }
                    .padding(.trailing, 16)
                }
                .frame(height: 56)
                .padding(.top, 8)
                .padding(.leading, 30)

                // タブバー - カプセル型デザイン（中央揃え）
                HStack {
                    Spacer()
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
                    Spacer()
                }
                .padding(.vertical, 8)
                
                // 画像リスト or Album
                ZStack {
                    if showAlbum {
                        ScrollView {
                            VStack(spacing: 4) {
                                Spacer().frame(height: 5)
                                // --- アルバムリスト ---
                                ForEach(albums) { album in
                                    Button(action: {
                                        selectedAlbum = album
                                    }) {
                                        VStack(alignment: .leading, spacing: 0) {
                                            if let firstArtwork = album.videos.first {
                                                GeometryReader { geometry in
                                                    if let imagePath = firstArtwork.imagePath, let uiImage = UIImage(contentsOfFile: imagePath) {
                                                        Image(uiImage: uiImage)
                                                            .resizable()
                                                            .aspectRatio(contentMode: .fit)
                                                            .frame(width: geometry.size.width, height: 233)
                                                    } else if let pixivURL = firstArtwork.pixivURL {
                                                        PixivThumbnailView(pixivURL: pixivURL)
                                                            .frame(width: geometry.size.width)
                                                            .aspectRatio(contentMode: .fit)
                                                    } else {
                                                        RoundedRectangle(cornerRadius: 0, style: .continuous)
                                                            .fill(Color.gray.opacity(0.3))
                                                            .frame(width: geometry.size.width, height: 233)
                                                    }
                                                }
                                                .frame(height: 233)
                                            } else {
                                                GeometryReader { geometry in
                                                    RoundedRectangle(cornerRadius: 0, style: .continuous)
                                                        .fill(Color.gray.opacity(0.3))
                                                        .frame(width: geometry.size.width, height: 233)
                                                }
                                                .frame(height: 233)
                                            }
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text("#" + album.tag)
                                                    .font(.system(size: 15.5, weight: .semibold))
                                                    .foregroundColor(.black)
                                            }
                                            .padding(.top, 8)
                                            .padding(.leading, 8)
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .fullScreenCover(item: $selectedAlbum) { album in
                            AlbumArtworkListScreenTemp(
                                artworks: album.videos, 
                                tag: album.tag,
                                onArtworkDeleted: { deletedArtwork in
                                    // 親画面のartworksリストから削除
                                    if let idx = artworks.firstIndex(where: { $0.id == deletedArtwork.id }) {
                                        artworks.remove(at: idx)
                                        print("[DEBUG] ArtworkScreen: Albumから画像削除 - ID: \(deletedArtwork.id)")
                                        
                                        // Albumタブの画像リストも更新
                                        updateAlbumsAfterArtworkDeletion(deletedArtworkId: deletedArtwork.id)
                                        
                                        saveArtworksToUserDefaults()
                                        print("[DEBUG] ArtworkScreen: UserDefaultsに保存しました")
                                    }
                                },
                                onArtworkEdited: { editedArtwork in
                                    // 親画面のartworksリストを更新
                                    if let idx = artworks.firstIndex(where: { $0.id == editedArtwork.id }) {
                                        artworks[idx] = editedArtwork
                                        print("[DEBUG] ArtworkScreen: Albumから画像編集 - ID: \(editedArtwork.id)")
                                        
                                        // Albumタブの画像リストも更新
                                        updateAlbumsAfterArtworkEdit(editedArtwork: editedArtwork)
                                        
                                        saveArtworksToUserDefaults()
                                        print("[DEBUG] ArtworkScreen: UserDefaultsに保存しました")
                                    }
                                }
                            )
                        }
                    } else {
                        ScrollView {
                            VStack(spacing: 32) {
                                ForEach(artworks, id: \.id) { artwork in
                                    VStack(alignment: .leading, spacing: 0) {
                                        GeometryReader { geometry in
                                            ZStack {
                                                Color.white
                                                // ローカル画像またはPixiv URL対応
                                                if let imagePath = artwork.imagePath, let uiImage = UIImage(contentsOfFile: imagePath) {
                                                    Image(uiImage: uiImage)
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fit)
                                                        .frame(width: geometry.size.width, height: 233)
                                                } else if let pixivURL = artwork.pixivURL {
                                                    PixivThumbnailView(pixivURL: pixivURL)
                                                        .frame(width: geometry.size.width)
                                                        .aspectRatio(contentMode: .fit)
                                                } else {
                                                    Rectangle()
                                                        .fill(Color.gray.opacity(0.2))
                                                        .frame(width: geometry.size.width, height: 233)
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
                                            .frame(width: geometry.size.width, height: 233)
                                            .clipped()
                                            .padding(.bottom, 0)
                                        }
                                        .frame(height: 233)
                                            HStack(alignment: .center, spacing: 12) {
                                                if let imageIdentifier = character.imageIdentifier, let image = UIImage(contentsOfFile: imageIdentifier) {
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
                                                activeSheet = .artworkDetail(artwork)
                                            }
                                        }
                                }
                            }
                            .padding(.top, 8)
                        }
                        .fullScreenCover(item: $selectedArtwork) { artwork in
                            ArtworkPlayerScreenTemp(artwork: artwork, onDelete: {
                                if let idx = artworks.firstIndex(where: { $0.id == artwork.id }) {
                                    artworks.remove(at: idx)
                                    saveArtworksToUserDefaults()
                                }
                            }, onEdit: { newTitle, newTags in
                                if let idx = artworks.firstIndex(where: { $0.id == artwork.id }) {
                                    artworks[idx].title = newTitle
                                    artworks[idx].tags = newTags
                                    saveArtworksToUserDefaults()
                                }
                            })
                        }
                    }
                }
            }
            // Albumタブ時のみ右下に＋ボタン
            if showAlbum {
                Button(action: { showTagInput = true }) {
                    Image(systemName: "number")
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
                        saveArtworksToUserDefaults()
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
                    Text("表示したいタグを入力")
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
                    // メインコンテンツ
                    VStack(spacing: 0) {
                        // ヘッダー
                        HStack {
                            Spacer()
                            Button(action: {
                                showEditMenu = true
                            }) {
                                Text("編集")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.blue)
                            }
                            .padding(.trailing, 20)
                        }
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                        
                        // 中央配置のコンテンツ
                        GeometryReader { innerGeometry in
                            ScrollView {
                                VStack(spacing: 24) {
                                    Spacer(minLength: 20)
                                    
                                    if let imagePath = artwork.imagePath, let uiImage = UIImage(contentsOfFile: imagePath) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(maxWidth: min(innerGeometry.size.width - 40, 600))
                                            .frame(maxHeight: innerGeometry.size.height * 0.6)
                                            .cornerRadius(24)
                                            .onTapGesture {
                                                withAnimation(.easeInOut(duration: 0.3)) {
                                                    showFullscreenImage = true
                                                }
                                            }
                                    } else if let pixivURL = artwork.pixivURL {
                                        PixivThumbnailView(pixivURL: pixivURL)
                                            .aspectRatio(contentMode: .fit)
                                            .frame(maxWidth: min(innerGeometry.size.width - 40, 600))
                                            .frame(maxHeight: innerGeometry.size.height * 0.6)
                                            .cornerRadius(24)
                                            .onTapGesture {
                                                pixivRedirectURL = pixivURL
                                                pixivRedirectArtwork = artwork
                                                showPixivRedirect = true
                                            }
                                    } else {
                                        Text("画像データがありません")
                                            .foregroundColor(.gray)
                                            .padding()
                                    }
                                    
                                    VStack(spacing: 16) {
                                        Text("タイトル: \(artwork.title)")
                                            .font(.headline)
                                        Text("タグ: \(artwork.tags.joined(separator: ", "))")
                                            .font(.subheadline)
                                        Text("ID: \(artwork.id.uuidString.prefix(8))")
                                            .font(.caption)
                                            .foregroundColor(.gray)
                                    }
                                    .padding(.horizontal, 20)
                                    
                                    Spacer(minLength: 100) // 閉じるボタンのためのスペース
                                }
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: innerGeometry.size.height)
                            }
                        }
                    }
                    // 下部に閉じるボタン（安全な位置に配置）
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: {
                                activeSheet = nil
                            }) {
                                Text("閉じる")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 32)
                                    .padding(.vertical, 10)
                                    .background(Color.black)
                                    .cornerRadius(10)
                                    .shadow(radius: 4)
                            }
                            Spacer()
                        }
                        .padding(.bottom, geometry.safeAreaInsets.bottom > 0 ? geometry.safeAreaInsets.bottom : 30)
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    Color.white.opacity(0),
                                    Color.white.opacity(0.9),
                                    Color.white
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 120)
                            .allowsHitTesting(false)
                        )
                    }
                // --- カスタムダイアログ ---
                if showEditMenu {
                    Color.black.opacity(0.25)
                        .edgesIgnoringSafeArea(.all)
                        .onTapGesture {
                            showEditMenu = false
                        }
                    VStack(spacing: 20) {
                        Text("編集する項目を選択")
                            .font(.headline)
                            .padding(.top, 20)
                        
                        VStack(spacing: 16) {
                            Button(action: {
                                editText = artwork.title
                                showEditMenu = false
                                showEditTitle = true
                            }) {
                                HStack {
                                    Image(systemName: "pencil")
                                    Text("タイトルを編集")
                                    Spacer()
                                }
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(10)
                            }
                            .foregroundColor(.primary)
                            
                            Button(action: {
                                editText = artwork.tags.joined(separator: ",")
                                showEditMenu = false
                                showEditTags = true
                            }) {
                                HStack {
                                    Image(systemName: "tag")
                                    Text("タグを編集")
                                    Spacer()
                                }
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(10)
                            }
                            .foregroundColor(.primary)
                            
                            Button(action: {
                                deletingArtworkID = artwork.id
                                showEditMenu = false
                                showDeleteAlert = true
                            }) {
                                HStack {
                                    Image(systemName: "trash")
                                    Text("画像を削除")
                                    Spacer()
                                }
                                .padding()
                                .background(Color.red.opacity(0.1))
                                .cornerRadius(10)
                            }
                            .foregroundColor(.red)
                        }
                        .padding(.horizontal, 20)
                        
                        Button(action: {
                            showEditMenu = false
                        }) {
                            Text("キャンセル")
                                .foregroundColor(.blue)
                                .padding(.vertical, 10)
                        }
                        .padding(.bottom, 20)
                    }
                    .background(Color.white)
                    .cornerRadius(18)
                    .shadow(radius: 16)
                    .frame(maxWidth: 340)
                    .padding(.horizontal, 32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
                if showEditTitle {
                    Color.black.opacity(0.25)
                        .edgesIgnoringSafeArea(.all)
                    VStack(spacing: 20) {
                        Text("タイトル名を編集")
                            .font(.headline)
                            .padding(.top, 12)
                        TextField("タイトル", text: $editText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 18))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        HStack(spacing: 24) {
                            Button(action: { showEditTitle = false }) {
                                Text("キャンセル")
                                    .foregroundColor(.blue)
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
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                    }
                    .background(Color.white)
                    .cornerRadius(18)
                    .shadow(radius: 16)
                    .frame(maxWidth: 340)
                    .padding(.horizontal, 32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
                if showDeleteAlert {
                    Color.black.opacity(0.25)
                        .edgesIgnoringSafeArea(.all)
                    VStack(spacing: 20) {
                        Text("本当に削除しますか？")
                            .font(.headline)
                            .padding(.top, 12)
                        HStack(spacing: 24) {
                            Button(action: {
                                showDeleteAlert = false
                                deletingArtworkID = nil
                            }) {
                                Text("キャンセル")
                                    .foregroundColor(.blue)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            }
                            Button(action: {
                                if let delID = deletingArtworkID,
                                   let idx = artworks.firstIndex(where: { $0.id == delID }) {
                                    artworks.remove(at: idx)
                                    saveArtworksToUserDefaults()
                                }
                                showDeleteAlert = false
                                deletingArtworkID = nil
                                activeSheet = nil
                            }) {
                                Text("削除")
                                    .foregroundColor(.red)
                                    .fontWeight(.bold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                    }
                    .background(Color.white)
                    .cornerRadius(18)
                    .shadow(radius: 16)
                    .frame(maxWidth: 340)
                    .padding(.horizontal, 32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
                // --- カスタムダイアログ終了 ---
                if showEditTags {
                    Color.black.opacity(0.25)
                        .edgesIgnoringSafeArea(.all)
                    VStack(spacing: 20) {
                        Text("タグを編集")
                            .font(.headline)
                            .padding(.top, 12)
                        TextField("タグ（カンマ区切り）", text: $editText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 18))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        HStack(spacing: 24) {
                            Button(action: { showEditTags = false }) {
                                Text("キャンセル")
                                    .foregroundColor(.blue)
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
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                    }
                    .background(Color.white)
                    .cornerRadius(18)
                    .shadow(radius: 16)
                    .frame(maxWidth: 340)
                    .padding(.horizontal, 32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
                // --- END カスタムダイアログ ---
                
                // 全画面画像表示
                if showFullscreenImage {
                    ZStack {
                        // 背景を真っ暗に
                        Color.black
                            .edgesIgnoringSafeArea(.all)
                        
                        // 画像
                        if let imagePath = artwork.imagePath, let uiImage = UIImage(contentsOfFile: imagePath) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else if let pixivURL = artwork.pixivURL {
                            PixivFullscreenView(pixivURL: pixivURL)
                                .aspectRatio(contentMode: .fit)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        
                        // 閉じるボタン（×）
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
            .fullScreenCover(isPresented: $showPixivRedirect) {
                PixivRedirectView(pixivURL: pixivRedirectURL)
            }
            } // GeometryReader
            }
        }
        .sheet(isPresented: $showTagInput) {
            VStack(spacing: 24) {
                Text("表示したいタグを入力")
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
    
    private func loadArtworks() {
        let key = "character_artworks_\(character.id.uuidString)"
        if let data = UserDefaults.standard.data(forKey: key),
           let decodedArtworks = try? JSONDecoder().decode([Artwork].self, from: data) {
            artworks = decodedArtworks
        }
    }
    
    private func saveArtworksToUserDefaults() {
        let key = "character_artworks_\(character.id.uuidString)"
        if let encodedData = try? JSONEncoder().encode(artworks) {
            UserDefaults.standard.set(encodedData, forKey: key)
        }
    }
    
    private func saveArtwork() {
        guard let image = selectedImage else { return }
        let tags = photoTags.isEmpty ? [] : photoTags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        // 画像を保存
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
    
    private func savePixivArtwork(pixivURL: String, title: String, imageURL: String?, tags: String) {
        let tagsArray = tags.isEmpty ? [] : tags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        let newArtwork = Artwork(
            id: UUID(),
            characterId: character.id,
            imagePath: nil,  // Pixiv作品は画像パスではなくURLを使用
            title: title,
            tags: tagsArray,
            createdAt: Date(),
            pixivURL: pixivURL,
            twitterURL: nil
        )
        
        artworks.insert(newArtwork, at: 0)
        saveArtworksToUserDefaults()
        
        // フォームをリセット
        photoTitle = ""
        photoTags = ""
        activeSheet = nil
    }
    
    private func updateAlbumsAfterArtworkDeletion(deletedArtworkId: UUID) {
        // 各Albumから削除された画像を除去
        albums = albums.compactMap { album in
            let updatedArtworks = album.videos.filter { $0.id != deletedArtworkId }
            // 画像が1つも残っていない場合はAlbumを削除
            if updatedArtworks.isEmpty {
                return nil
            }
            // 画像が残っている場合は更新されたAlbumを返す
            return ArtworkAlbum(tag: album.tag, videos: updatedArtworks, characterImageName: "")
        }
        print("[DEBUG] ArtworkScreen: Album更新完了 - 残りAlbum数: \(albums.count)")
    }
    
    private func updateAlbumsAfterArtworkEdit(editedArtwork: Artwork) {
        // 各Albumの該当画像を更新
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
        print("[DEBUG] ArtworkScreen: Album編集更新完了 - 残りAlbum数: \(albums.count)")
    }
}