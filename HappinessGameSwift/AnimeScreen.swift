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
    
    // 新規アニメを先頭に追加
    func addAnimeAtTop(_ anime: Anime) {
        var newAnime = anime
        newAnime.order = 0
        
        // 他のアニメの順番を1つずつ増やす
        for i in 0..<animes.count {
            animes[i].order += 1
        }
        
        animes.insert(newAnime, at: 0)
        saveAnimes()
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    // アニメの順番を移動
    func moveAnime(from source: IndexSet, to destination: Int) {
        animes.move(fromOffsets: source, toOffset: destination)
        
        // 順番を更新
        for (index, _) in animes.enumerated() {
            animes[index].order = index
        }
        
        saveAnimes()
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
    var order: Int = 0  // 表示順序用フィールド
    // 必要に応じて他の属性も追加可能
    static func == (lhs: Anime, rhs: Anime) -> Bool {
        lhs.id == rhs.id
    }
    enum CodingKeys: String, CodingKey {
        case id, imageIdentifier, backgroundImagePath, title, hashtag, releaseDate, customFields, watchStatus, watchStatuses, order
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
        try container.encode(order, forKey: .order)
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
        
        // orderを読み込む。古いデータの場合はデフォルト値を使用
        order = (try? container.decode(Int.self, forKey: .order)) ?? 0
    }
    init(id: UUID, imageIdentifier: String?, backgroundImagePath: String? = nil, title: String, hashtag: String, releaseDate: Date, customFields: [AnimeCustomField]? = nil, watchStatus: WatchStatus = .none, watchStatuses: [WatchStatus] = [], order: Int = 0) {
        self.id = id
        self.imageIdentifier = imageIdentifier
        self.backgroundImagePath = backgroundImagePath
        self.title = title
        self.hashtag = hashtag
        self.releaseDate = releaseDate
        self.customFields = customFields
        self.watchStatus = watchStatus
        self.watchStatuses = watchStatuses.isEmpty && watchStatus != .none ? [watchStatus] : watchStatuses
        self.order = order
    }
}

struct AnimeScreen: View {
    @EnvironmentObject var animeManager: AnimeManager
    @EnvironmentObject var mainTab: MainTabSelection
    @State private var showAddSheet = false
    @State private var selectedTab: AnimeTab = .all
    @State private var selectedAnime: Anime? = nil
    @State private var showNavigationMenu = false
    @State private var showAnimeOrderModal = false
    
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
        
        let result: [Anime]
        switch selectedTab {
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
        }
        
        // Sort by order
        return result.sorted(by: { $0.order < $1.order })
    }

    // ヘッダー部分
    private var headerView: some View {
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
        .padding(.bottom, 7)
    }
    
    // タブビュー部分
    private var tabView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(AnimeTab.allCases, id: \.self) { tab in
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
    }
    
    // アニメリスト部分
    private var animeListView: some View {
        ScrollView {
            VStack(spacing: 0) {
                FirebaseAdView(placement: "anime")
                    .padding(.top, 8)
                    .padding(.bottom, 0)
                
                if filteredAnimes.isEmpty {
                    VStack(spacing: 24) {
                        Spacer()
                        
                        Image(systemName: "tv")
                            .font(.system(size: 60))
                            .foregroundColor(.gray.opacity(0.6))
                        
                        VStack(spacing: 12) {
                            Text("アニメがまだありません")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.black)
                            
                            Text("右上の「+」ボタンからアニメを追加してください")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                        }
                        
                        Spacer()
                    }
                    .frame(maxWidth: .infinity, minHeight: 400)
                } else {
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
            }
            .padding(.bottom, 75)
        }
    }

    var body: some View {
        ZStack {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    headerView
                    tabView
                    animeListView
                }
            }
            
            // ナビゲーションメニューをオーバーレイ
            if showNavigationMenu {
                NavigationMenuView(
                    isPresented: $showNavigationMenu,
                    onShowCharacterOrder: nil,
                    onShowAnimeOrder: {
                        showAnimeOrderModal = true
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.opacity)
                .zIndex(2)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddAnimeSheet(animes: $animeManager.animes)
                .environmentObject(animeManager)
        }
        .sheet(isPresented: $showAnimeOrderModal, onDismiss: {
            // モーダルを閉じたときにデータを再読み込み
            animeManager.loadAnimes()
        }) {
            AnimeOrderModal()
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
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 183, height: 99)
                    .clipped()
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
    let onClose: () -> Void
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var animeManager: AnimeManager
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
    @State private var showDeleteArtworkAlbumAlert = false
    @State private var deletingArtworkAlbum: ArtworkAlbum? = nil
    
    // 最新のアニメ情報を取得
    private var currentAnime: Anime {
        animeManager.animes.first(where: { $0.id == anime.id }) ?? anime
    }
    
    // Enum to manage sheet presentations
    enum SheetType: Identifiable {
        case addPhoto
        case artworkDetail(Artwork)
        
        var id: String {
            switch self {
            case .addPhoto: return "addPhoto"
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
                onClose()
            }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.black)
                    .font(.system(size: 18, weight: .bold))
            }
            .buttonStyle(PlainButtonStyle())
            .frame(width: 60, alignment: .leading)
            
            Spacer()
            
            // タイトル
            Text(currentAnime.title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            // 追加ボタン
            Button(action: { activeSheet = .addPhoto }) {
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
        .padding(.vertical, 8) // Reduced from 12 to 8
        .background(Color.white)
    }
    
    // バナービュー
    var bannerView: some View {
        ZStack {
            // 画像のロード
            if let imageIdentifier = currentAnime.imageIdentifier, let image = loadImageFromPath(imageIdentifier) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: 120)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(maxWidth: .infinity, maxHeight: 120)
            }
            
            // ダークオーバーレイ
            Color.black.opacity(0.4)
                .frame(maxWidth: .infinity, maxHeight: 120)
            
            // テキストオーバーレイ
            VStack {
                Spacer()
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("アートワーク")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        Text(currentAnime.title)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 120)
    }
    
    // タブビュー
    var tabView: some View {
        HStack {
            HStack(spacing: 12) {
                Button(action: { showAlbum = false }) {
                    Text("ArtWork")
                        .font(.caption2)
                        .foregroundColor(!showAlbum ? .white : .black)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(!showAlbum ? Color(.darkGray) : Color(.systemGray5))
                        )
                }
                
                Button(action: { showAlbum = true }) {
                    Text("Album")
                        .font(.caption2)
                        .foregroundColor(showAlbum ? .white : .black)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
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
    }
    
    // コンテンツビュー
    var contentView: some View {
        ZStack {
                    if showAlbum {
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
                                        .padding()
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
                                    // --- アルバムリスト ---
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
                                                        .frame(width: 80, height: 80)
                                                        .clipped()
                                                        .cornerRadius(8)
                                                } else if let pixivURL = firstArtwork.pixivURL {
                                                    PixivThumbnailView(pixivURL: pixivURL)
                                                        .aspectRatio(contentMode: .fill)
                                                        .frame(width: 80, height: 80)
                                                        .clipped()
                                                        .cornerRadius(8)
                                                } else {
                                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                        .fill(Color.gray.opacity(0.3))
                                                        .frame(width: 80, height: 80)
                                                }
                                            } else {
                                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                    .fill(Color.gray.opacity(0.3))
                                                    .frame(width: 80, height: 80)
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
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(Color.white)
                                        .cornerRadius(8)
                                        .shadow(radius: 1)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 2)
                                }
                            }
                            .padding(.bottom, 20)
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
                                        saveAlbumsToUserDefaults()
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
                        }
                    } else {
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
                                        .padding()
                                        .background(Color.purple)
                                        .cornerRadius(25)
                                }
                                
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            ScrollView {
                                VStack(spacing: 32) {
                                    ForEach(artworks, id: \ .id) { artwork in
                                    Button(action: {
                                        if let pixivURL = artwork.pixivURL {
                                            pixivRedirectURL = pixivURL
                                            pixivRedirectArtwork = artwork
                                            showPixivRedirect = true
                                        } else {
                                            selectedArtwork = artwork
                                        }
                                    }) {
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
                                                        .clipped()
                                                } else {
                                                    RoundedRectangle(cornerRadius: 0, style: .continuous)
                                                        .fill(Color.gray.opacity(0.3))
                                                        .frame(width: UIScreen.main.bounds.width, height: 233)
                                                }
                                            }
                                            .frame(width: UIScreen.main.bounds.width, height: 233)
                                            .clipped()
                                            .padding(.bottom, 0)
                                            HStack(alignment: .center, spacing: 12) {
                                                if let imageIdentifier = currentAnime.imageIdentifier, let image = loadImageFromPath(imageIdentifier) {
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
                                }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.top, 8)
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
        }
    
    // メインコンテンツ
    var mainContent: some View {
        VStack(spacing: 0) {
            tabView
            contentView
        }
    }
    
    // フローティングボタン
    var floatingButton: some View {
        Group {
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
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // Header
                headerView
                    .zIndex(2) // ヘッダーを最前面に
                // Banner
                bannerView
                    .allowsHitTesting(false) // バナーのタップを無効化
                    .zIndex(1)
                // Main content
                mainContent
            }
            floatingButton
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
                Text("表示したいタグを入力")
                    .font(.headline)
                Text("同じタグからアルバムを作れます")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
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
                                showTagInput = false
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
                                    updateAlbumsAfterArtworkDeletion(deletedArtworkId: delID)
                                    saveArtworksToUserDefaults()
                                    saveAlbumsToUserDefaults()
                                }
                                showDeleteAlert = false
                                deletingArtworkID = nil
                                showTagInput = false
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
    
    private func saveAlbumsToUserDefaults() {
        let key = "anime_artwork_albums_\(anime.id.uuidString)"
        if let encodedData = try? JSONEncoder().encode(albums) {
            UserDefaults.standard.set(encodedData, forKey: key)
            print("[DEBUG] AnimeArtworkScreen: アルバムをUserDefaultsに保存しました")
        }
    }
    
    private func loadAlbumsFromUserDefaults() {
        let key = "anime_artwork_albums_\(anime.id.uuidString)"
        if let data = UserDefaults.standard.data(forKey: key),
           let decodedAlbums = try? JSONDecoder().decode([ArtworkAlbum].self, from: data) {
            albums = decodedAlbums
            print("[DEBUG] AnimeArtworkScreen: アルバムをUserDefaultsから読み込みました - 件数: \(albums.count)")
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
    
    private func deleteArtworkAlbum(_ album: ArtworkAlbum) {
        if let index = albums.firstIndex(where: { $0.id == album.id }) {
            albums.remove(at: index)
            saveAlbumsToUserDefaults()
            print("[DEBUG] AnimeArtworkScreen: アルバム削除完了 - 残りAlbum数: \(albums.count)")
        }
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
    let onClose: () -> Void
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject private var animeManager: AnimeManager
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
    @State private var activeAlert: ActiveAlert? = nil
    
    enum ActiveAlert: Identifiable {
        case deleteVideo(UUID)
        case deleteAlbum(Album)
        
        var id: String {
            switch self {
            case .deleteVideo: return "deleteVideo"
            case .deleteAlbum: return "deleteAlbum"
            }
        }
    }
    
    enum ActiveSheet: Identifiable {
        case editTitle(MemoryVideo)
        case editTags(MemoryVideo)
        case thumbnailPicker(MemoryVideo)
        case youtubeConfirmation(MemoryVideo)
        
        var id: String {
            switch self {
            case .editTitle: return "editTitle"
            case .editTags: return "editTags"
            case .thumbnailPicker: return "thumbnailPicker"
            case .youtubeConfirmation: return "youtubeConfirmation"
            }
        }
    }
    
    @State private var activeSheet: ActiveSheet? = nil
    @State private var selectedThumbnailData: Data? = nil
    @State private var expandedVideo: MemoryVideo? = nil
    @State private var playingVideoId: UUID? = nil
    @State private var albums: [Album] = []
    @State private var selectedAlbum: Album? = nil
    @State private var showThumbnailPicker = false
    @State private var editingVideo: MemoryVideo? = nil
    
    // 最新のアニメ情報を取得
    private var currentAnime: Anime {
        animeManager.animes.first(where: { $0.id == anime.id }) ?? anime
    }
    
    // ヘッダービュー
    var headerView: some View {
        HStack {
            // 戻るボタン（矢印）
            Button(action: { 
                dismiss()
                onClose()
            }) {
                Image(systemName: "chevron.left")
                    .foregroundColor(.black)
                    .font(.system(size: 18, weight: .bold))
            }
            .buttonStyle(PlainButtonStyle())
            .frame(width: 60, alignment: .leading)
            
            Spacer()
            
            // タイトル
            Text(currentAnime.title)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
            
            Spacer()
            
            // 追加ボタン
            Button(action: { showAddSheet = true }) {
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
        .padding(.vertical, 8) // Reduced from 12 to 8
        .background(Color.white)
    }
    
    // バナービュー
    var bannerView: some View {
        ZStack {
            // 画像のロード
            if let imageIdentifier = currentAnime.imageIdentifier, let image = loadImageFromPath(imageIdentifier) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: .infinity, maxHeight: 120)
                    .clipped()
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(maxWidth: .infinity, maxHeight: 120)
            }
            
            // ダークオーバーレイ
            Color.black.opacity(0.4)
                .frame(maxWidth: .infinity, maxHeight: 120)
            
            // テキストオーバーレイ
            VStack {
                Spacer()
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ビデオ")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        Text(currentAnime.title)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: 120)
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                // Header
                headerView
                    .zIndex(2) // ヘッダーを最前面に
                // Banner
                bannerView
                    .allowsHitTesting(false) // バナーのタップを無効化
                    .zIndex(1)
                
                // タブバー
                tabBarView
                
                // コンテンツ
                mainContent
            }
            
            // Albumタブ時のみ右下に＋ボタン（アルバムが1つ以上ある場合のみ）
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
        .sheet(isPresented: $showTagInput) {
            VStack(spacing: 24) {
                Text("表示したいタグを入力")
                    .font(.headline)
                Text("同じタグからアルバムを作れます")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                TextField("#タグ名", text: $newTag)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .padding(.horizontal, 24)
                Button("保存") {
                    let tag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !tag.isEmpty {
                        let tagVideos = videos.filter { $0.tags.contains(where: { $0 == tag }) }
                        if !tagVideos.isEmpty {
                            albums.append(Album(tag: tag, videos: tagVideos))
                            saveVideoAlbumsToUserDefaults()
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
        .onAppear {
            loadVideos()
            loadVideoAlbumsFromUserDefaults()
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
        .sheet(isPresented: $showEditTitle) {
            VStack(spacing: 24) {
                Text("タイトルを編集")
                    .font(.headline)
                TextField("タイトル", text: $editText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                HStack(spacing: 24) {
                    Button(action: { 
                        showEditTitle = false
                        editingVideo = nil
                    }) {
                        Text("キャンセル")
                            .foregroundColor(.red)
                    }
                    Button(action: {
                        if let video = editingVideo,
                           let idx = videos.firstIndex(where: { $0.id == video.id }) {
                            var updated = videos[idx]
                            updated.title = editText
                            videos[idx] = updated
                            saveVideosToUserDefaults()
                        }
                        showEditTitle = false
                        editingVideo = nil
                    }) {
                        Text("保存")
                            .foregroundColor(.blue)
                            .fontWeight(.bold)
                    }
                }
            }
            .padding(32)
        }
        .sheet(isPresented: $showEditTags) {
            VStack(spacing: 24) {
                Text("タグを編集")
                    .font(.headline)
                TextField("タグ（カンマ区切り）", text: $editText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                HStack(spacing: 24) {
                    Button(action: { 
                        showEditTags = false
                        editingVideo = nil
                    }) {
                        Text("キャンセル")
                            .foregroundColor(.red)
                    }
                    Button(action: {
                        if let video = editingVideo,
                           let idx = videos.firstIndex(where: { $0.id == video.id }) {
                            var updated = videos[idx]
                            updated.tags = editText.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                            videos[idx] = updated
                            saveVideosToUserDefaults()
                        }
                        showEditTags = false
                        editingVideo = nil
                    }) {
                        Text("保存")
                            .foregroundColor(.blue)
                            .fontWeight(.bold)
                    }
                }
            }
            .padding(32)
        }
        .sheet(isPresented: $showThumbnailPicker) {
            ThumbnailPickerView(
                video: editingVideo ?? MemoryVideo(id: UUID(), characterId: anime.id, videoPath: "", thumbnailData: nil, title: "", tags: [], date: Date(), youtubeURL: nil, youtubeThumbnailURL: nil),
                onSave: { newThumbnailData in
                    if let video = editingVideo,
                       let idx = videos.firstIndex(where: { $0.id == video.id }) {
                        var updated = videos[idx]
                        updated.thumbnailData = newThumbnailData
                        videos[idx] = updated
                        saveVideosToUserDefaults()
                    }
                },
                onCancel: {
                    showThumbnailPicker = false
                }
            )
        }
        .alert(item: $activeAlert) { alertType in
            switch alertType {
            case .deleteVideo(let videoId):
                return Alert(
                    title: Text("動画を削除しますか？"),
                    message: Text("この動画は完全に削除されます。"),
                    primaryButton: .destructive(Text("削除")) {
                        if let idx = videos.firstIndex(where: { $0.id == videoId }) {
                            videos.remove(at: idx)
                            updateAlbumsAfterVideoDeletion(deletedVideoId: videoId)
                            saveVideosToUserDefaults()
                            saveVideoAlbumsToUserDefaults()
                        }
                    },
                    secondaryButton: .cancel(Text("キャンセル"))
                )
            case .deleteAlbum(let album):
                return Alert(
                    title: Text("アルバムを削除しますか？"),
                    message: Text("このアルバムは完全に削除されます。"),
                    primaryButton: .destructive(Text("削除")) {
                        deleteVideoAlbum(album)
                    },
                    secondaryButton: .cancel(Text("キャンセル"))
                )
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddVideoView(
                selectedVideoURL: $selectedVideoURL,
                videoTitle: $videoTitle,
                videoTags: $videoTags,
                selectedThumbnailData: $selectedThumbnailData,
                onSave: {
                    if selectedVideoURL != nil && !videoTitle.trimmingCharacters(in: .whitespaces).isEmpty && !videoTags.trimmingCharacters(in: .whitespaces).isEmpty {
                        Task {
                            await saveVideo()
                        }
                    }
                },
                onYouTubeSave: { url, title, thumbnailURL, tags in
                    saveYouTubeVideo(url: url, title: title, thumbnailURL: thumbnailURL, tags: tags)
                }
            )
        }
        .sheet(isPresented: $showThumbnailPicker) {
            ThumbnailPickerView(
                video: editingVideo ?? videos.first!,
                onSave: { newThumbnailData in
                    if let editingVideo = editingVideo,
                       let idx = videos.firstIndex(where: { $0.id == editingVideo.id }) {
                        var updated = videos[idx]
                        updated.thumbnailData = newThumbnailData
                        videos[idx] = updated
                        saveVideosToUserDefaults()
                    }
                    showThumbnailPicker = false
                    self.editingVideo = nil
                },
                onCancel: {
                    showThumbnailPicker = false
                    self.editingVideo = nil
                }
            )
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
                        saveVideoAlbumsToUserDefaults()
                        print("[DEBUG] AnimeScreen: UserDefaultsに保存しました")
                    }
                }
            )
        }
        .fullScreenCover(item: $selectedVideo) { video in
            VideoPlayerScreen(
                video: video,
                character: nil as Character?,
                anime: currentAnime as Anime?,
                allVideos: videos,
                onSave: { newTitle, newTags in
                    if let idx = videos.firstIndex(where: { $0.id == video.id }) {
                        var updated = videos[idx]
                        updated.title = newTitle
                        updated.tags = newTags
                        videos[idx] = updated
                        saveVideosToUserDefaults()
                    }
                },
                onDelete: {
                    if let idx = videos.firstIndex(where: { $0.id == video.id }) {
                        videos.remove(at: idx)
                        updateAlbumsAfterVideoDeletion(deletedVideoId: video.id)
                        saveVideosToUserDefaults()
                        saveVideoAlbumsToUserDefaults()
                        print("[DEBUG] AnimeScreen: 動画削除完了 - ID: \(video.id)")
                    }
                    selectedVideo = nil
                },
                onThumbnailUpdate: { newThumbnailData in
                    if let idx = videos.firstIndex(where: { $0.id == video.id }) {
                        var updated = videos[idx]
                        updated.thumbnailData = newThumbnailData
                        videos[idx] = updated
                        saveVideosToUserDefaults()
                    }
                }
            )
        }
        .background(Color.white)
        .navigationBarHidden(true)
        .onAppear {
            loadVideos()
            loadVideoAlbumsFromUserDefaults()
        }
    }
    
    // MARK: - Helper Functions
    
    private func loadVideos() {
        let key = "videos_\(anime.id.uuidString)"
        if let data = UserDefaults.standard.data(forKey: key),
           let decodedVideos = try? JSONDecoder().decode([MemoryVideo].self, from: data) {
            videos = decodedVideos
        }
    }
    
    private func saveVideosToUserDefaults() {
        let key = "videos_\(anime.id.uuidString)"
        if let encodedData = try? JSONEncoder().encode(videos) {
            UserDefaults.standard.set(encodedData, forKey: key)
            print("AnimeVideoScreen: UserDefaults保存完了 - 動画数: \(videos.count)")
        }
    }
    
    private func saveVideoAlbumsToUserDefaults() {
        let key = "video_albums_\(anime.id.uuidString)"
        if let encodedData = try? JSONEncoder().encode(albums) {
            UserDefaults.standard.set(encodedData, forKey: key)
            print("[DEBUG] AnimeVideoScreen: アルバムをUserDefaultsに保存しました")
        }
    }
    
    private func loadVideoAlbumsFromUserDefaults() {
        let key = "video_albums_\(anime.id.uuidString)"
        if let data = UserDefaults.standard.data(forKey: key),
           let decodedAlbums = try? JSONDecoder().decode([Album].self, from: data) {
            albums = decodedAlbums
            print("[DEBUG] AnimeVideoScreen: アルバムをUserDefaultsから読み込みました - 件数: \(albums.count)")
        }
    }
    
    private func updateAlbumsAfterVideoDeletion(deletedVideoId: UUID) {
        albums = albums.compactMap { album in
            let updatedVideos = album.videos.filter { $0.id != deletedVideoId }
            if updatedVideos.isEmpty {
                return nil
            }
            return Album(tag: album.tag, videos: updatedVideos)
        }
        print("[DEBUG] AnimeVideoScreen: Album更新完了 - 残りAlbum数: \(albums.count)")
    }
    
    private func deleteVideo(id: UUID) {
        if let idx = videos.firstIndex(where: { $0.id == id }) {
            videos.remove(at: idx)
            updateAlbumsAfterVideoDeletion(deletedVideoId: id)
            saveVideosToUserDefaults()
            saveVideoAlbumsToUserDefaults()
        }
    }
    
    private func deleteVideoAlbum(_ album: Album) {
        if let index = albums.firstIndex(where: { $0.id == album.id }) {
            albums.remove(at: index)
            saveVideoAlbumsToUserDefaults()
            print("[DEBUG] AnimeVideoScreen: アルバム削除完了 - 残りAlbum数: \(albums.count)")
        }
    }
    
    private func saveVideo() async {
        guard let videoURL = selectedVideoURL else { return }
        let tags = videoTags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        
        let fileName = "video_\(UUID().uuidString).mov"
        let documentsPath = saveVideoToDocuments(from: videoURL, fileName: fileName)
        
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
        
        let appDirectoryURL = documentsURL.appendingPathComponent("AnirecoImages")
        
        do {
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
    
    private func saveYouTubeVideo(url: String, title: String, thumbnailURL: String, tags: String) {
        let tagArray = tags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        
        let newVideo = MemoryVideo(
            id: UUID(),
            characterId: anime.id,
            videoPath: "",
            thumbnailData: selectedThumbnailData,
            title: title,
            tags: tagArray,
            date: Date(),
            youtubeURL: url,
            youtubeThumbnailURL: thumbnailURL == "custom" ? nil : thumbnailURL
        )
        
        videos.insert(newVideo, at: 0)
        saveVideosToUserDefaults()
        selectedThumbnailData = nil
        showAddSheet = false
    }
    
    // MARK: - Helper Views
    
    private var tabBarView: some View {
        HStack {
            HStack(spacing: 12) {
                Button(action: { showAlbum = false }) {
                    Text("Video")
                        .font(.caption2)
                        .foregroundColor(!showAlbum ? .white : .black)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(!showAlbum ? Color(.darkGray) : Color(.systemGray5))
                        )
                }
                
                Button(action: { showAlbum = true }) {
                    Text("Album")
                        .font(.caption2)
                        .foregroundColor(showAlbum ? .white : .black)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 12)
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
    }
    
    // メインコンテンツ
    var mainContent: some View {
        VStack(spacing: 0) {
            tabView
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // タブビュー
    var tabView: some View {
        Group {
            if showAlbum {
                albumListView
            } else {
                videoListView
            }
        }
    }
    
    // アルバムリストビュー
    var albumListView: some View {
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
                    
                    Text("同じタグのビデオからアルバムを作成できます")
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
                                    if let firstVideo = album.videos.first, let thumbnailData = firstVideo.thumbnailData, let uiImage = UIImage(data: thumbnailData) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 80, height: 80)
                                            .clipped()
                                            .cornerRadius(8)
                                    } else {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 80, height: 80)
                                    }
                                    
                                    // 右側のコンテンツ
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("#" + album.tag)
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.black)
                                        
                                        if let firstVideo = album.videos.first {
                                            Text(firstVideo.tags.isEmpty ? "タグなし" : firstVideo.tags.joined(separator: ", "))
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
                                        activeAlert = .deleteAlbum(album)
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
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.white)
                                .cornerRadius(8)
                                .shadow(radius: 1)
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal, 16)
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
        }
        .navigationDestination(item: $selectedAlbum) { album in
            AlbumVideoListScreen(
                videos: album.videos,
                tag: album.tag,
                onVideoDeleted: { deletedVideo in
                    if let idx = videos.firstIndex(where: { $0.id == deletedVideo.id }) {
                        videos.remove(at: idx)
                        updateAlbumsAfterVideoDeletion(deletedVideoId: deletedVideo.id)
                        saveVideosToUserDefaults()
                        saveVideoAlbumsToUserDefaults()
                    }
                }
            )
        }
    }
    
    // ビデオリストビュー
    var videoListView: some View {
        Group {
            if videos.isEmpty {
                VStack(spacing: 20) {
                    Spacer()
                        .frame(maxHeight: 100)
                    
                    Image(systemName: "video.slash")
                        .font(.system(size: 60))
                        .foregroundColor(.purple)
                    
                    Text("まだビデオがありません")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("右上の追加ボタンからビデオを追加できます")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button(action: {
                        showAddSheet = true
                    }) {
                        Label("ビデオを追加", systemImage: "plus.circle.fill")
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
                    VStack(spacing: 0) {
                        Spacer().frame(height: 5)
                        ForEach(Array(videos.enumerated()), id: \.element.id) { idx, video in
                            if idx > 0 {
                                Spacer().frame(height: 35)
                            }
                            videoRowView(video: video)
                        }
                    }
                }
            }
        }
        .fullScreenCover(item: $selectedVideo) { video in
            VideoPlayerScreen(
                video: video,
                character: nil as Character?,
                anime: currentAnime as Anime?,
                allVideos: videos,
                onSave: { newTitle, newTags in
                    if let idx = videos.firstIndex(where: { $0.id == video.id }) {
                        var updated = videos[idx]
                        updated.title = newTitle
                        updated.tags = newTags
                        videos[idx] = updated
                        saveVideosToUserDefaults()
                    }
                },
                onDelete: {
                    deleteVideo(id: video.id)
                    selectedVideo = nil
                },
                onThumbnailUpdate: { newThumbnailData in
                    if let idx = videos.firstIndex(where: { $0.id == video.id }) {
                        var updated = videos[idx]
                        updated.thumbnailData = newThumbnailData
                        videos[idx] = updated
                        saveVideosToUserDefaults()
                    }
                }
            )
        }
    }
    
    // ビデオ行ビュー
    func videoRowView(video: MemoryVideo) -> some View {
        Button(action: {
            selectedVideo = video
        }) {
            HStack(alignment: .top, spacing: 16) {
                // サムネイル
                if let thumbnailData = video.thumbnailData, let uiImage = UIImage(data: thumbnailData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 183, height: 109)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .clipped()
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 183, height: 109)
                }
                
                // タイトルとタグ
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
                
                // メニューボタン
                Menu {
                    Button(action: {
                        editText = video.title
                        showEditTitle = true
                        editingVideo = video
                    }) {
                        Label("タイトルを編集", systemImage: "pencil")
                    }
                    Button(action: {
                        editText = video.tags.joined(separator: ", ")
                        showEditTags = true
                        editingVideo = video
                    }) {
                        Label("タグを編集", systemImage: "tag")
                    }
                    Button(action: {
                        showThumbnailPicker = true
                        editingVideo = video
                    }) {
                        Label("サムネイルを変更", systemImage: "photo")
                    }
                    Divider()
                    Button(role: .destructive, action: {
                        print("[DEBUG] 削除ボタンが押されました - Video ID: \(video.id)")
                        activeAlert = .deleteVideo(video.id)
                        print("[DEBUG] activeAlert set to deleteVideo")
                    }) {
                        Label("削除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 18))
                        .foregroundColor(.gray)
                        .padding(8)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Circle())
                }
                .padding(.trailing, 8)
            }
            .padding(.leading, 8)
        }
        .buttonStyle(PlainButtonStyle())
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
    @State private var currentDisplayedIcon: UIImage? = nil
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var animeManager: AnimeManager
    
    // 最新のアニメ情報を取得
    private var currentAnime: Anime {
        animeManager.animes.first(where: { $0.id == anime.id }) ?? anime
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // アニメバナー画像
                    VStack(spacing: 0) {
                        Button(action: {
                            showIconPicker = true
                        }) {
                            if let imageIdentifier = currentAnime.imageIdentifier, let image = loadImageFromPath(imageIdentifier) {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(maxWidth: .infinity, maxHeight: 200)
                                    .clipped()
                                    .overlay(
                                        Color.black.opacity(0.4)
                                    )
                                    .overlay(
                                        VStack {
                                            Spacer()
                                            HStack {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(anime.title)
                                                        .font(.system(size: 24, weight: .bold))
                                                        .foregroundColor(.white)
                                                    
                                                    if !anime.hashtag.isEmpty {
                                                        Text("#\(anime.hashtag)")
                                                            .font(.system(size: 16, weight: .medium))
                                                            .foregroundColor(.white)
                                                    }
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
                                    .frame(maxWidth: .infinity, maxHeight: 200)
                                    .overlay(
                                        VStack(spacing: 4) {
                                            Image(systemName: "film.fill")
                                                .font(.system(size: 40))
                                                .foregroundColor(.gray)
                                            Text("タップで追加")
                                                .font(.system(size: 12))
                                                .foregroundColor(.gray)
                                        }
                                    )
                                    .overlay(
                                        Color.black.opacity(0.4)
                                    )
                                    .overlay(
                                        VStack {
                                            Spacer()
                                            HStack {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(anime.title)
                                                        .font(.system(size: 24, weight: .bold))
                                                        .foregroundColor(.white)
                                                    
                                                    if !anime.hashtag.isEmpty {
                                                        Text("#\(anime.hashtag)")
                                                            .font(.system(size: 16, weight: .medium))
                                                            .foregroundColor(.white)
                                                    }
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
            .background(Color.white)
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
            .onChange(of: iconPickerItem) {
                if let newValue = iconPickerItem {
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
                    .onChange(of: selectedItem) { _, newValue in
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
                    animeManager.addAnimeAtTop(newAnime)
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
    @State private var currentDisplayedIcon: UIImage? = nil

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
                        if let currentIcon = currentDisplayedIcon {
                            Image(uiImage: currentIcon)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(width: 120, height: 120)
                                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                                .shadow(radius: 8)
                        } else if let imageIdentifier = anime.imageIdentifier, let image = loadImageFromPath(imageIdentifier) {
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
                        AnimeArtworkScreen(anime: $anime, animes: $animes, onClose: { showArtwork = false })
                    }
                    .fullScreenCover(isPresented: $showVideo) {
                        AnimeVideoScreen(anime: $anime, animes: $animes, onClose: { showVideo = false })
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
        .onAppear {
            // 初期化時に現在のアイコンを設定
            if currentDisplayedIcon == nil, let imageIdentifier = anime.imageIdentifier {
                currentDisplayedIcon = loadImageFromPath(imageIdentifier)
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
                    .onChange(of: backgroundPickerItem) { _, newValue in
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
                                anime = updatedAnime  // Bindingも更新
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
                        // tempIconImageはリセットしない（最新状態を保持）
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
                    .onChange(of: iconPickerItem) {
                        if let newItem = iconPickerItem {
                            Task {
                                if let data = try? await newItem.loadTransferable(type: Data.self), let uiImage = UIImage(data: data) {
                                    tempIconImage = uiImage
                                    currentDisplayedIcon = uiImage // 即座にUI更新
                                    
                                    let fileName = "icon_\(UUID().uuidString).png"
                                    let imagePath = saveImageToDocuments(uiImage, fileName: fileName)
                                    
                                    // 新しいAnimeオブジェクトを作成して更新
                                    var updatedAnime = anime
                                    updatedAnime.imageIdentifier = imagePath
                                    
                                    // Bindingを通じて更新（これがsetterを呼び出す）
                                    anime = updatedAnime
                                    
                                    // animesリストも更新
                                    if let idx = animes.firstIndex(where: { $0.id == anime.id }) {
                                        animes[idx] = updatedAnime
                                    }
                                    
                                    // AnimeManagerも更新してUI全体を更新
                                    animeManager.updateAnime(updatedAnime)
                                    animeManager.refreshUI()
                                    
                                    // アイコン選択完了後にモーダルを閉じる
                                    showEditIconModal = false
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
            .onAppear {
                // モーダル表示時に現在のアイコンをtempIconImageに設定
                if let currentIcon = currentDisplayedIcon {
                    tempIconImage = currentIcon
                } else if let imageIdentifier = anime.imageIdentifier {
                    tempIconImage = loadImageFromPath(imageIdentifier)
                }
            }
        }
        .onAppear {
            // 初期化時に現在のアイコンを設定
            if currentDisplayedIcon == nil, let imageIdentifier = anime.imageIdentifier {
                currentDisplayedIcon = loadImageFromPath(imageIdentifier)
            }
        }
    }
    
}
