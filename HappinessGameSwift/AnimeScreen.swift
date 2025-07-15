// swiftlint:disable file_length
import SwiftUI
import PhotosUI
import UIKit
import Foundation
import Photos
import AVFoundation
import AVKit

// Removed duplicate typealias - now defined in ArtworkScreen.swift

fileprivate func daysInMonth(_ month: Int) -> Int {
    let calendar = Calendar.current
    let dateComponents = DateComponents(year: 2000, month: month)
    let date = calendar.date(from: dateComponents) ?? Date()
    return calendar.range(of: .day, in: .month, for: date)?.count ?? 30
}

// アニメデータ管理用のObservableObject
class AnimeManager: ObservableObject {
    @Published var animes: [Anime] = []
    
    init() {
        loadAnimes()
    }
    
    func loadAnimes() {
        if let data = UserDefaults.standard.data(forKey: "animes"),
           let decoded = try? JSONDecoder().decode([Anime].self, from: data) {
            print("[DEBUG] loadAnimes: 読み込んだアニメ数=\(decoded.count)")
            for a in decoded { print("[DEBUG] アニメID=\(a.id), title=\(a.title), customFields=\(String(describing: a.customFields))") }
            animes = decoded
        } else {
            print("[DEBUG] loadAnimes: データなし or デコード失敗")
        }
    }
    
    func saveAnimes() {
        if let data = try? JSONEncoder().encode(animes) {
            UserDefaults.standard.set(data, forKey: "animes")
            print("[DEBUG] saveAnimes: 保存アニメ数=\(animes.count)")
            for a in animes { print("[DEBUG] 保存アニメID=\(a.id), title=\(a.title), customFields=\(String(describing: a.customFields))") }
            
            // Firebaseにも同期（現在のユーザープロファイルが存在する場合）
            if let profileData = UserDefaults.standard.data(forKey: "currentUserProfile"),
               let userProfile = try? JSONDecoder().decode(UserProfile.self, from: profileData) {
                print("アニメ変更のFirebase同期開始")
                FirebaseManager.shared.saveUserProfile(userProfile) { result in
                    switch result {
                    case .success():
                        print("✅ アニメ変更のFirebase同期成功")
                    case .failure(let error):
                        print("❌ アニメ変更のFirebase同期エラー: \(error)")
                    }
                }
            }
        } else {
            print("[DEBUG] saveAnimes: エンコード失敗")
        }
    }
    
    func updateAnime(_ updatedAnime: Anime) {
        print("[DEBUG] updateAnime: 更新アニメID=\(updatedAnime.id), title=\(updatedAnime.title), customFields=\(String(describing: updatedAnime.customFields))")
        if let idx = animes.firstIndex(where: { $0.id == updatedAnime.id }) {
            animes[idx] = updatedAnime
            saveAnimes()
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        } else {
            print("[DEBUG] updateAnime: アニメID見つからず")
        }
    }
    
    func addAnime(_ anime: Anime) {
        let exists = animes.contains { $0.id == anime.id }
        print("[DEBUG] addAnime: 追加アニメID=\(anime.id), title=\(anime.title), customFields=\(String(describing: anime.customFields)), exists=\(exists)")
        if !exists {
            animes.append(anime)
            saveAnimes()
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }
    
    // UI更新用のメソッド
    func refreshUI() {
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
}

// カスタムフィールド用構造体
struct AnimeCustomField: Hashable, Codable {
    var name: String
    var value: String
}

enum WatchStatus: String, Codable, CaseIterable {
    case none = "なし"
    case watching = "視聴中"
    case willWatch = "後で見る"
    case watchAgain = "もう一度見る"
    case thisTerm = "今期"
}

struct Anime: Identifiable, Hashable, Equatable, Codable {
    let id: UUID
    var imageIdentifier: String?
    var backgroundImagePath: String?
    var title: String
    var hashtag: String
    var releaseDate: Date
    var customFields: [AnimeCustomField]?
    var watchStatus: WatchStatus = .none  // 後方互換性のため残す
    var watchStatuses: [WatchStatus] = []  // 複数選択用の新しいフィールド
    // 必要に応じて他の属性も追加可能
    static func == (lhs: Anime, rhs: Anime) -> Bool {
        lhs.id == rhs.id
    }
    enum CodingKeys: String, CodingKey {
        case id, imageIdentifier, backgroundImagePath, title, hashtag, releaseDate, customFields, watchStatus, watchStatuses
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(hashtag, forKey: .hashtag)
        try container.encode(releaseDate, forKey: .releaseDate)
        try container.encodeIfPresent(imageIdentifier, forKey: .imageIdentifier)
        try container.encodeIfPresent(backgroundImagePath, forKey: .backgroundImagePath)
        try container.encodeIfPresent(customFields, forKey: .customFields)
        try container.encode(watchStatus, forKey: .watchStatus)
        try container.encode(watchStatuses, forKey: .watchStatuses)
    }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        hashtag = try container.decode(String.self, forKey: .hashtag)
        releaseDate = try container.decode(Date.self, forKey: .releaseDate)
        imageIdentifier = try? container.decodeIfPresent(String.self, forKey: .imageIdentifier)
        backgroundImagePath = try? container.decodeIfPresent(String.self, forKey: .backgroundImagePath)
        customFields = try? container.decodeIfPresent([AnimeCustomField].self, forKey: .customFields)
        watchStatus = (try? container.decode(WatchStatus.self, forKey: .watchStatus)) ?? .none
        
        // watchStatusesを読み込む。古いデータの場合は、watchStatusから移行
        if let statuses = try? container.decode([WatchStatus].self, forKey: .watchStatuses) {
            watchStatuses = statuses
        } else if watchStatus != .none {
            // 後方互換性: 古いデータの場合、watchStatusから配列を作成
            watchStatuses = [watchStatus]
        } else {
            watchStatuses = []
        }
    }
    init(id: UUID, imageIdentifier: String?, backgroundImagePath: String? = nil, title: String, hashtag: String, releaseDate: Date, customFields: [AnimeCustomField]? = nil, watchStatus: WatchStatus = .none, watchStatuses: [WatchStatus] = []) {
        self.id = id
        self.imageIdentifier = imageIdentifier
        self.backgroundImagePath = backgroundImagePath
        self.title = title
        self.hashtag = hashtag
        self.releaseDate = releaseDate
        self.customFields = customFields
        self.watchStatus = watchStatus
        self.watchStatuses = watchStatuses.isEmpty && watchStatus != .none ? [watchStatus] : watchStatuses
    }
}

struct AnimeScreen: View {
    @EnvironmentObject var animeManager: AnimeManager
    @EnvironmentObject var mainTab: MainTabSelection
    @State private var showAddSheet = false
    @State private var selectedTab: AnimeTab = .all
    @State private var selectedAnime: Anime? = nil
    @State private var showMenu = false
    @State private var showNavigationMenu = false
    
