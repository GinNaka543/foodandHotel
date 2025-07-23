// swiftlint:disable file_length
import SwiftUI
import PhotosUI
import UIKit
import Foundation
import Photos
import AVFoundation
import AVKit
import FirebaseFirestore

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
        
        // ログイン時にデータを再読み込み
        NotificationCenter.default.addObserver(
            forName: Notification.Name("UserDidLogin"),
            object: nil,
            queue: .main
        ) { _ in
            self.loadAnimes()
        }
    }
    
    func loadAnimes() {
        if let data = UserDefaultsHelper.shared.getData(forKey: "animes"),
           let decoded = try? JSONDecoder().decode([Anime].self, from: data) {
            print("[DEBUG] loadAnimes: 読み込んだアニメ数=\(decoded.count)")
            for a in decoded { print("[DEBUG] アニメID=\(a.id), title=\(a.title), customFields=\(String(describing: a.customFields))") }
            animes = decoded
        } else {
            print("[DEBUG] loadAnimes: データなし or デコード失敗")
            animes = []
        }
    }
    
    func saveAnimes() {
        if let data = try? JSONEncoder().encode(animes) {
            UserDefaultsHelper.shared.setData(data, forKey: "animes")
            print("[DEBUG] saveAnimes: 保存アニメ数=\(animes.count)")
            for a in animes { print("[DEBUG] 保存アニメID=\(a.id), title=\(a.title), customFields=\(String(describing: a.customFields))") }
            
            // Firebaseにも同期（現在のユーザープロファイルが存在する場合）
            if let profileData = UserDefaultsHelper.shared.getData(forKey: "currentUserProfile"),
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

enum AnimeGenre: String, Codable, CaseIterable {
    case serious = "シリアス"
    case romcom = "ラブコメ"
    case sports = "スポーツ"
    case comedy = "コメディー"
    case isekai = "異世界系"
    case sf = "SF"
    case art = "芸術系"
    case brain = "頭脳系"
    case healing = "癒し系"
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
    var rating: Double = 0.0  // レーティング（0.0〜5.0）
    var voiceActors: [String] = []  // 声優リスト
    var characters: [String] = []  // 出演キャラクターリスト
    var watchLink: String = ""  // アニメ視聴リンク
    var genres: [AnimeGenre] = []  // ジャンルリスト
    // 必要に応じて他の属性も追加可能
    static func == (lhs: Anime, rhs: Anime) -> Bool {
        lhs.id == rhs.id
    }
    enum CodingKeys: String, CodingKey {
        case id, imageIdentifier, backgroundImagePath, title, hashtag, releaseDate, customFields, watchStatus, watchStatuses, order, rating, voiceActors, characters, watchLink, genres
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
        try container.encode(rating, forKey: .rating)
        try container.encode(voiceActors, forKey: .voiceActors)
        try container.encode(characters, forKey: .characters)
        try container.encode(watchLink, forKey: .watchLink)
        try container.encode(genres, forKey: .genres)
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
        
        // ratingとvoiceActorsを読み込む。古いデータの場合はデフォルト値を使用
        rating = (try? container.decode(Double.self, forKey: .rating)) ?? 0.0
        voiceActors = (try? container.decode([String].self, forKey: .voiceActors)) ?? []
        characters = (try? container.decode([String].self, forKey: .characters)) ?? []
        watchLink = (try? container.decode(String.self, forKey: .watchLink)) ?? ""
        genres = (try? container.decode([AnimeGenre].self, forKey: .genres)) ?? []
    }
    init(id: UUID, imageIdentifier: String?, backgroundImagePath: String? = nil, title: String, hashtag: String, releaseDate: Date, customFields: [AnimeCustomField]? = nil, watchStatus: WatchStatus = .none, watchStatuses: [WatchStatus] = [], order: Int = 0, rating: Double = 0.0, voiceActors: [String] = [], characters: [String] = [], watchLink: String = "", genres: [AnimeGenre] = []) {
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
        self.rating = rating
        self.voiceActors = voiceActors
        self.characters = characters
        self.watchLink = watchLink
        self.genres = genres
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
    @State private var bannerAnime: Anime? = nil
    @State private var bannerVideo: MemoryVideo? = nil
    @State private var showVideoPlayer = false
    @State private var selectedVideoId: UUID? = nil
    @State private var selectedVideoAnime: Anime? = nil
    @State private var bannerTimer: Timer? = nil
    @State private var allYouTubeVideos: [MemoryVideo] = []
    @State private var displayedVideoIds: Set<UUID> = []
    
    enum AnimeTab: String, CaseIterable {
        case all = "すべて"
        case watching = "視聴中"
        case thisTerm = "今期"
        case willWatch = "視聴予定"
        case watchAgain = "再視聴"
        // ジャンル
        case serious = "シリアス"
        case romcom = "ラブコメ"
        case sports = "スポーツ"
        case comedy = "コメディー"
        case isekai = "異世界系"
        case sf = "SF"
        case art = "芸術系"
        case brain = "頭脳系"
        case healing = "癒し系"
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
        // ジャンルフィルタ
        case .serious:
            result = animesWithTitles.filter { $0.genres.contains(.serious) }
        case .romcom:
            result = animesWithTitles.filter { $0.genres.contains(.romcom) }
        case .sports:
            result = animesWithTitles.filter { $0.genres.contains(.sports) }
        case .comedy:
            result = animesWithTitles.filter { $0.genres.contains(.comedy) }
        case .isekai:
            result = animesWithTitles.filter { $0.genres.contains(.isekai) }
        case .sf:
            result = animesWithTitles.filter { $0.genres.contains(.sf) }
        case .art:
            result = animesWithTitles.filter { $0.genres.contains(.art) }
        case .brain:
            result = animesWithTitles.filter { $0.genres.contains(.brain) }
        case .healing:
            result = animesWithTitles.filter { $0.genres.contains(.healing) }
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
    
    // バナービュー
    private var bannerView: some View {
        Group {
            if let video = bannerVideo, let youtubeURL = video.youtubeURL, !youtubeURL.isEmpty {
                ZStack(alignment: .bottomLeading) {
                    // カスタムサムネイルまたはYouTubeサムネイルを表示
                    if let thumbnailData = video.thumbnailData, let uiImage = UIImage(data: thumbnailData) {
                        ZStack {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: UIScreen.main.bounds.width - 32, height: 176)
                                .clipped()
                            
                            // 暗いオーバーレイを追加
                            Color.black.opacity(0.2)
                                .frame(width: UIScreen.main.bounds.width - 32, height: 176)
                        }
                    } else if let customThumbnailURL = video.youtubeThumbnailURL {
                        ZStack {
                            AsyncImage(url: URL(string: customThumbnailURL)) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: UIScreen.main.bounds.width - 32, height: 176)
                                        .clipped()
                                case .failure(_), .empty:
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: UIScreen.main.bounds.width - 32, height: 176)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            
                            // 暗いオーバーレイを追加
                            Color.black.opacity(0.2)
                                .frame(width: UIScreen.main.bounds.width - 32, height: 176)
                        }
                    } else {
                        ZStack {
                            AsyncImage(url: URL(string: getYouTubeThumbnailURLForBanner(from: youtubeURL))) { phase in
                                switch phase {
                                case .success(let image):
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: UIScreen.main.bounds.width - 32, height: 176)
                                        .clipped()
                                case .failure(_), .empty:
                                    Rectangle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: UIScreen.main.bounds.width - 32, height: 176)
                                @unknown default:
                                    EmptyView()
                                }
                            }
                            
                            // 暗いオーバーレイを追加
                            Color.black.opacity(0.2)
                                .frame(width: UIScreen.main.bounds.width - 32, height: 176)
                        }
                    }
                
                // 動画情報
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(video.title)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.3), radius: 0, x: 0, y: 1)
                            .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                        
                        if !video.tags.isEmpty {
                            Text("#" + video.tags.joined(separator: " #"))
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.3), radius: 0, x: 0, y: 1)
                                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                                .lineLimit(1)
                        }
                    }
                    
                    HStack(spacing: 4) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 16))
                        Text("WATCH")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.black)
                    .cornerRadius(4)
                }
                .padding()
            }
            .frame(width: UIScreen.main.bounds.width - 32, height: 176)
            .cornerRadius(12)
            .onTapGesture {
                // 動画を再生
                print("動画再生ボタンが押されました")
                print("Video title: \(video.title)")
                print("YouTube URL: \(video.youtubeURL ?? "nil")")
                print("Video path: \(video.videoPath)")
                
                if let youtubeURL = video.youtubeURL, !youtubeURL.isEmpty {
                    // YouTubeの場合は直接URLを開く
                    print("YouTubeのURLを開きます: \(youtubeURL)")
                    if let url = URL(string: youtubeURL) {
                        UIApplication.shared.open(url)
                    }
                } else {
                    // アップロード動画の場合はプレイヤーで再生
                    print("アップロード動画をプレイヤーで再生します")
                    if let anime = animeManager.animes.first(where: { anime in
                        let key = "videos_\(anime.id.uuidString)"
                        if let data = UserDefaults.standard.data(forKey: key),
                           let videos = try? JSONDecoder().decode([MemoryVideo].self, from: data) {
                            return videos.contains(where: { $0.id == video.id })
                        }
                        return false
                    }) {
                        print("対応するアニメが見つかりました: \(anime.title)")
                        selectedVideoAnime = anime
                        selectedVideoId = video.id
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            showVideoPlayer = true
                        }
                        print("showVideoPlayer: \(showVideoPlayer)")
                        print("selectedVideoAnime: \(selectedVideoAnime?.title ?? "nil")")
                        print("selectedVideoId: \(selectedVideoId?.uuidString ?? "nil")")
                    } else {
                        print("対応するアニメが見つかりませんでした")
                    }
                }
            }
            } else {
                // 動画が登録されていない場合は紫のグラデーション
                ZStack {
                    AnimatedGradientView()
                        .frame(width: UIScreen.main.bounds.width - 32, height: 176)
                        .cornerRadius(12)
                    
                    VStack {
                        Spacer()
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Image(systemName: "play.rectangle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white)
                                    .shadow(radius: 4)
                                    .padding(.bottom, 4)
                                
                                Text("YouTubeから")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                    .shadow(radius: 2)
                                Text("動画を登録しよう")
                                    .font(.system(size: 18, weight: .medium))
                                    .foregroundColor(.white.opacity(0.95))
                                    .shadow(radius: 2)
                            }
                            .padding(.leading, 24)
                            .padding(.bottom, 20)
                            Spacer()
                        }
                    }
                }
            }
        }
        .frame(height: 200)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
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
    private var animeListContents: some View {
        VStack(spacing: 0) {
                if filteredAnimes.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "tv")
                            .font(.system(size: 50))
                            .foregroundColor(.purple)
                        Text("好きなアニメを登録しよう")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundColor(.black)
                        Text("視聴状況を管理して、見逃しを防ぎましょう")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 20)
                        
                        Button(action: { showAddSheet = true }) {
                            HStack {
                                Image(systemName: "plus")
                                Text("アニメを追加")
                            }
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color(red: 0.6, green: 0.4, blue: 0.9), Color(red: 0.8, green: 0.5, blue: 0.9)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(25)
                        }
                        .padding(.top, 20)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 100)
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

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                headerView
                ScrollView {
                    VStack(spacing: 0) {
                        bannerView
                        tabView
                            .padding(.top, 0)
                        animeListContents
                    }
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
        .onAppear {
            // YouTube動画を収集
            loadYouTubeVideos()
            
            // 最初の動画を選択
            selectRandomYouTubeVideo()
            
            // 動画のローテーションを開始
            startBannerRotation()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // アプリがフォアグラウンドに戻った時に動画リストを更新
            loadYouTubeVideos()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("VideoDeleted"))) { _ in
            // 動画が削除された時に動画リストを更新
            loadYouTubeVideos()
            selectRandomYouTubeVideo()
        }
        .onDisappear {
            bannerTimer?.invalidate()
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
        .fullScreenCover(isPresented: $showVideoPlayer, onDismiss: {
            selectedVideoAnime = nil
            selectedVideoId = nil
        }) {
            if showVideoPlayer, let anime = selectedVideoAnime, let videoId = selectedVideoId {
                let key = "videos_\(anime.id.uuidString)"
                if let data = UserDefaults.standard.data(forKey: key),
                   let videos = try? JSONDecoder().decode([MemoryVideo].self, from: data),
                   let video = videos.first(where: { $0.id == videoId }) {
                    VideoPlayerScreen(video: video, character: nil, anime: anime, allVideos: videos)
                        .onAppear {
                            print("VideoPlayerScreenが表示されました")
                            print("Video: \(video.title)")
                            print("Anime: \(anime.title)")
                        }
                } else {
                    VStack {
                        Text("動画が見つかりませんでした")
                            .font(.title)
                            .padding()
                        Button("閉じる") {
                            showVideoPlayer = false
                        }
                        .padding()
                    }
                    .onAppear {
                        print("エラー: 動画が見つかりませんでした")
                        print("selectedVideoAnime: \(anime.title)")
                        print("selectedVideoId: \(videoId.uuidString)")
                        print("key: videos_\(anime.id.uuidString)")
                    }
                }
            } else {
                VStack {
                    Text("動画を読み込めませんでした")
                        .font(.title)
                        .padding()
                    Button("閉じる") {
                        showVideoPlayer = false
                    }
                    .padding()
                }
                .onAppear {
                    print("エラー: 必要な情報がありません")
                    print("showVideoPlayer: \(showVideoPlayer)")
                    print("selectedVideoAnime: \(selectedVideoAnime?.title ?? "nil")")
                    print("selectedVideoId: \(selectedVideoId?.uuidString ?? "nil")")
                }
            }
        }
    }
    
    
    // YouTube動画を収集
    private func loadYouTubeVideos() {
        allYouTubeVideos = []
        for anime in animeManager.animes {
            let key = "videos_\(anime.id.uuidString)"
            if let data = UserDefaults.standard.data(forKey: key),
               let videos = try? JSONDecoder().decode([MemoryVideo].self, from: data) {
                // YouTube URLを持つ動画のみをフィルタリング
                let youtubeVideos = videos.filter { $0.youtubeURL != nil && !$0.youtubeURL!.isEmpty }
                allYouTubeVideos.append(contentsOf: youtubeVideos)
            }
        }
    }
    
    // ランダムなYouTube動画を選択
    private func selectRandomYouTubeVideo() {
        guard !allYouTubeVideos.isEmpty else { return }
        
        // 表示していない動画のみをフィルタリング
        let unshownVideos = allYouTubeVideos.filter { !displayedVideoIds.contains($0.id) }
        
        // 全て表示した場合はリセット
        if unshownVideos.isEmpty {
            displayedVideoIds.removeAll()
            selectRandomYouTubeVideo()
            return
        }
        
        // ランダムに1つ選択
        if let randomVideo = unshownVideos.randomElement() {
            bannerVideo = randomVideo
            displayedVideoIds.insert(randomVideo.id)
        }
    }
    
    // バナーのローテーションを開始
    private func startBannerRotation() {
        bannerTimer?.invalidate()
        
        // YouTube動画がある場合のみローテーションを開始
        guard !allYouTubeVideos.isEmpty else { return }
        
        bannerTimer = Timer.scheduledTimer(withTimeInterval: 7.0, repeats: true) { _ in
            // 新しい動画を選択
            self.selectRandomYouTubeVideo()
        }
    }
    
    // YouTubeサムネイルURLを取得（バナー用）
    private func getYouTubeThumbnailURLForBanner(from url: String) -> String {
        // YouTubeのビデオIDを抽出
        let videoId: String?
        if url.contains("youtu.be/") {
            videoId = url.components(separatedBy: "youtu.be/").last?.components(separatedBy: "?").first
        } else if url.contains("youtube.com/watch?v=") {
            videoId = url.components(separatedBy: "v=").last?.components(separatedBy: "&").first
        } else {
            videoId = nil
        }
        
        // サムネイルURLを返す
        if let videoId = videoId {
            return "https://img.youtube.com/vi/\(videoId)/maxresdefault.jpg"
        } else {
            return ""
        }
    }
}

// アニメ一覧の1行
struct AnimeRow: View {
    let anime: Anime
    @ObservedObject var animeManager: AnimeManager
    
    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            // 左側：サムネイルのみ
            if let imageIdentifier = anime.imageIdentifier, let image = loadImageFromPath(imageIdentifier) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 183, height: 229)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 183, height: 229)
            }
            
            // 右側：アニメ情報
            VStack(alignment: .leading, spacing: 8) {
                // タイトル
                Text(anime.title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.black)
                    .lineLimit(2)
                
                // ハッシュタグ
                Text("#" + anime.hashtag)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.gray)
                    .lineLimit(1)
                
                // レーティング（常に表示）
                HStack(spacing: 4) {
                    ForEach(1...5, id: \.self) { index in
                        Image(systemName: index <= Int(anime.rating.rounded()) ? "star.fill" : "star")
                            .font(.system(size: 14))
                            .foregroundColor(index <= Int(anime.rating.rounded()) ? .yellow : .gray.opacity(0.3))
                    }
                    Text(String(format: "%.1f", anime.rating))
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                // 声優情報（常に表示）
                VStack(alignment: .leading, spacing: 2) {
                    Text("声優")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                    if !anime.voiceActors.isEmpty {
                        Text(anime.voiceActors.prefix(3).joined(separator: ", "))
                            .font(.system(size: 12))
                            .foregroundColor(.black)
                            .lineLimit(2)
                    } else {
                        Text("声優情報を入力してください")
                            .font(.system(size: 12))
                            .foregroundColor(.gray.opacity(0.5))
                            .italic()
                    }
                }
                
                // キャラクター情報（常に表示）
                VStack(alignment: .leading, spacing: 2) {
                    Text("キャラクター")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.gray)
                    if !anime.characters.isEmpty {
                        Text(anime.characters.prefix(3).joined(separator: ", "))
                            .font(.system(size: 12))
                            .foregroundColor(.black)
                            .lineLimit(2)
                    } else {
                        Text("キャラクター情報を入力してください")
                            .font(.system(size: 12))
                            .foregroundColor(.gray.opacity(0.5))
                            .italic()
                    }
                }
                
                // アニメを見るボタン
                if !anime.watchLink.isEmpty {
                    Link(destination: URL(string: anime.watchLink) ?? URL(string: "https://")!) {
                        HStack {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 14))
                            Text("アニメを見る")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.purple)
                        .cornerRadius(6)
                    }
                } else {
                    HStack {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 14))
                        Text("アニメを見る")
                            .font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.gray.opacity(0.3))
                    .cornerRadius(6)
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
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
    @State private var showR18Alert = false
    @State private var r18ArtworkTitles: [String] = []
    @State private var isShowingFullDescription = false
    
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
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8) // Reduced from 12 to 8
        .background(Color.white)
    }
    
    // バナービュー
    var bannerView: some View {
        Group {
            if let imageIdentifier = currentAnime.imageIdentifier, let image = loadImageFromPath(imageIdentifier) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
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
    
    // タブビュー
    var tabView: some View {
        HStack {
            HStack(spacing: 12) {
                Button(action: { showAlbum = false }) {
                    Text("ArtWork")
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
                    Text("Album")
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
                                VStack(spacing: 12) {
                                    // --- アルバムリスト ---
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
                                                    PixivThumbnailView(pixivURL: pixivURL)
                                                        .frame(height: 180)
                                                        .clipped()
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
                                .padding(.top, 8)
                                .padding(.bottom, 8)
                            }
                        }
                        .fullScreenCover(item: $selectedAlbum) { album in
                            AlbumArtworkListScreen(
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
                            ArtworkPlayerScreen(
                                artwork: artwork,
                                character: nil,
                                anime: anime,
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
                                onArtworkChange: { updatedArtwork in
                                    // Update the artwork with view count changes
                                    if let idx = artworks.firstIndex(where: { $0.id == updatedArtwork.id }) {
                                        artworks[idx] = updatedArtwork
                                        saveArtworksToUserDefaults()
                                    }
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
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 0) {
                    // Banner (no header)
                    bannerView
                        .allowsHitTesting(false) // バナーのタップを無効化
                        .zIndex(1)
                    
                    // Profile section
                    HStack(spacing: 12) {
                    // Anime icon
                    if let imageIdentifier = currentAnime.imageIdentifier, let image = loadImageFromPath(imageIdentifier) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 67, height: 67)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 67, height: 67)
                            .overlay(
                                Image(systemName: "tv")
                                    .font(.system(size: 33))
                                    .foregroundColor(.gray)
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(currentAnime.title)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.black)
                        Text("@\(currentAnime.title)")
                            .font(.system(size: 12.7))
                            .foregroundColor(.black)
                        Text("\(artworks.count)枚の画像・アルバム数\(albums.count)")
                            .font(.system(size: 15.4))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                // Description section
                if let customFields = currentAnime.customFields,
                   let descriptionField = customFields.first(where: { $0.name == "概要" }),
                   !descriptionField.value.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        if descriptionField.value.count > 13 && !isShowingFullDescription {
                            HStack(spacing: 0) {
                                Text(String(descriptionField.value.prefix(13)) + "... ")
                                    .font(.system(size: 14))
                                    .foregroundColor(.black)
                                Text("さらに表示")
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
                                Button(action: {
                                    isShowingFullDescription = false
                                }) {
                                    Text("折りたたむ")
                                        .font(.system(size: 14))
                                        .foregroundColor(.black)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 16)
                    .padding(.trailing, 16)
                    .padding(.bottom, 12)
                }
                
                // Add button moved here
                Button(action: { 
                    if showAlbum {
                        showTagInput = true
                    } else {
                        activeSheet = .addPhoto
                    }
                }) {
                    Text(showAlbum ? "アルバムを作る" : "画像を追加する")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10.4)  // 12 / 1.15 = 10.4
                        .background(Color.black)
                        .cornerRadius(20)
                }
                .padding(.horizontal, 16)  // Same as banner padding
                .padding(.bottom, 16)
                
                // Main content
                mainContent
                }
            }
            floatingButton
            
            // Navigation bar at bottom
            VStack {
                Spacer()
                HStack(spacing: 0) {
                    // Back button
                    Button(action: {
                        dismiss()
                        onClose()
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
                    .buttonStyle(AnimeNavigationButtonStyle())
                    
                    // Artwork button
                    Button(action: {
                        showAlbum = false
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "photo")
                                .font(.system(size: 24))
                            Text("Artwork")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(!showAlbum ? .black : .gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    
                    // Album button
                    Button(action: {
                        // Navigate to album view
                        showAlbum = true
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "rectangle.grid.2x2")
                                .font(.system(size: 24))
                            Text("Album")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(showAlbum ? .black : .gray)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                    }
                    
                    // About button
                    Button(action: {
                        showAbout = true
                    }) {
                        VStack(spacing: 4) {
                            if let imageIdentifier = anime.imageIdentifier, let image = loadImageFromPath(imageIdentifier) {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 24, height: 24)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle")
                                    .font(.system(size: 24))
                            }
                            Text("About")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
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
        .onAppear {
            loadArtworks()
            loadAlbumsFromUserDefaults()
        }
        .fullScreenCover(isPresented: $showAbout) {
            AnimeAboutView(anime: $anime, animes: $animes, onClose: { showAbout = false })
                .environmentObject(animeManager)
        }
        .sheet(isPresented: $showPixivRedirect) {
            PixivRedirectView(
                pixivURL: pixivRedirectURL,
                artwork: artworks.first(where: { $0.pixivURL == pixivRedirectURL }),
                onEdit: { newTitle, newTags in
                    if let idx = artworks.firstIndex(where: { $0.pixivURL == pixivRedirectURL }) {
                        artworks[idx].title = newTitle
                        artworks[idx].tags = newTags
                        saveArtworksToUserDefaults()
                    }
                },
                onDelete: {
                    if let idx = artworks.firstIndex(where: { $0.pixivURL == pixivRedirectURL }) {
                        let artwork = artworks[idx]
                        artworks.remove(at: idx)
                        updateAlbumsAfterArtworkDeletion(deletedArtworkId: artwork.id)
                        saveArtworksToUserDefaults()
                        saveAlbumsToUserDefaults()
                    }
                    showPixivRedirect = false
                },
                onThumbnailUpdate: { newThumbnailData in
                    if let idx = artworks.firstIndex(where: { $0.pixivURL == pixivRedirectURL }) {
                        artworks[idx].customThumbnailData = newThumbnailData
                        saveArtworksToUserDefaults()
                    }
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
                                            .aspectRatio(contentMode: .fill)
                                            .frame(maxWidth: min(innerGeometry.size.width - 40, 600))
                                            .frame(maxHeight: innerGeometry.size.height * 0.6)
                                            .clipped()
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
        if let data = UserDefaultsHelper.shared.getData(forKey: key),
           let decodedArtworks = try? JSONDecoder().decode([Artwork].self, from: data) {
            artworks = decodedArtworks
            checkPixivArtworks()
        }
    }
    
    private func checkPixivArtworks() {
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
    
    private func saveArtworksToUserDefaults() {
        let key = "anime_artworks_\(anime.id.uuidString)"
        if let encodedData = try? JSONEncoder().encode(artworks) {
            UserDefaultsHelper.shared.setData(encodedData, forKey: key)
        }
    }
    
    private func saveAlbumsToUserDefaults() {
        let key = "anime_artwork_albums_\(anime.id.uuidString)"
        if let encodedData = try? JSONEncoder().encode(albums) {
            UserDefaultsHelper.shared.setData(encodedData, forKey: key)
            print("[DEBUG] AnimeArtworkScreen: アルバムをUserDefaultsに保存しました")
        }
    }
    
    private func loadAlbumsFromUserDefaults() {
        let key = "anime_artwork_albums_\(anime.id.uuidString)"
        if let data = UserDefaultsHelper.shared.getData(forKey: key),
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
    @State private var showAbout = false
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
    @State private var isShowingFullDescription = false
    
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
            
            Spacer()
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8) // Reduced from 12 to 8
        .background(Color.white)
    }
    
    // バナービュー
    var bannerView: some View {
        Group {
            if let imageIdentifier = currentAnime.imageIdentifier, let image = loadImageFromPath(imageIdentifier) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
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
                    // Banner (no header)
                    bannerView
                        .allowsHitTesting(false) // バナーのタップを無効化
                        .zIndex(1)
                    
                    // Profile section
                    HStack(spacing: 12) {
                    // Anime icon
                    if let imageIdentifier = currentAnime.imageIdentifier, let image = loadImageFromPath(imageIdentifier) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 67, height: 67)
                            .clipShape(Circle())
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 67, height: 67)
                            .overlay(
                                Image(systemName: "tv")
                                    .font(.system(size: 33))
                                    .foregroundColor(.gray)
                            )
                    }
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(currentAnime.title)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.black)
                        Text("@\(currentAnime.title)")
                            .font(.system(size: 12.7))
                            .foregroundColor(.black)
                        Text("\(videos.count)本の動画・アルバム数\(albums.count)")
                            .font(.system(size: 15.4))
                            .foregroundColor(.gray)
                    }
                    
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                
                // Description section
                if let customFields = currentAnime.customFields,
                   let descriptionField = customFields.first(where: { $0.name == "概要" }),
                   !descriptionField.value.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        if descriptionField.value.count > 13 && !isShowingFullDescription {
                            HStack(spacing: 0) {
                                Text(String(descriptionField.value.prefix(13)) + "... ")
                                    .font(.system(size: 14))
                                    .foregroundColor(.black)
                                Text("さらに表示")
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
                                Button(action: {
                                    isShowingFullDescription = false
                                }) {
                                    Text("折りたたむ")
                                        .font(.system(size: 14))
                                        .foregroundColor(.black)
                                }
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 16)
                    .padding(.trailing, 16)
                    .padding(.bottom, 12)
                }
                
                // Add button moved here
                Button(action: { 
                    if showAlbum {
                        showTagInput = true
                    } else {
                        showAddSheet = true
                    }
                }) {
                    Text(showAlbum ? "アルバムを作る" : "動画を追加する")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10.4)  // 12 / 1.15 = 10.4
                        .background(Color.black)
                        .cornerRadius(20)
                }
                .padding(.horizontal, 16)  // Same as banner padding
                .padding(.bottom, 16)
                
                // タブバー
                tabBarView
                
                // コンテンツ
                mainContent
                }
            }
            
            
            // Navigation bar at bottom
            VStack {
                Spacer()
                HStack(spacing: 0) {
                    // Back button
                    Button(action: {
                        dismiss()
                        onClose()
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
                    .buttonStyle(AnimeNavigationButtonStyle())
                    
                    // Video button
                    Button(action: {
                        showAlbum = false
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "video")
                                .font(.system(size: 24))
                            Text("Video")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(!showAlbum ? .black : .gray)
                        .frame(maxWidth: .infinity)
                    }
                    
                    // Album button
                    Button(action: {
                        showAlbum = true
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: "rectangle.grid.2x2")
                                .font(.system(size: 24))
                            Text("Album")
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
                            if let imageIdentifier = anime.imageIdentifier, let image = loadImageFromPath(imageIdentifier) {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 24, height: 24)
                                    .clipShape(Circle())
                            } else {
                                Image(systemName: "person.circle")
                                    .font(.system(size: 24))
                            }
                            Text("About")
                                .font(.system(size: 10))
                        }
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
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
        .fullScreenCover(isPresented: $showAbout) {
            AnimeAboutView(anime: $anime, animes: $animes, onClose: { showAbout = false })
                .environmentObject(animeManager)
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
                        
                        // 動画が削除されたことを通知
                        NotificationCenter.default.post(name: Notification.Name("VideoDeleted"), object: nil)
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
                        
                        // 動画が削除されたことを通知
                        NotificationCenter.default.post(name: Notification.Name("VideoDeleted"), object: nil)
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
    
    // YouTubeサムネイルURLを取得
    private func getYouTubeThumbnailURL(from url: String) -> String {
        // YouTubeのビデオIDを抽出
        let videoId: String?
        if url.contains("youtu.be/") {
            videoId = url.components(separatedBy: "youtu.be/").last?.components(separatedBy: "?").first
        } else if url.contains("youtube.com/watch?v=") {
            videoId = url.components(separatedBy: "v=").last?.components(separatedBy: "&").first
        } else {
            videoId = nil
        }
        
        // サムネイルURLを返す
        if let videoId = videoId {
            return "https://img.youtube.com/vi/\(videoId)/maxresdefault.jpg"
        } else {
            return ""
        }
    }
    
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
            
            // 動画が削除されたことを通知
            NotificationCenter.default.post(name: Notification.Name("VideoDeleted"), object: nil)
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
                    Text("Album")
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
    @ViewBuilder
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
                    VStack(spacing: 12) {
                        ForEach(albums) { album in
                            AlbumRowView(album: album, onTap: {
                                selectedAlbum = album
                            })
                            .padding(.horizontal, 16)
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                }
            }
        }
        .navigationDestination(item: $selectedAlbum) { album in
            AlbumVideoListScreen(
                videos: album.videos,
                tag: album.tag,
                onVideoDeleted: { deletedVideo in
                    if let idx = self.videos.firstIndex(where: { $0.id == deletedVideo.id }) {
                        self.videos.remove(at: idx)
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
                                Spacer().frame(height: 15.9)
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
            incrementViewCount(for: video)
        }) {
            HStack(alignment: .top, spacing: 8) {
                // サムネイル
                if let thumbnailData = video.thumbnailData, let uiImage = UIImage(data: thumbnailData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 165, height: 90)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .clipped()
                } else if let youtubeURL = video.youtubeURL {
                    // YouTubeサムネイルを表示
                    AsyncImage(url: URL(string: getYouTubeThumbnailURL(from: youtubeURL))) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .frame(width: 165, height: 90)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .clipped()
                        case .failure(_), .empty:
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: 165, height: 90)
                        @unknown default:
                            EmptyView()
                        }
                    }
                } else {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 165, height: 90)
                }
                
                // タイトルとタグ
                VStack(alignment: .leading, spacing: 2) {
                    Text(video.title)
                        .font(.system(size: 16.5, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.vertical, 4)
                    
                    // ハッシュタグ
                    if let firstTag = video.tags.first {
                        Text("#\(firstTag)")
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(.gray)
                    }
                    
                    Text("\(formatViewCount(video.viewCount ?? 0))回・\(timeAgo(from: video.date))")
                        .font(.system(size: 13.8, weight: .regular))
                        .foregroundColor(.gray)
                        .padding(.vertical, 1)
                }
                .frame(alignment: .leading)
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
                        .rotationEffect(.degrees(90))
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .frame(width: 60, height: 60)
                .contentShape(Rectangle())
                .padding(.trailing, 8)
            }
            .padding(.leading, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // Increment view count for a video
    private func incrementViewCount(for video: MemoryVideo) {
        if let index = videos.firstIndex(where: { $0.id == video.id }) {
            var updatedVideo = videos[index]
            updatedVideo.viewCount = (updatedVideo.viewCount ?? 0) + 1
            videos[index] = updatedVideo
            saveVideosToUserDefaults()
        }
    }
    
    // View count formatter
    private func formatViewCount(_ count: Int) -> String {
        if count >= 10000 {
            let formatted = Double(count) / 10000.0
            return String(format: "%.1f万", formatted)
        } else {
            return "\(count)"
        }
    }
    
    // Time ago formatter
    private func timeAgo(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date, to: now)
        
        if let years = components.year, years > 0 {
            return "\(years)年前"
        } else if let months = components.month, months > 0 {
            return "\(months)ヶ月前"
        } else if let days = components.day, days > 0 {
            return "\(days)日前"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours)時間前"
        } else if let minutes = components.minute, minutes > 0 {
            return "\(minutes)分前"
        } else {
            return "たった今"
        }
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
    @State private var editedRating: Double = 0.0
    @State private var editedVoiceActors: String = ""
    @State private var editedCharacters: String = ""
    @State private var editedWatchLink: String = ""
    @State private var isEditingProfile: Bool = false
    @State private var isEditingDescription: Bool = false
    @State private var showEditSelection: Bool = false
    @State private var showIconPicker: Bool = false
    @State private var iconPickerItem: PhotosPickerItem? = nil
    @State private var newIconImage: UIImage?
    @State private var currentDisplayedIcon: UIImage? = nil
    @State private var showSoundtrackEdit: Bool = false
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
                                Divider().padding(.leading, 20)
                                ratingSelectionRow(label: "レート", rating: $editedRating)
                                Divider().padding(.leading, 20)
                                editableProfileRow(label: "声優", text: $editedVoiceActors, placeholder: "最大5人まで（カンマ区切り）")
                                Divider().padding(.leading, 20)
                                editableProfileRow(label: "出演キャラ", text: $editedCharacters, placeholder: "最大5人まで（カンマ区切り）")
                                Divider().padding(.leading, 20)
                                editableProfileRow(label: "視聴リンク", text: $editedWatchLink)
                            } else {
                                profileRow(label: "タイトル", value: currentAnime.title)
                                Divider().padding(.leading, 20)
                                profileRow(label: "ハッシュタグ", value: currentAnime.hashtag.isEmpty ? "未設定" : currentAnime.hashtag)
                                Divider().padding(.leading, 20)
                                let statusText = currentAnime.watchStatuses.filter { $0 != .none }.map { $0.rawValue }.joined(separator: "、")
                                profileRow(label: "ステータス", value: statusText.isEmpty ? "未設定" : statusText)
                                Divider().padding(.leading, 20)
                                profileRow(label: "レート", value: currentAnime.rating > 0 ? String(format: "%.1f / 5.0", currentAnime.rating) : "未設定")
                                Divider().padding(.leading, 20)
                                profileRow(label: "声優", value: currentAnime.voiceActors.isEmpty ? "未設定" : currentAnime.voiceActors.joined(separator: ", "))
                                Divider().padding(.leading, 20)
                                profileRow(label: "出演キャラ", value: currentAnime.characters.isEmpty ? "未設定" : currentAnime.characters.joined(separator: ", "))
                                Divider().padding(.leading, 20)
                                profileRow(label: "視聴リンク", value: currentAnime.watchLink.isEmpty ? "未設定" : currentAnime.watchLink)
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
                    
                    // サントラセクション
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("サントラ")
                                .font(.system(size: 20, weight: .bold))
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 32)
                        .padding(.bottom, 16)
                        
                        // サントラリスト
                        if currentAnime.soundtracks.isEmpty {
                            Text("サントラが未設定です")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(currentAnime.soundtracks, id: \.id) { soundtrack in
                                    SoundtrackRow(soundtrack: soundtrack) {
                                        // 削除処理
                                        deleteSoundtrack(soundtrack)
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
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
            // 最新のデータを取得して初期化
            let latestAnime = currentAnime
            editedTitle = latestAnime.title
            editedHashtag = latestAnime.hashtag
            editedReleaseDate = latestAnime.releaseDate
            editedWatchStatuses = Set(latestAnime.watchStatuses)
            editedRating = latestAnime.rating
            editedVoiceActors = latestAnime.voiceActors.joined(separator: ", ")
            editedCharacters = latestAnime.characters.joined(separator: ", ")
            editedWatchLink = latestAnime.watchLink
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
                    .default(Text("サントラを編集")) {
                        showSoundtrackEdit = true
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
            .sheet(isPresented: $showSoundtrackEdit) {
                SoundtrackEditView { soundtrack in
                    // サントラを保存
                    guard let idx = animes.firstIndex(where: { $0.id == anime.id }) else { return }
                    var updatedAnime = animes[idx]
                    var soundtracks = updatedAnime.soundtracks
                    soundtracks.append(soundtrack)
                    updatedAnime.soundtracks = soundtracks
                    animes[idx] = updatedAnime
                    animeManager.updateAnime(updatedAnime)
                    anime = updatedAnime
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
    
    private func editableProfileRow(label: String, text: Binding<String>, placeholder: String = "未設定") -> some View {
        HStack {
            Text(label)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
            TextField(placeholder, text: text)
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
    
    private func ratingSelectionRow(label: String, rating: Binding<Double>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
            
            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { index in
                    Button(action: {
                        rating.wrappedValue = Double(index)
                    }) {
                        Image(systemName: index <= Int(rating.wrappedValue) ? "star.fill" : "star")
                            .font(.system(size: 20))
                            .foregroundColor(index <= Int(rating.wrappedValue) ? .yellow : .gray)
                    }
                }
                
                if rating.wrappedValue > 0 {
                    Text(String(format: "%.1f", rating.wrappedValue))
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .padding(.leading, 8)
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
        updatedAnime.rating = editedRating
        
        // 声優リストを処理（カンマ区切りを配列に変換、最大5人まで）
        let voiceActorsList = editedVoiceActors
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(5)
        updatedAnime.voiceActors = Array(voiceActorsList)
        
        // キャラクターリストを処理（カンマ区切りを配列に変換、最大5人まで）
        let charactersList = editedCharacters
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(5)
        updatedAnime.characters = Array(charactersList)
        
        // 視聴リンクを保存
        updatedAnime.watchLink = editedWatchLink
        
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
    
    private func deleteSoundtrack(_ soundtrack: Soundtrack) {
        guard let idx = animes.firstIndex(where: { $0.id == anime.id }) else { return }
        var updatedAnime = animes[idx]
        var soundtracks = updatedAnime.soundtracks
        soundtracks.removeAll { $0.id == soundtrack.id }
        updatedAnime.soundtracks = soundtracks
        animes[idx] = updatedAnime
        animeManager.updateAnime(updatedAnime)
        anime = updatedAnime
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
            VStack(spacing: 0) {
                // ヘッダー
                ZStack {
                    Text("アニメ追加")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                    
                    HStack {
                        Button(action: { dismiss() }) {
                            Text("キャンセル")
                                .foregroundColor(.white)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color(red: 0.6, green: 0.4, blue: 0.9), Color(red: 0.8, green: 0.5, blue: 0.9)]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(20)
                        }
                        
                        Spacer()
                        
                        Button(action: {
                            let newAnime = Anime(id: UUID(), imageIdentifier: savedImagePath, backgroundImagePath: nil, title: title, hashtag: hashtag, releaseDate: Date(), watchStatus: .none, watchStatuses: Array(selectedWatchStatuses))
                            animeManager.addAnimeAtTop(newAnime)
                            dismiss()
                        }) {
                            Text("追加")
                                .foregroundColor(.white)
                                .fontWeight(.bold)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            (title.isEmpty || hashtag.isEmpty) ? Color.gray.opacity(0.3) : Color(red: 0.6, green: 0.4, blue: 0.9),
                                            (title.isEmpty || hashtag.isEmpty) ? Color.gray.opacity(0.3) : Color(red: 0.8, green: 0.5, blue: 0.9)
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(20)
                        }
                        .disabled(title.isEmpty || hashtag.isEmpty)
                    }
                }
                .padding()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // タイトル入力
                        TextField("アニメタイトル", text: $title)
                            .textFieldStyle(PlainTextFieldStyle())
                            .multilineTextAlignment(.center)
                            .padding(.vertical, 8)
                            .overlay(
                                VStack {
                                    Spacer()
                                    Divider()
                                        .background(Color.gray.opacity(0.5))
                                }
                            )
                            .padding(.horizontal)
                        
                        // アイコン画像（四角形）
                        VStack(spacing: 12) {
                            PhotosPicker(selection: $selectedItem, matching: .images) {
                                if let image = image {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 168, height: 168)
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                } else {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 168, height: 168)
                                        .overlay(
                                            Image(systemName: "camera.fill")
                                                .font(.system(size: 56))
                                                .foregroundColor(.gray.opacity(0.6))
                                        )
                                }
                            }
                            Text("アイコン画像を選択")
                                .font(.caption)
                                .foregroundColor(.gray)
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
                        
                        // ハッシュタグ入力
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("ハッシュタグ", text: $hashtag)
                                .textFieldStyle(PlainTextFieldStyle())
                                .padding(.vertical, 8)
                                .overlay(
                                    VStack {
                                        Spacer()
                                        Divider()
                                            .background(Color.gray.opacity(0.5))
                                    }
                                )
                            
                            Text("同じタグを持つアニメでアルバムを作成できます")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .padding(.horizontal)
                        
                        // 視聴ステータス
                        VStack(spacing: 8) {
                            VStack(spacing: 0) {
                                ForEach(WatchStatus.allCases.filter { $0 != .none }, id: \.self) { status in
                                    HStack {
                                        Text(status.rawValue)
                                            .font(.system(size: 15))
                                        Spacer()
                                        if selectedWatchStatuses.contains(status) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.blue)
                                        } else {
                                            Image(systemName: "circle")
                                                .foregroundColor(.gray.opacity(0.4))
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color.gray.opacity(0.05))
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        if selectedWatchStatuses.contains(status) {
                                            selectedWatchStatuses.remove(status)
                                        } else {
                                            selectedWatchStatuses.insert(status)
                                        }
                                    }
                                    
                                    if status != WatchStatus.allCases.filter({ $0 != .none }).last {
                                        Divider()
                                    }
                                }
                            }
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .padding(.horizontal)
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.top, 20)
                }
            }
            .background(Color.white)
            .navigationBarHidden(true)
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
    @State private var showEditGenresModal = false
    @State private var editGenres: Set<AnimeGenre> = []
    @State private var showEditBackgroundModal = false
    @State private var backgroundPickerItem: PhotosPickerItem? = nil
    @State private var backgroundImage: UIImage? = nil
    @State private var currentDisplayedIcon: UIImage? = nil

    var body: some View {
        ZStack {
            // 背景を最初に配置
            let currentAnime = animeManager.animes.first(where: { $0.id == anime.id }) ?? anime
            let titleText = currentAnime.title
            
            // 背景画像 or グラデーション
            if let imagePath = currentAnime.backgroundImagePath,
               let uiImage = loadImageFromPath(imagePath) {
                GeometryReader { geo in
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
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
            
            // コンテンツ
            VStack(alignment: .leading) {
                // 戻るボタン
                HStack {
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
                            Text("Back")
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 1)
                        }
                    }
                    .padding(.top, 24)
                    .padding(.leading, 16)
                    
                    Spacer()
                }
                
                VStack {
                    Spacer().frame(height: 180)
                    // アイコン
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
                    .padding(.top, 30)
                    
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
                    .padding(.top, 20)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .onTapGesture {
                        editWatchStatuses = Set(currentAnime.watchStatuses)
                        showEditWatchStatusModal = true
                    }
                    
                    // ジャンル
                    VStack(spacing: 8) {
                        Text("ジャンル")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 1)
                        if currentAnime.genres.isEmpty {
                            Text("未設定")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.gray)
                        } else {
                            HStack(spacing: 8) {
                                ForEach(currentAnime.genres, id: \.self) { genre in
                                    Text(genre.rawValue)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.purple)
                                        .cornerRadius(12)
                                }
                            }
                        }
                    }
                    .padding(.top, 12)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .onTapGesture {
                        editGenres = Set(currentAnime.genres)
                        showEditGenresModal = true
                    }
                    
                    Spacer()
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
                .zIndex(1)
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
        // ジャンル編集モーダル
        .sheet(isPresented: $showEditGenresModal) {
            VStack(spacing: 20) {
                Text("ジャンルを選択（複数選択可）")
                    .font(.headline)
                ScrollView {
                    VStack(spacing: 12) {
                        ForEach(AnimeGenre.allCases, id: \.self) { genre in
                            Button(action: {
                                if editGenres.contains(genre) {
                                    editGenres.remove(genre)
                                } else {
                                    editGenres.insert(genre)
                                }
                            }) {
                                HStack {
                                    Text(genre.rawValue)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.black)
                                    Spacer()
                                    if editGenres.contains(genre) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.purple)
                                    } else {
                                        Image(systemName: "circle")
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 10)
                                        .fill(editGenres.contains(genre) ? Color.purple.opacity(0.1) : Color(.systemGray6))
                                )
                            }
                        }
                    }
                }
                .frame(maxHeight: 400)
                
                HStack(spacing: 20) {
                    Button("キャンセル") {
                        showEditGenresModal = false
                    }
                    .foregroundColor(.red)
                    
                    Button("保存") {
                        guard let idx = animes.firstIndex(where: { $0.id == anime.id }) else { return }
                        var updatedAnime = animes[idx]
                        updatedAnime.genres = Array(editGenres)
                        animes[idx] = updatedAnime
                        animeManager.updateAnime(updatedAnime)
                        showEditGenresModal = false
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
                                    .frame(height: 176)
                                    .clipped()
                                    .cornerRadius(12)
                            } else if let imagePath = anime.backgroundImagePath,
                                      let uiImage = loadImageFromPath(imagePath) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 176)
                                    .clipped()
                                    .cornerRadius(12)
                            } else {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(height: 176)
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

// MARK: - AlbumRowView
struct AlbumRowView: View {
    let album: Album
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // Background image
                Group {
                    if let firstVideo = album.videos.first, 
                       let thumbnailData = firstVideo.thumbnailData, 
                       let uiImage = UIImage(data: thumbnailData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else if let firstVideo = album.videos.first, 
                              let youtubeThumbnailURL = firstVideo.youtubeThumbnailURL {
                        AsyncImage(url: URL(string: youtubeThumbnailURL)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .overlay(ProgressView())
                        }
                    } else {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.purple.opacity(0.6),
                                        Color.blue.opacity(0.4)
                                    ]),
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                    }
                }
                .frame(height: 180)
                .clipped()
                
                // Gradient overlay
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.clear,
                        Color.black.opacity(0.7)
                    ]),
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 180)
                
                // Text information
                VStack(alignment: .leading) {
                    Spacer()
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(album.tag)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Text("\(album.videos.count)個の動画")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        Spacer()
                    }
                    .padding(16)
                }
                .frame(height: 180)
            }
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// Navigation button style that highlights on press
struct AnimeNavigationButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(configuration.isPressed ? .black : .gray)
    }
}