    enum AnimeTab: String, CaseIterable {
        case all = "すべて"
        case watching = "視聴中"
        case thisTerm = "今期"
        case willWatch = "視聴予定"
        case watchAgain = "再視聴"
    }
    
    var filteredAnimes: [Anime] {
        // Filter out animes without titles first
        let animesWithTitles = animeManager.animes.filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        switch selectedTab {
        case .all:
            return animesWithTitles
        case .watching:
            return animesWithTitles.filter { $0.watchStatuses.contains(.watching) }
        case .willWatch:
            return animesWithTitles.filter { $0.watchStatuses.contains(.willWatch) }
        case .watchAgain:
            return animesWithTitles.filter { $0.watchStatuses.contains(.watchAgain) }
        case .thisTerm:
            return animesWithTitles.filter { $0.watchStatuses.contains(.thisTerm) }
        }
    }

    var body: some View {
        ZStack {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    HStack {
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showNavigationMenu = true
                            }
                        }) {
                        Image(systemName: "line.horizontal.3")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.black)
                    }
                    Spacer()
                    Button(action: { showAddSheet = true }) {
                        Text("アニメを追加")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.purple, Color.purple.opacity(0.7)]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(20)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 7) // タブとボタンの間隔を7px追加
                // タブUI
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(AnimeTab.allCases, id: \ .self) { tab in
                            Button(action: { selectedTab = tab }) {
                                Text(tab.rawValue)
                                    .font(.system(size: 16, weight: .regular))
                                    .foregroundColor(selectedTab == tab ? .white : .black)
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 8)
                                    .background(
                                        Capsule()
                                            .fill(selectedTab == tab ? Color(.darkGray) : Color(.systemGray5))
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                
                ScrollView {
                    VStack(spacing: 0) {
                        // 広告バナーをアニメ一覧と一緒にスクロール
                        FirebaseAdView(placement: "anime")
                            .padding(.top, 8)
                            .padding(.bottom, 0)
                        ForEach(filteredAnimes, id: \.id) { anime in
                            Button(action: {
                                selectedAnime = anime
                            }) {
                                AnimeRow(anime: anime, animeManager: animeManager)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.bottom, 75)
                }
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddAnimeSheet(animes: $animeManager.animes)
                .environmentObject(animeManager)
        }
        .fullScreenCover(item: $selectedAnime) { anime in
            AnimeDetailView(anime: Binding(
                get: { anime },
                set: { newAnime in
                    if let idx = animeManager.animes.firstIndex(where: { $0.id == anime.id }) {
                        animeManager.animes[idx] = newAnime
                        animeManager.updateAnime(newAnime)
                    }
                    selectedAnime = newAnime
                }
            ), animes: $animeManager.animes, onDismiss: {
                selectedAnime = nil
                animeManager.refreshUI()
            })
            .environmentObject(animeManager)
        }
        
        // サイドメニューをオーバーレイ
        if showMenu {
            SideMenuView(isShowing: $showMenu)
                .transition(.move(edge: .leading))
                .zIndex(1)
        }
    }
    .overlay(
        Group {
            if showNavigationMenu {
                NavigationMenuView(isPresented: $showNavigationMenu)
                    .transition(.opacity)
                    .zIndex(2)
            }
        }
    )
    }
}

// アニメ一覧の1行
struct AnimeRow: View {
    let anime: Anime
    @ObservedObject var animeManager: AnimeManager
    
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            if let imageIdentifier = anime.imageIdentifier, let image = loadImageFromPath(imageIdentifier) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 183, height: 99)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 183, height: 99)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(anime.title)
                    .font(.system(size: 15.5, weight: .semibold))
                    .foregroundColor(.black)
                    .frame(height: 20)
                Text("#" + anime.hashtag)
                    .font(.system(size: 12.8, weight: .regular))
                    .foregroundColor(.gray)
                    .frame(height: 20)
            }
            .offset(y: -15)
            Spacer()
        }
        .padding(.vertical, 6)
        .background(Color.clear)
        .contentShape(Rectangle())
    }
}

struct AnimeArtworkScreen: View {
    @Binding var anime: Anime
    @Binding var animes: [Anime]
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
    @State private var deletingArtworkID: UUID? = nil
    @State private var showEditMenu = false
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
                    // アニメ名
                    HStack {
                        Spacer().frame(width: 0)
                        Text(anime.title)
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
                                                    if let imagePath = firstArtwork.imagePath, let uiImage = loadImageFromPath(imagePath) {
                                                        Image(uiImage: uiImage)
                                                            .resizable()
                                                            .aspectRatio(contentMode: .fit)
                                                            .frame(width: geometry.size.width, height: 233)
                                                            .clipped()
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
                                        print("[DEBUG] AnimeArtworkScreen: Albumから画像削除 - ID: \(deletedArtwork.id)")
                                        
                                        // Albumタブの画像リストも更新
                                        updateAlbumsAfterArtworkDeletion(deletedArtworkId: deletedArtwork.id)
                                        
                                        saveArtworksToUserDefaults()
                                        print("[DEBUG] AnimeArtworkScreen: UserDefaultsに保存しました")
                                    }
                                },
                                onArtworkEdited: { editedArtwork in
                                    // 親画面のartworksリストを更新
                                    if let idx = artworks.firstIndex(where: { $0.id == editedArtwork.id }) {
                                        artworks[idx] = editedArtwork
                                        print("[DEBUG] AnimeArtworkScreen: Albumから画像編集 - ID: \(editedArtwork.id)")
                                        
                                        // Albumタブの画像リストも更新
                                        updateAlbumsAfterArtworkEdit(editedArtwork: editedArtwork)
                                        
                                        saveArtworksToUserDefaults()
                                        print("[DEBUG] AnimeArtworkScreen: UserDefaultsに保存しました")
                                    }
                                }
                            )
                        }
                    } else {
                        ScrollView {
                            VStack(spacing: 32) {
                                ForEach(artworks, id: \ .id) { artwork in
                                    VStack(alignment: .leading, spacing: 0) {
                                        GeometryReader { geometry in
                                            ZStack {
                                                Color.white
                                                if let imagePath = artwork.imagePath, let uiImage = loadImageFromPath(imagePath) {
                                                    Image(uiImage: uiImage)
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fit)
                                                        .frame(width: geometry.size.width, height: 233)
                                                        .clipped()
                                                } else if let pixivURL = artwork.pixivURL {
                                                    PixivThumbnailView(pixivURL: pixivURL)
                                                        .frame(width: geometry.size.width)
                                                        .aspectRatio(contentMode: .fit)
                                                } else {
                                                    RoundedRectangle(cornerRadius: 0, style: .continuous)
                                                        .fill(Color.gray.opacity(0.3))
                                                        .frame(width: geometry.size.width, height: 233)
                                                }
                                            }
                                            .frame(width: geometry.size.width, height: 233)
                                            .clipped()
                                            .padding(.bottom, 0)
                                        }
                                            .frame(height: 233)
                                            HStack(alignment: .center, spacing: 12) {
                                                if let imageIdentifier = anime.imageIdentifier, let image = loadImageFromPath(imageIdentifier) {
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
                                                            Image(systemName: "film")
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
                                    
                                    if let imagePath = artwork.imagePath, let uiImage = loadImageFromPath(imagePath) {
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
                                    .padding(.vertical, 12)
                                    .background(Color.black)
                                    .cornerRadius(10)
                            }
                            Spacer()
                        }
                        .padding(.bottom, max(geometry.safeAreaInsets.bottom, 60))
                    }
                    
                    // 編集メニュー
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
                        .cornerRadius(20)
                        .shadow(radius: 20)
                        .frame(maxWidth: 300)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    
                // --- カスタムダイアログ ---
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
                                    artworks[idx] = Artwork(id: artworks[idx].id, characterId: artworks[idx].characterId, imagePath: artworks[idx].imagePath, title: editText, tags: artworks[idx].tags, createdAt: artworks[idx].createdAt)
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
                // --- END カスタムダイアログ ---
                
                // 全画面画像表示
                if showFullscreenImage {
                    ZStack {
                        // 背景を真っ暗に
                        Color.black
                            .edgesIgnoringSafeArea(.all)
                        
                        // 画像
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
                        
                        // 閉じるボタン
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
            
            // showEditTags dialog
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
                                let newTags = editText.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                                artworks[idx] = Artwork(id: artworks[idx].id, characterId: artworks[idx].characterId, imagePath: artworks[idx].imagePath, title: artworks[idx].title, tags: newTags, createdAt: artworks[idx].createdAt, pixivURL: artworks[idx].pixivURL, twitterURL: artworks[idx].twitterURL)
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
            }
        }
    }
    
    private func saveArtwork() {
        guard let image = selectedImage, let _ = image.jpegData(compressionQuality: 0.8) else { return }
        let tags = photoTags.isEmpty ? [] : photoTags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        // 画像を保存
        let fileName = "anime_artwork_\(UUID().uuidString).png"
        let path = saveImageToDocuments(image, fileName: fileName)
        let newArtwork = Artwork(id: UUID(), characterId: anime.id, imagePath: path, title: photoTitle, tags: tags, createdAt: Date())
        artworks.insert(newArtwork, at: 0)
        saveArtworksToUserDefaults()
        selectedImage = nil
        photoTitle = ""
        photoTags = ""
        activeSheet = nil
    }
    
    private func loadArtworks() {
        let key = "anime_artworks_\(anime.id.uuidString)"
        if let data = UserDefaults.standard.data(forKey: key),
           let decodedArtworks = try? JSONDecoder().decode([Artwork].self, from: data) {
            artworks = decodedArtworks
        }
    }
    
    private func saveArtworksToUserDefaults() {
        let key = "anime_artworks_\(anime.id.uuidString)"
        if let encodedData = try? JSONEncoder().encode(artworks) {
            UserDefaults.standard.set(encodedData, forKey: key)
        }
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
        print("[DEBUG] AnimeArtworkScreen: Album更新完了 - 残りAlbum数: \(albums.count)")
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
        print("[DEBUG] AnimeArtworkScreen: Album編集更新完了 - 残りAlbum数: \(albums.count)")
    }
    
    private func savePixivArtwork(pixivURL: String, title: String, imageURL: String?, tags: String) {
        print("[DEBUG] savePixivArtwork開始 - URL: \(pixivURL), title: \(title), tags: \(tags)")
        let tagsArray = tags.isEmpty ? [] : tags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        let newArtwork = Artwork(
            id: UUID(),
            characterId: anime.id,
            imagePath: nil,  // Pixiv作品は画像パスではなくURLを使用
            title: title,
            tags: tagsArray,
            createdAt: Date(),
            pixivURL: pixivURL,
            twitterURL: nil
        )
        
        print("[DEBUG] 新しいPixivアートワーク作成 - ID: \(newArtwork.id)")
        artworks.insert(newArtwork, at: 0)
        print("[DEBUG] artworks配列に追加 - 現在の総数: \(artworks.count)")
        saveArtworksToUserDefaults()
        print("[DEBUG] UserDefaultsに保存完了")
        
        // フォームをリセット
        photoTitle = ""
        photoTags = ""
        activeSheet = nil
    }
}

struct AnimeVideoRowView: View {
    let video: MemoryVideo
    let anime: Anime
    let playingVideoId: UUID?
    let onPlay: () -> Void
    let onClose: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if playingVideoId == video.id {
                VideoInlinePlayer(video: video, onClose: onClose)
                    .frame(width: UIScreen.main.bounds.width * 0.9, height: (UIScreen.main.bounds.width * 0.9) * 9 / 16)
                    .cornerRadius(20)
            } else {
                VideoThumbnailPlayer(video: video, isInModal: false, onTap: onPlay)
                    .frame(width: UIScreen.main.bounds.width * 0.9, height: (UIScreen.main.bounds.width * 0.9) * 9 / 16)
                    .cornerRadius(20)
            }
            HStack(alignment: .center, spacing: 12) {
                if let imageIdentifier = anime.imageIdentifier, let image = loadImageFromPath(imageIdentifier) {
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
                            Image(systemName: "film")
                                .font(.system(size: 20))
                                .foregroundColor(.gray)
                        )
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(video.title)
                        .font(.headline)
                    if !video.tags.isEmpty {
                        Text("#" + video.tags.joined(separator: " #"))
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 24)
    }
}

struct AnimeVideoScreen: View {
    @Binding var anime: Anime
    @Binding var animes: [Anime]
    @Environment(\.presentationMode) var presentationMode
    @State private var videos: [MemoryVideo] = []
    @State private var showAddSheet = false
    @State private var selectedVideoURL: URL? = nil
    @State private var videoTitle: String = ""
    @State private var videoTags: String = ""
    @State private var showAlbum = false
    @State private var showTagInput = false
    @State private var newTag: String = ""
    @State private var filteredTags: [String] = []
    @State private var selectedVideo: MemoryVideo? = nil
    @State private var showEditTitle = false
    @State private var showEditTags = false
    @State private var editText = ""
    @State private var showDeleteAlert = false
    @State private var deletingVideoID: UUID? = nil
    @State private var selectedThumbnailData: Data? = nil
    @State private var expandedVideo: MemoryVideo? = nil
    @State private var playingVideoId: UUID? = nil
    @State private var albums: [Album] = []
    @State private var selectedAlbum: Album? = nil

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
                    // アニメ名
                    HStack {
                        Spacer().frame(width: 0)
                        Text(anime.title)
                            .font(.system(size: 25, weight: .bold))
                            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 2)
                            .offset(x: -15)
                        Spacer()
                    }
                    // Uploadボタン（右端に揃える）
                    Button(action: { showAddSheet = true }) {
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
                            Text("Video")
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
                // 動画リスト or Album
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
                                            if let firstVideo = album.videos.first, let thumbnailData = firstVideo.thumbnailData, let uiImage = UIImage(data: thumbnailData) {
                                                GeometryReader { geometry in
                                                    Image(uiImage: uiImage)
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fit)
                                                        .frame(width: geometry.size.width, height: 233)
                                                        .clipped()
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
                            AlbumVideoListScreen(
                                videos: album.videos, 
                                tag: album.tag,
                                onVideoDeleted: { deletedVideo in
                                    // 動画リストから削除
                                    if let idx = videos.firstIndex(where: { $0.id == deletedVideo.id }) {
                                        videos.remove(at: idx)
                                        print("[DEBUG] AnimeScreen: Albumから動画削除 - ID: \(deletedVideo.id)")
                                        
                                        // Albumタブの動画リストも更新
                                        updateAlbumsAfterVideoDeletion(deletedVideoId: deletedVideo.id)
                                        
                                        saveVideosToUserDefaults()
                                        print("[DEBUG] AnimeScreen: UserDefaultsに保存しました")
                                    }
                                }
                            )
                        }
                    } else {
                        ScrollView {
                            VStack(spacing: 0) {
                                Spacer().frame(height: 5)
                                ForEach(Array(videos.enumerated()), id: \ .element.id) { idx, video in
                                    if idx > 0 {
                                        Spacer().frame(height: 35)
                                    }
                                    Button(action: {
                                        selectedVideo = video
                                    }) {
                                        HStack(alignment: .top, spacing: 16) {
                                            if let thumbnailData = video.thumbnailData, let uiImage = UIImage(data: thumbnailData) {
                                                Image(uiImage: uiImage)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fit)
                                                    .frame(width: 183, height: 109)
                                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                                    .clipped()
                                            } else if let youtubeThumbnailURL = video.youtubeThumbnailURL {
                                                AsyncImage(url: URL(string: youtubeThumbnailURL)) { image in
                                                    image
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fit)
                                                        .frame(width: 183, height: 109)
                                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                                        .clipped()
                                                } placeholder: {
                                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                        .fill(Color.gray.opacity(0.3))
                                                        .frame(width: 183, height: 109)
                                                        .overlay(
                                                            ProgressView()
                                                        )
                                                }
                                            } else {
                                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                    .fill(Color.gray.opacity(0.3))
                                                    .frame(width: 183, height: 109)
                                            }
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(video.title)
                                                    .font(.system(size: 16.5, weight: .semibold))
                                                    .foregroundColor(.black)
                                                    .padding(.vertical, 8)
                                                Text(video.tags.isEmpty ? "#nakajimaginsei" : "#" + video.tags.joined(separator: " #"))
                                                    .font(.system(size: 13.8, weight: .regular))
                                                    .foregroundColor(.gray)
                                                    .padding(.vertical, 2)
                                            }
                                            .frame(height: 50, alignment: .leading)
                                            .padding(.top, 3)
                                            .padding(.leading, 8)
                                            Spacer()
                                            Button(action: {
                                                selectedVideo = video
                                                showEditTitle = true // 必要に応じてActionSheetや編集処理
                                            }) {
                                                Image(systemName: "ellipsis.vertical")
                                                    .font(.system(size: 23))
                                                    .foregroundColor(.black)
                                                    .padding(.trailing, 8)
                                            }
                                        }
                                        .padding(.leading, 8)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .fullScreenCover(item: $selectedVideo) { video in
                            VideoPlayerScreen(
                                video: video,
                                character: nil,
                                anime: anime,
                                allVideos: videos,
                                onDelete: {
                                    if let idx = videos.firstIndex(where: { $0.id == video.id }) {
                                        videos.remove(at: idx)
                                        saveVideosToUserDefaults()
                                    }
                                    selectedVideo = nil
                                }
                            )
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
                                let tagVideos = videos.filter { $0.tags.contains(where: { $0 == tag }) }
                                if !tagVideos.isEmpty {
                                    albums.append(Album(tag: tag, videos: tagVideos))
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
        }
        .onAppear {
            loadVideos()
        }
        .sheet(isPresented: $showAddSheet) {
            AddVideoView(selectedVideoURL: $selectedVideoURL, videoTitle: $videoTitle, videoTags: $videoTags, selectedThumbnailData: $selectedThumbnailData, onSave: {
                if selectedVideoURL != nil && !videoTitle.trimmingCharacters(in: .whitespaces).isEmpty && !videoTags.trimmingCharacters(in: .whitespaces).isEmpty {
                    Task {
                        await saveVideo()
                    }
                }
            }, onYouTubeSave: { url, title, thumbnailURL, tags in
                saveYouTubeVideo(url: url, title: title, thumbnailURL: thumbnailURL, tags: tags)
            })
        }
    }
    
    private func saveVideo() async {
        guard let videoURL = selectedVideoURL else { return }
        let tags = videoTags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        
        // 動画ファイルをDocumentsディレクトリに保存
        let fileName = "anime_video_\(UUID().uuidString).mov"
        let documentsPath = saveVideoToDocuments(from: videoURL, fileName: fileName)
        
        // サムネイル生成
        var thumbnailData: Data? = selectedThumbnailData
        if thumbnailData == nil {
            let asset = AVURLAsset(url: videoURL)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            
            do {
                let cgImage = try await imageGenerator.image(at: CMTime(seconds: 1.0, preferredTimescale: 1))
                let uiImage = UIImage(cgImage: cgImage.image)
                thumbnailData = uiImage.jpegData(compressionQuality: 0.8)
            } catch {
                print("サムネイル生成に失敗: \(error)")
            }
        }
        
        let newVideo = MemoryVideo(id: UUID(), characterId: anime.id, videoPath: documentsPath, thumbnailData: thumbnailData, title: videoTitle, tags: tags, date: Date(), youtubeURL: nil, youtubeThumbnailURL: nil)
        videos.insert(newVideo, at: 0)
        saveVideosToUserDefaults()
        selectedVideoURL = nil
        videoTitle = ""
        videoTags = ""
        selectedThumbnailData = nil
        showAddSheet = false
    }
    
    private func saveVideoToDocuments(from url: URL, fileName: String) -> String {
        let fileManager = FileManager.default
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        guard let documentsURL = urls.first else { return "" }
        
        // アプリ専用のサブディレクトリを作成
        let appDirectoryURL = documentsURL.appendingPathComponent("AnirecoImages")
        
        do {
            // ディレクトリが存在しない場合は作成
            if !fileManager.fileExists(atPath: appDirectoryURL.path) {
                try fileManager.createDirectory(at: appDirectoryURL, withIntermediateDirectories: true, attributes: nil)
            }
            
            let fileURL = appDirectoryURL.appendingPathComponent(fileName)
            
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
            try fileManager.copyItem(at: url, to: fileURL)
            return "AnirecoImages/\(fileName)"
        } catch {
            print("動画保存エラー: \(error)")
            return ""
        }
    }
    
    private func loadVideos() {
        let key = "anime_videos_\(anime.id.uuidString)"
        if let data = UserDefaults.standard.data(forKey: key),
           let decodedVideos = try? JSONDecoder().decode([MemoryVideo].self, from: data) {
            videos = decodedVideos
        }
    }
    
    private func saveVideosToUserDefaults() {
        let key = "anime_videos_\(anime.id.uuidString)"
        if let encodedData = try? JSONEncoder().encode(videos) {
            UserDefaults.standard.set(encodedData, forKey: key)
            print("AnimeVideoScreen: UserDefaults保存完了 - 動画数: \(videos.count)")
        }
    }
    
    private func saveYouTubeVideo(url: String, title: String, thumbnailURL: String, tags: String) {
        let tagArray = tags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        
        // YouTube動画の場合はvideoPathは空文字列にする
        let newVideo = MemoryVideo(
            id: UUID(),
            characterId: anime.id,
            videoPath: "",
            thumbnailData: nil,
            title: title,
            tags: tagArray,
            date: Date(),
            youtubeURL: url,
            youtubeThumbnailURL: thumbnailURL
        )
        
        videos.insert(newVideo, at: 0)
        saveVideosToUserDefaults()
        showAddSheet = false
    }
    
    private func updateAlbumsAfterVideoDeletion(deletedVideoId: UUID) {
        // 各Albumから削除された動画を除去
        albums = albums.compactMap { album in
            let updatedVideos = album.videos.filter { $0.id != deletedVideoId }
            // 動画が1つも残っていない場合はAlbumを削除
            if updatedVideos.isEmpty {
                return nil
            }
            // 動画が残っている場合は更新されたAlbumを返す
            return Album(tag: album.tag, videos: updatedVideos)
        }
        print("[DEBUG] AnimeVideoScreen: Album更新完了 - 残りAlbum数: \(albums.count)")
    }
}

struct AnimeAboutView: View {
    @Binding var anime: Anime
    @Binding var animes: [Anime]
    let onClose: () -> Void
    @State private var animeDescription: String = ""
    @State private var editedTitle: String = ""
    @State private var editedHashtag: String = ""
    @State private var editedReleaseDate: Date = Date()
    @State private var editedWatchStatuses: Set<WatchStatus> = []
    @State private var isEditingProfile: Bool = false
    @State private var isEditingDescription: Bool = false
    @State private var showEditSelection: Bool = false
    @State private var showIconPicker: Bool = false
    @State private var iconPickerItem: PhotosPickerItem? = nil
    @State private var newIconImage: UIImage?
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var animeManager: AnimeManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // アニメアイコン
                    VStack(spacing: 12) {
                        Button(action: {
                            showIconPicker = true
                        }) {
                            if let imageIdentifier = anime.imageIdentifier, let image = loadImageFromPath(imageIdentifier) {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 100, height: 100)
                                    .clipShape(Circle())
                                    .overlay(
                                        Circle()
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                    .overlay(
                                        Circle()
                                            .fill(Color.black.opacity(0.5))
                                            .frame(width: 100, height: 100)
                                            .overlay(
                                                Image(systemName: "camera.fill")
                                                    .font(.system(size: 20))
                                                    .foregroundColor(.white)
                                            )
                                            .opacity(0)
                                    )
                            } else {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 100, height: 100)
                                    .overlay(
                                        VStack(spacing: 4) {
                                            Image(systemName: "film.fill")
                                                .font(.system(size: 40))
                                                .foregroundColor(.gray)
                                            Text("タップで追加")
                                                .font(.system(size: 10))
                                                .foregroundColor(.gray)
                                        }
                                    )
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 10)
                    
                    // プロフィールセクション
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("プロフィール")
                                .font(.system(size: 20, weight: .bold))
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 16)
                        
                        // プロフィール項目
                        VStack(spacing: 0) {
                            if isEditingProfile {
                                editableProfileRow(label: "タイトル", text: $editedTitle)
                                Divider().padding(.leading, 20)
                                editableProfileRow(label: "ハッシュタグ", text: $editedHashtag)
                                Divider().padding(.leading, 20)
                                statusSelectionRow(label: "ステータス", statuses: $editedWatchStatuses)
                            } else {
                                profileRow(label: "タイトル", value: anime.title)
                                Divider().padding(.leading, 20)
                                profileRow(label: "ハッシュタグ", value: anime.hashtag.isEmpty ? "未設定" : anime.hashtag)
                                Divider().padding(.leading, 20)
                                let statusText = anime.watchStatuses.filter { $0 != .none }.map { $0.rawValue }.joined(separator: "、")
                                profileRow(label: "ステータス", value: statusText.isEmpty ? "未設定" : statusText)
                            }
                        }
                        .background(Color.white)
                    }
                    
                    // 概要セクション
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("概要")
                                .font(.system(size: 20, weight: .bold))
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 32)
                        .padding(.bottom, 16)
                        
                        // 概要テキスト
                        if isEditingDescription {
                            ZStack(alignment: .topLeading) {
                                if animeDescription.isEmpty {
                                    Text("概要を入力してください...")
                                        .font(.system(size: 16))
                                        .foregroundColor(.gray)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 16)
                                }
                                
                                TextEditor(text: $animeDescription)
                                    .font(.system(size: 16))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .frame(minHeight: 200)
                                    .scrollContentBackground(.hidden)
                                    .background(Color.clear)
                            }
                            .background(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .padding(.horizontal, 20)
                        } else {
                            if animeDescription.isEmpty {
                                Text("概要が未設定です")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 16)
                            } else {
                                Text(animeDescription)
                                    .font(.system(size: 16))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 16)
                            }
                        }
                    }
                    
                    Spacer(minLength: 50)
                }
            }
            .background(Color(.systemGray6))
            .navigationBarTitle("About", displayMode: .inline)
            .navigationBarItems(
                leading: Button(action: {
                    saveAnime()
                    onClose()
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.black)
                        .font(.system(size: 20, weight: .bold))
                },
                trailing: Button(action: {
                    if isEditingProfile || isEditingDescription {
                        // 保存処理
                        saveAnime()
                        isEditingProfile = false
                        isEditingDescription = false
                    } else {
                        // 編集選択モーダルを表示
                        showEditSelection = true
                    }
                }) {
                    Text(isEditingProfile || isEditingDescription ? "保存" : "編集")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color.black)
                        .cornerRadius(8)
                }
            )
        }
        .onAppear {
            loadAnimeDescription()
            editedTitle = anime.title
            editedHashtag = anime.hashtag
            editedReleaseDate = anime.releaseDate
            editedWatchStatuses = Set(anime.watchStatuses)
        }
        .onDisappear {
            saveAnime()
        }
        .actionSheet(isPresented: $showEditSelection) {
            ActionSheet(
                title: Text("編集する項目を選択してください"),
                buttons: [
                    .default(Text("プロフィールを編集")) {
                        isEditingProfile = true
                    },
                    .default(Text("概要を編集")) {
                        isEditingDescription = true
                    },
                    .cancel(Text("キャンセル"))
                ]
            )
        }
        .sheet(isPresented: $showIconPicker) {
            PhotosPicker(selection: $iconPickerItem, matching: .images) {
                VStack(spacing: 20) {
                    Text("アイコンを選択")
                        .font(.headline)
                    
                    if let newIconImage = newIconImage {
                        Image(uiImage: newIconImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 150, height: 150)
                            .clipShape(Circle())
                    }
                    
                    Button("画像を選択") {
                        // PhotosPickerが自動で処理
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    
                    if newIconImage != nil {
                        Button("保存") {
                            saveNewIcon()
                            showIconPicker = false
                        }
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    
                    Button("キャンセル") {
                        showIconPicker = false
                        newIconImage = nil
                        iconPickerItem = nil
                    }
                    .foregroundColor(.red)
                }
                .padding()
            }
            .onChange(of: iconPickerItem) { newValue in
                if let newValue = newValue {
                    Task {
                        if let data = try? await newValue.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            newIconImage = image
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Helper Views
    private func profileRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .font(.system(size: 16))
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    private func editableProfileRow(label: String, text: Binding<String>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
            TextField("未設定", text: text)
                .font(.system(size: 16))
                .foregroundColor(.primary)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
    
    private func dateProfileRow(label: String, date: Binding<Date>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
            DatePicker("", selection: date, displayedComponents: [.date])
                .labelsHidden()
                .environment(\.locale, Locale(identifier: "ja_JP"))
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
    
    private func statusSelectionRow(label: String, statuses: Binding<Set<WatchStatus>>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
            
            HStack(spacing: 8) {
                ForEach([WatchStatus.watching, .willWatch, .watchAgain, .thisTerm], id: \.self) { status in
                    Button(action: {
                        if statuses.wrappedValue.contains(status) {
                            statuses.wrappedValue.remove(status)
                        } else {
                            statuses.wrappedValue.insert(status)
                        }
                    }) {
                        Text(status.rawValue)
                            .font(.system(size: 14))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(statuses.wrappedValue.contains(status) ? Color.blue : Color.gray.opacity(0.2))
                            .foregroundColor(statuses.wrappedValue.contains(status) ? .white : .primary)
                            .cornerRadius(8)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
    
    // MARK: - Helper Methods
    private func loadAnimeDescription() {
        // カスタムフィールドから"概要"フィールドを探す
        if let customFields = anime.customFields,
           let descriptionField = customFields.first(where: { $0.name == "概要" }) {
            animeDescription = descriptionField.value
        }
    }
    
    private func saveAnime() {
        guard let idx = animes.firstIndex(where: { $0.id == anime.id }) else { return }
        
        // 編集中の場合は編集内容を保存
        var updatedAnime = animes[idx]
        
        // プロフィール編集内容を常に保存
        updatedAnime.title = editedTitle
        updatedAnime.hashtag = editedHashtag
        updatedAnime.watchStatuses = Array(editedWatchStatuses)
        
        // 概要をカスタムフィールドに保存
        if updatedAnime.customFields == nil {
            updatedAnime.customFields = []
        }
        
        // 既存の"概要"フィールドを更新または新規作成
        if let index = updatedAnime.customFields?.firstIndex(where: { $0.name == "概要" }) {
            updatedAnime.customFields?[index].value = animeDescription
        } else {
            updatedAnime.customFields?.append(AnimeCustomField(name: "概要", value: animeDescription))
        }
        
        animes[idx] = updatedAnime
        animeManager.updateAnime(updatedAnime)
        
        // Bindingも更新
        anime = updatedAnime
    }
    
    // アイコン保存機能
    private func saveNewIcon() {
        guard let iconImage = newIconImage,
              let idx = animes.firstIndex(where: { $0.id == anime.id }) else { return }
        
        // 画像をDocumentsディレクトリに保存
        let fileName = "anime_icon_\(UUID().uuidString).png"
        if let savedPath = saveImageToDocuments(iconImage, fileName: fileName) {
            var updatedAnime = animes[idx]
            
            // 古いアイコンを削除
            if let oldPath = updatedAnime.imageIdentifier {
                try? FileManager.default.removeItem(atPath: oldPath)
            }
            
            // 新しいアイコンパスを設定
            updatedAnime.imageIdentifier = savedPath
            
            animes[idx] = updatedAnime
            animeManager.updateAnime(updatedAnime)
            
            // Bindingも更新
            anime = updatedAnime
        }
        
        newIconImage = nil
        iconPickerItem = nil
    }
    
    // 画像をDocumentsディレクトリに保存
    private func saveImageToDocuments(_ image: UIImage, fileName: String) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        
        let fileManager = FileManager.default
        let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
        guard let documentsURL = urls.first else { return nil }
        
        // アプリ専用のサブディレクトリを作成
        let appDirectoryURL = documentsURL.appendingPathComponent("AnirecoImages")
        
        do {
            // ディレクトリが存在しない場合は作成
            if !fileManager.fileExists(atPath: appDirectoryURL.path) {
                try fileManager.createDirectory(at: appDirectoryURL, withIntermediateDirectories: true, attributes: nil)
            }
            
            let fileURL = appDirectoryURL.appendingPathComponent(fileName)
            
            try data.write(to: fileURL)
            return "AnirecoImages/\(fileName)"
        } catch {
            print("画像保存エラー: \(error)")
            return nil
        }
    }
}
struct AddAnimeSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var animes: [Anime]
    @EnvironmentObject private var animeManager: AnimeManager
    @State private var title = ""
    @State private var hashtag = ""
    @State private var releaseDate = Date()
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var image: UIImage? = nil
    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var selectedDay: Int = Calendar.current.component(.day, from: Date())
    @State private var savedImagePath: String? = nil
    @State private var selectedWatchStatuses: Set<WatchStatus> = []
    var body: some View {
        NavigationView {
            Form {
                Section {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        HStack {
                            if let image = image {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 60, height: 60)
                                    .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Image(systemName: "film")
                                            .font(.system(size: 28))
                                            .foregroundColor(.gray)
                                    )
                            }
                            Text("画像を選択")
                                .foregroundColor(.blue)
                        }
                    }
                    .onChange(of: selectedItem) { newValue in
                        if let newItem = newValue {
                            Task {
                                if let data = try? await newItem.loadTransferable(type: Data.self), let uiImage = UIImage(data: data) {
                                    image = uiImage
                                    let fileName = "anime_icon_\(UUID().uuidString).png"
                                    if let path = saveImageToDocuments(uiImage, fileName: fileName) {
                                        savedImagePath = path
                                    }
                                }
                            }
                        }
                    }
                    TextField("タイトル", text: $title)
                    TextField("ハッシュタグ", text: $hashtag)
                }
                Section {
                    HStack {
                        Text("公開日")
                        Spacer()
                        Picker(selection: $selectedMonth, label: Text("月")) {
                            ForEach(1...12, id: \.self) { month in
                                Text("\(month)月").tag(month)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        Picker(selection: $selectedDay, label: Text("日")) {
                            ForEach(1...daysInMonth(selectedMonth), id: \.self) { day in
                                Text("\(day)日").tag(day)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                }
                Section(header: Text("視聴ステータス（複数選択可）")) {
                    ForEach(WatchStatus.allCases.filter { $0 != .none }, id: \.self) { status in
                        HStack {
                            Text(status.rawValue)
                            Spacer()
                            if selectedWatchStatuses.contains(status) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.blue)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.gray)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selectedWatchStatuses.contains(status) {
                                selectedWatchStatuses.remove(status)
                            } else {
                                selectedWatchStatuses.insert(status)
                            }
                        }
                    }
                }
                Button("追加") {
                    let calendar = Calendar.current
                    let year = calendar.component(.year, from: Date())
                    let date = calendar.date(from: DateComponents(year: year, month: selectedMonth, day: selectedDay)) ?? Date()
                    let newAnime = Anime(id: UUID(), imageIdentifier: savedImagePath, backgroundImagePath: nil, title: title, hashtag: hashtag, releaseDate: date, watchStatus: .none, watchStatuses: Array(selectedWatchStatuses))
                    animeManager.addAnime(newAnime)
                    dismiss()
                }
            }
        }
    }
}

// AnimeDetailViewの定義を追加
struct AnimeDetailView: View {
    @Binding var anime: Anime
    @Binding var animes: [Anime]
    var onDismiss: (() -> Void)? = nil
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var animeManager: AnimeManager
    
    @State private var showArtwork = false
    @State private var showVideo = false
    @State private var showAbout = false
    // 編集用の状態変数
    @State private var showEditTitleModal = false
    @State private var showEditReleaseDateModal = false
    @State private var showEditIconModal = false
    @State private var editTitle: String = ""
    @State private var editHashtag: String = ""
    @State private var editReleaseDate: Date = Date()
    @State private var iconPickerItem: PhotosPickerItem? = nil
    @State private var iconImage: UIImage? = nil
    @State private var tempIconImage: UIImage? = nil
    @State private var showEditWatchStatusModal = false
    @State private var editWatchStatuses: Set<WatchStatus> = []
    @State private var showEditBackgroundModal = false
    @State private var backgroundPickerItem: PhotosPickerItem? = nil
    @State private var backgroundImage: UIImage? = nil

    var body: some View {
        GeometryReader { geometry in
            let currentAnime = animeManager.animes.first(where: { $0.id == anime.id }) ?? anime
            let titleText = currentAnime.title
            ZStack(alignment: .topLeading) {
                // 背景画像
                if let imagePath = currentAnime.backgroundImagePath,
                   let uiImage = loadImageFromPath(imagePath) {
                    GeometryReader { geo in
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                    }
                    .ignoresSafeArea()
                    .overlay(Color.black.opacity(0.3).ignoresSafeArea())
                    .onTapGesture {
                        showEditBackgroundModal = true
                    }
                } else {
                    LinearGradient(
                        gradient: Gradient(colors: [Color(red: 0.4, green: 0.6, blue: 0.9), Color(red: 0.3, green: 0.5, blue: 0.8)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()
                    .onTapGesture {
                        showEditBackgroundModal = true
                    }
                }
                
                Button(action: {
                    if let onDismiss = onDismiss {
                        onDismiss()
                    } else {
                        presentationMode.wrappedValue.dismiss()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.white)
                            .font(.system(size: 18, weight: .medium))
                        Text("Back")
                            .foregroundColor(.white)
                            .font(.system(size: 17, weight: .medium))
                            .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 1)
                    }
                }
                .padding(.top, 24)
                .padding(.leading, 16)
                VStack {
                    Spacer().frame(height: 180 + 50)
                    ZStack {
                        if let imageIdentifier = currentAnime.imageIdentifier, let image = loadImageFromPath(imageIdentifier) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 120, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                                .shadow(radius: 8)
                        } else {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(Color.black.opacity(0.2))
                                .frame(width: 120, height: 120)
                                .shadow(radius: 8)
                                .overlay(
                                    Image(systemName: "film")
                                        .font(.system(size: 50))
                                        .foregroundColor(.white)
                                )
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { showEditIconModal = true }
                    // タイトル
                    Text(titleText)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 1)
                        .padding(.top, 20)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .onTapGesture {
                            editTitle = currentAnime.title
                            editHashtag = currentAnime.hashtag
                            showEditTitleModal = true
                        }
                    
                    // 視聴ステータス
                    VStack(spacing: 4) {
                        Text("ステータス")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                        if currentAnime.watchStatuses.isEmpty {
                            Text("なし")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.gray)
                        } else {
                            HStack(spacing: 8) {
                                ForEach(currentAnime.watchStatuses.filter { $0 != .none }, id: \.self) { status in
                                    Text(status.rawValue)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.blue)
                                        .cornerRadius(12)
                                }
                            }
                        }
                    }
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .onTapGesture {
                        editWatchStatuses = Set(currentAnime.watchStatuses)
                        showEditWatchStatusModal = true
                    }
                    
                    // ナビゲーションバー（下部メニュー）
                    HStack {
                        Spacer()
                        Button(action: { showArtwork = true }) {
                            VStack(spacing: 4) {
                                Image(systemName: "photo.on.rectangle")
                                    .foregroundColor(.white)
                                    .font(.system(size: 24))
                                Text("ArtWork").font(.caption2).foregroundColor(.white)
                            }
                            .frame(width: 80, height: 60)
                        }
                        .buttonStyle(PlainButtonStyle())
                        Spacer()
                        Button(action: { showVideo = true }) {
                            VStack(spacing: 4) {
                                Image(systemName: "video")
                                    .foregroundColor(.white)
                                    .font(.system(size: 24))
                                Text("Video").font(.caption2).foregroundColor(.white)
                            }
                            .frame(width: 80, height: 60)
                        }
                        .buttonStyle(PlainButtonStyle())
                        Spacer()
                        Button(action: { showAbout = true }) {
                            VStack(spacing: 4) {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.white)
                                    .font(.system(size: 24))
                                Text("About").font(.caption2).foregroundColor(.white)
                            }
                            .frame(width: 80, height: 60)
                        }
                        .buttonStyle(PlainButtonStyle())
                        Spacer()
                    }
                    .padding(.top, 40)
                    .fullScreenCover(isPresented: $showArtwork) {
                        AnimeArtworkScreen(anime: $anime, animes: $animes)
                    }
                    .fullScreenCover(isPresented: $showVideo) {
                        AnimeVideoScreen(anime: $anime, animes: $animes)
                    }
                    .fullScreenCover(isPresented: $showAbout) {
                        AnimeAboutView(anime: $anime, animes: $animes, onClose: { showAbout = false })
                            .environmentObject(animeManager)
                    }
                }
                .frame(width: geometry.size.width)
                .zIndex(1) // 背景画像よりも前面に配置
            }
        }
        .navigationBarHidden(true)
        // タイトル編集モーダル
        .sheet(isPresented: $showEditTitleModal) {
            VStack(spacing: 20) {
                Text("タイトルとハッシュタグを編集")
                    .font(.headline)
                VStack(spacing: 12) {
                    TextField("タイトル", text: $editTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    TextField("ハッシュタグ", text: $editHashtag)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                HStack {
                    Button("キャンセル") {
                        showEditTitleModal = false
                    }
                    Spacer()
                    Button("保存") {
                        guard let idx = animes.firstIndex(where: { $0.id == anime.id }) else { return }
                        var updatedAnime = animes[idx]
                        updatedAnime.title = editTitle
                        updatedAnime.hashtag = editHashtag
                        animes[idx] = updatedAnime
                        animeManager.updateAnime(updatedAnime)
                        showEditTitleModal = false
                    }
                    .disabled(editTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .padding(40)
        }
        // 公開日編集モーダル（無効化）
        // 視聴ステータス編集モーダル
        .sheet(isPresented: $showEditWatchStatusModal) {
            VStack(spacing: 20) {
                Text("視聴ステータスを選択（複数選択可）")
                    .font(.headline)
                VStack(spacing: 12) {
                    ForEach(WatchStatus.allCases.filter { $0 != .none }, id: \.self) { status in
                        Button(action: {
                            if editWatchStatuses.contains(status) {
                                editWatchStatuses.remove(status)
                            } else {
                                editWatchStatuses.insert(status)
                            }
                        }) {
                            HStack {
                                Text(status.rawValue)
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.black)
                                Spacer()
                                if editWatchStatuses.contains(status) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundColor(.gray)
                                }
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(editWatchStatuses.contains(status) ? Color.blue.opacity(0.1) : Color(.systemGray6))
                            )
                        }
                    }
                }
                HStack(spacing: 20) {
                    Button("キャンセル") {
                        showEditWatchStatusModal = false
                    }
                    .foregroundColor(.red)
                    
                    Button("保存") {
                        guard let idx = animes.firstIndex(where: { $0.id == anime.id }) else { return }
                        var updatedAnime = animes[idx]
                        updatedAnime.watchStatuses = Array(editWatchStatuses)
                        animes[idx] = updatedAnime
                        animeManager.updateAnime(updatedAnime)
                        showEditWatchStatusModal = false
                    }
                    .foregroundColor(.blue)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .padding(40)
        }
        // 背景画像編集モーダル
        .sheet(isPresented: $showEditBackgroundModal) {
            NavigationView {
                VStack(spacing: 20) {
                    Text("背景画像を選択")
                        .font(.headline)
                    
                    PhotosPicker(selection: $backgroundPickerItem, matching: .images) {
                        VStack {
                            if let backgroundImage = backgroundImage {
                                Image(uiImage: backgroundImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 200)
                                    .clipped()
                                    .cornerRadius(12)
                            } else if let imagePath = anime.backgroundImagePath,
                                      let uiImage = loadImageFromPath(imagePath) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 200)
                                    .clipped()
                                    .cornerRadius(12)
                            } else {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 200)
                                    .overlay(
                                        VStack {
                                            Image(systemName: "photo.fill")
                                                .font(.system(size: 50))
                                                .foregroundColor(.gray)
                                            Text("背景画像を選択")
                                                .foregroundColor(.gray)
                                        }
                                    )
                            }
                        }
                    }
                    .onChange(of: backgroundPickerItem) { newValue in
                        if let newItem = newValue {
                            Task {
                                if let data = try? await newItem.loadTransferable(type: Data.self),
                                   let uiImage = UIImage(data: data) {
                                    backgroundImage = uiImage
                                }
                            }
                        }
                    }
                    
                    Spacer()
                }
                .padding()
                .navigationBarTitle("背景画像", displayMode: .inline)
                .navigationBarItems(
                    leading: Button("キャンセル") {
                        backgroundImage = nil
                        showEditBackgroundModal = false
                    },
                    trailing: Button("保存") {
                        if let backgroundImage = backgroundImage {
                            // 画像をドキュメントディレクトリに保存
                            let fileName = "anime_bg_\(UUID().uuidString).png"
                            if let imagePath = saveImageToDocuments(backgroundImage, fileName: fileName) {
                                // アニメ情報を更新
                                guard let idx = animes.firstIndex(where: { $0.id == anime.id }) else { return }
                                var updatedAnime = animes[idx]
                                updatedAnime.backgroundImagePath = imagePath
                                animes[idx] = updatedAnime
                                animeManager.updateAnime(updatedAnime)
                            }
                        }
                        showEditBackgroundModal = false
                    }
                    .disabled(backgroundImage == nil)
                )
            }
        }
        // アイコン編集モーダル
        .sheet(isPresented: $showEditIconModal) {
            VStack {
                // ヘッダー部分
                HStack {
                    Spacer()
                    Button(action: { 
                        showEditIconModal = false
                        tempIconImage = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(.gray)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                
                VStack(spacing: 24) {
                    Text("アイコンを選択")
                        .font(.system(size: 20, weight: .bold))
                        .padding(.top, 16)
                    
                    PhotosPicker(selection: $iconPickerItem, matching: .images) {
                        ZStack {
                            if let tempIconImage = tempIconImage {
                                Image(uiImage: tempIconImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 150, height: 150)
                                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            } else if let imageIdentifier = anime.imageIdentifier, let image = loadImageFromPath(imageIdentifier) {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 150, height: 150)
                                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                            } else {
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 150, height: 150)
                                    .overlay(
                                        Image(systemName: "photo")
                                            .font(.system(size: 40))
                                            .foregroundColor(.gray)
                                    )
                            }
                        }
                    }
                    .onChange(of: iconPickerItem) { newValue in
                        if let newItem = newValue {
                            Task {
                                if let data = try? await newItem.loadTransferable(type: Data.self), let uiImage = UIImage(data: data) {
                                    tempIconImage = uiImage
                                    let fileName = "icon_\(UUID().uuidString).png"
                                    let imagePath = saveImageToDocuments(uiImage, fileName: fileName)
                                    
                                    guard let idx = animes.firstIndex(where: { $0.id == anime.id }) else { return }
                                    var updatedAnime = animes[idx]
                                    updatedAnime.imageIdentifier = imagePath
                                    animes[idx] = updatedAnime
                                    animeManager.updateAnime(updatedAnime)
                                    animeManager.refreshUI()
                                }
                            }
                        }
                    }
                    
                    Text("画像をタップして変更")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                    
                    Spacer()
                }
                .padding(.horizontal, 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(.systemBackground))
        }
    }
    
}
