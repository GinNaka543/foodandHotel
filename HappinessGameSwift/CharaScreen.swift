import SwiftUI
import PhotosUI
import UIKit
import Foundation
import Photos
// Firebase removed

// キャラクターデータ管理用のObservableObject
class CharacterManager: ObservableObject {
    @Published var characters: [Character] = []
    
    init() {
        // ★ 一時的なリセット処理は削除しました
        loadCharacters()
        
        // ログイン時にデータを再読み込み
        NotificationCenter.default.addObserver(
            forName: Notification.Name("UserDidLogin"),
            object: nil,
            queue: .main
        ) { _ in
            self.loadCharacters()
        }
    }
    
    func loadCharacters() {
        if let data = UserDefaultsHelper.shared.getData(forKey: "characters"),
           let decoded = try? JSONDecoder().decode([Character].self, from: data) {
            characters = decoded
        } else {
            characters = []
        }
    }
    
    func saveCharacters() {
        if let data = try? JSONEncoder().encode(characters) {
            UserDefaultsHelper.shared.setData(data, forKey: "characters")
            
            // Force synchronization to ensure data is persisted immediately
            UserDefaults.standard.synchronize()
            
            // Save characters locally only - Firebase removed
            print("📝 Characters saved: \(characters.count) items")
            for (index, character) in characters.enumerated() {
                print("  \(index + 1). \(character.name) (ID: \(character.id))")
            }
        } else {
            // print("❌ Failed to encode characters")
        }
    }
    
    func updateCharacter(_ updatedCharacter: Character) {
        if let idx = characters.firstIndex(where: { $0.id == updatedCharacter.id }) {
            characters[idx] = updatedCharacter
            saveCharacters()
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        } else {
        }
    }
    
    func addCharacter(_ character: Character) {
        let exists = characters.contains { $0.id == character.id }
        if !exists {
            characters.append(character)
            saveCharacters()
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }
    
    func deleteCharacter(_ character: Character) {
        // Delete associated images
        if let imagePath = character.imageIdentifier {
            deleteImageFromPath(imagePath)
        }
        if let bgPath = character.backgroundImagePath {
            deleteImageFromPath(bgPath)
        }
        
        characters.removeAll { $0.id == character.id }
        saveCharacters()
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    private func deleteImageFromPath(_ imagePath: String) {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imageURL = documentsPath.appendingPathComponent(imagePath)
        try? FileManager.default.removeItem(at: imageURL)
    }
    
    // UI更新用のメソッド
    func refreshUI() {
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    // 新規キャラクターを先頭に追加
    func addCharacterAtTop(_ character: Character) {
        var newCharacter = character
        newCharacter.order = 0
        
        // 他のキャラクターの順番を1つずつ増やす
        for i in 0..<characters.count {
            characters[i].order += 1
        }
        
        characters.insert(newCharacter, at: 0)
        saveCharacters()
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    // キャラクターの順番を移動
    func moveCharacter(from source: IndexSet, to destination: Int) {
        characters.move(fromOffsets: source, toOffset: destination)
        
        // 順番を更新
        for (index, _) in characters.enumerated() {
            characters[index].order = index
        }
        
        saveCharacters()
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
}

// カスタムフィールド用構造体
struct CustomField: Hashable, Codable {
    var name: String
    var value: String
}

// キャラクターランキング用構造体
struct CharacterRanking: Identifiable, Codable {
    var id = UUID()
    var characterId: UUID
    var rank: Int // 1-7位
    var characterName: String // 表示用
    var characterImagePath: String? // 表示用
    var externalLink: String? // 外部リンク（Firebase削除済み）
    
    init(characterId: UUID, rank: Int, characterName: String, characterImagePath: String? = nil, externalLink: String? = nil) {
        self.characterId = characterId
        self.rank = rank
        self.characterName = characterName
        self.characterImagePath = characterImagePath
        self.externalLink = externalLink
    }
}

// キャラクターランキング管理クラス
class CharacterRankingManager: ObservableObject {
    @Published var rankings: [CharacterRanking] = []
    
    init() {
        loadRankings()
        
        // ログイン時にデータを再読み込み
        NotificationCenter.default.addObserver(
            forName: Notification.Name("UserDidLogin"),
            object: nil,
            queue: .main
        ) { _ in
            self.loadRankings()
        }
    }
    
    func loadRankings() {
        if let data = UserDefaultsHelper.shared.getData(forKey: "characterRankings"),
           let decoded = try? JSONDecoder().decode([CharacterRanking].self, from: data) {
            rankings = decoded.sorted { $0.rank < $1.rank }
        }
    }
    
    func saveRankings() {
        if let data = try? JSONEncoder().encode(rankings) {
            UserDefaultsHelper.shared.setData(data, forKey: "characterRankings")
        }
    }
    
    func updateRanking(characterId: UUID, rank: Int, characterName: String, characterImagePath: String?) {
        if let index = rankings.firstIndex(where: { $0.rank == rank }) {
            rankings[index] = CharacterRanking(characterId: characterId, rank: rank, characterName: characterName, characterImagePath: characterImagePath)
        } else {
            rankings.append(CharacterRanking(characterId: characterId, rank: rank, characterName: characterName, characterImagePath: characterImagePath))
        }
        rankings.sort { $0.rank < $1.rank }
        saveRankings()
    }
    
    func removeRanking(rank: Int) {
        rankings.removeAll { $0.rank == rank }
        saveRankings()
    }
    
    func getRanking(for rank: Int) -> CharacterRanking? {
        return rankings.first { $0.rank == rank }
    }
}

struct Character: Identifiable, Hashable, Equatable, Codable {
    let id: UUID
    var imageIdentifier: String? // PhotoライブラリのassetIdentifier
    var backgroundImagePath: String? // 背景画像のパス
    var name: String
    var favoriteFood: String
    var age: String // 年齢
    // var cupSize: String // カップ数 (removed)
    var seichi: String // 聖地
    var height: String // 身長
    var customFields: [CustomField]? // カスタムフィールド
    var order: Int = 0 // 表示順序用フィールド
    var iconScale: Double = 1.0 // アイコンの拡大率
    var iconOffsetX: Double = 0.0 // アイコンの横方向オフセット
    var iconOffsetY: Double = 0.0 // アイコンの縦方向オフセット

    static func == (lhs: Character, rhs: Character) -> Bool {
        lhs.id == rhs.id
    }
    // Codable対応
    enum CodingKeys: String, CodingKey {
        case id, imageIdentifier, backgroundImagePath, name, favoriteFood, age, seichi, height, customFields, order, iconScale, iconOffsetX, iconOffsetY
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(favoriteFood, forKey: .favoriteFood)
        try container.encode(age, forKey: .age)
        // try container.encode(cupSize, forKey: .cupSize) // removed
        try container.encode(seichi, forKey: .seichi)
        try container.encode(height, forKey: .height)
        try container.encodeIfPresent(imageIdentifier, forKey: .imageIdentifier)
        try container.encodeIfPresent(backgroundImagePath, forKey: .backgroundImagePath)
        try container.encodeIfPresent(customFields, forKey: .customFields)
        try container.encode(order, forKey: .order)
        try container.encode(iconScale, forKey: .iconScale)
        try container.encode(iconOffsetX, forKey: .iconOffsetX)
        try container.encode(iconOffsetY, forKey: .iconOffsetY)
    }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        favoriteFood = (try? container.decode(String.self, forKey: .favoriteFood)) ?? ""
        age = (try? container.decode(String.self, forKey: .age)) ?? ""
        // cupSize = (try? container.decode(String.self, forKey: .cupSize)) ?? "" // removed
        seichi = (try? container.decode(String.self, forKey: .seichi)) ?? ""
        height = (try? container.decode(String.self, forKey: .height)) ?? ""
        imageIdentifier = try? container.decodeIfPresent(String.self, forKey: .imageIdentifier)
        backgroundImagePath = try? container.decodeIfPresent(String.self, forKey: .backgroundImagePath)
        customFields = try? container.decodeIfPresent([CustomField].self, forKey: .customFields)
        order = (try? container.decode(Int.self, forKey: .order)) ?? 0
        iconScale = (try? container.decode(Double.self, forKey: .iconScale)) ?? 1.0
        iconOffsetX = (try? container.decode(Double.self, forKey: .iconOffsetX)) ?? 0.0
        iconOffsetY = (try? container.decode(Double.self, forKey: .iconOffsetY)) ?? 0.0
    }
    init(id: UUID, imageIdentifier: String?, backgroundImagePath: String? = nil, name: String, favoriteFood: String = "", age: String, seichi: String, height: String, customFields: [CustomField]? = nil, order: Int = 0, iconScale: Double = 1.0, iconOffsetX: Double = 0.0, iconOffsetY: Double = 0.0) {
        self.id = id
        self.imageIdentifier = imageIdentifier
        self.backgroundImagePath = backgroundImagePath
        self.name = name
        self.favoriteFood = favoriteFood
        self.age = age
        // self.cupSize = cupSize // removed
        self.seichi = seichi
        self.height = height
        self.customFields = customFields
        self.order = order
        self.iconScale = iconScale
        self.iconOffsetX = iconOffsetX
        self.iconOffsetY = iconOffsetY
    }
}

struct CharaScreen: View {
    @EnvironmentObject var characterManager: CharacterManager
    @EnvironmentObject var mainTab: MainTabSelection
    @State private var showAddSheet = false
    @State private var selectedCharacter: Character? = nil
    @State private var showRankingAdmin = false
    @State private var showNavigationMenu = false
    @State private var showPrivacyPolicy = false
    @State private var bannerTimer: Timer? = nil
    @State private var bannerVideo: MemoryVideo? = nil
    @State private var allYouTubeVideos: [MemoryVideo] = []
    @State private var displayedVideoIds: Set<UUID> = []
    @State private var refreshID = UUID() // 強制リフレッシュ用のID
    
    var filteredCharacters: [Character] {
        // Filter out characters without names first
        let charactersWithNames = characterManager.characters.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        // Sort by order
        return charactersWithNames.sorted(by: { $0.order < $1.order })
    }

    var body: some View {
        ZStack {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    HStack {
                        // 左上メニューボタン
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
                        // 右上＋ボタン
                        Button(action: { showAddSheet = true }) {
                            Text(NSLocalizedString("add_character", comment: ""))
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
                .padding(.bottom, 8)
                // スクロール可能なコンテンツ
                ScrollView {
                    VStack(spacing: 0) {
                        // 広告バナー
                        bannerView
                            .id(refreshID) // 強制リフレッシュ用
                            .padding(.bottom, 16)
                        
                        // キャラリスト
                        if filteredCharacters.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "person.2.square.stack")
                                    .font(.system(size: 50))
                                    .foregroundColor(.purple)
                                Text(NSLocalizedString("add_favorite_character", comment: ""))
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.black)
                                Text(NSLocalizedString("manage_character_info", comment: ""))
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)
                                
                                Button(action: { showAddSheet = true }) {
                                    HStack {
                                        Image(systemName: "plus")
                                        Text(NSLocalizedString("add_character_button", comment: ""))
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
                            ForEach(filteredCharacters, id: \.id) { character in
                                Button(action: {
                                    selectedCharacter = character
                                }) {
                                    CharacterRow(character: character, characterManager: characterManager)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        
                        Spacer(minLength: 75) // ナビゲーションバーの高さ分のパディング
                    }
                }
            }
            
            // サントラプレイヤービュー
            VStack {
                Spacer()
                    .padding(.bottom, 70) // タブバーの上に表示
            }
        }
        .sheet(isPresented: $showAddSheet, onDismiss: {
            characterManager.loadCharacters()
        }) {
            AddCharacterSheet(characters: $characterManager.characters)
                .environmentObject(characterManager)
        }
        .sheet(isPresented: $showRankingAdmin) {
            CharacterRankingAdminView()
        }
        .sheet(isPresented: $mainTab.showCharacterOrderModal, onDismiss: {
            // モーダルを閉じたときにデータを再読み込み
            characterManager.loadCharacters()
        }) {
            CharacterOrderModal()
                .environmentObject(characterManager)
        }
        .sheet(isPresented: $showPrivacyPolicy) {
            PrivacyPolicyView(hasAgreed: .constant(true), isInitialAgreement: false)
        }
        .onAppear {
            // YouTube動画を収集
            loadYouTubeVideos()
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
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("VideoDataUpdated"))) { _ in
            // 動画データが更新された時にバナーを更新
            // print("🔄 [CharaScreen] Received VideoDataUpdated notification - refreshing banner")
            bannerVideo = nil  // 現在のバナーをクリア
            displayedVideoIds.removeAll()  // 表示履歴をリセット
            allYouTubeVideos = []  // 既存の動画リストをクリア
            loadYouTubeVideos()
            refreshID = UUID()  // ビューを強制的にリフレッシュ
        }
        .onDisappear {
            bannerTimer?.invalidate()
        }
        .fullScreenCover(item: $selectedCharacter) { character in
            CharacterDetailView(character: Binding(
                get: { 
                    // 常に最新のデータを返す
                    characterManager.characters.first(where: { $0.id == character.id }) ?? character
                },
                set: { newCharacter in
                    if let idx = characterManager.characters.firstIndex(where: { $0.id == character.id }) {
                        characterManager.characters[idx] = newCharacter
                        characterManager.updateCharacter(newCharacter)
                    }
                    selectedCharacter = newCharacter
                }
            ), characters: $characterManager.characters, onDismiss: { 
                selectedCharacter = nil
                // 詳細画面を閉じた後にUIを更新
                characterManager.refreshUI()
            })
            .environmentObject(characterManager)
        }
        
    }
    .overlay(
        Group {
            if showNavigationMenu {
                NavigationMenuView(
                    isPresented: $showNavigationMenu,
                    onShowCharacterOrder: nil,
                    onShowAnimeOrder: nil,
                    onShowPrivacyPolicy: {
                        showPrivacyPolicy = true
                    }
                )
                .transition(.opacity)
                .zIndex(2)
            }
        }
    )
    }
    // UserDefaults保存・読込
    private func saveCharacters() {
        characterManager.saveCharacters()
    }
    
    // バナービュー（簡素化版 - デバッグ用）
    private var bannerView: some View {
        // let _ = print("🎯 [CharaScreen] bannerView called. bannerVideo exists: \(bannerVideo != nil)")
        
        return Group {
            if let video = bannerVideo, let youtubeURL = video.youtubeURL, !youtubeURL.isEmpty {
                // let _ = print("🔍 [CharaScreen] Found banner video: \(video.title) with YouTube URL: \(youtubeURL)")
                
                VStack {
                    // First check for custom thumbnail data
                    if let thumbnailData = video.thumbnailData,
                       let thumbnailImage = UIImage(data: thumbnailData) {
                        // let _ = print("🖼️ [CharaScreen] Using custom thumbnail data")
                        Image(uiImage: thumbnailImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(height: 180)
                            .clipped()
                            .id("\(video.id)_\(video.thumbnailData?.hashValue ?? 0)") // Force view refresh when thumbnail changes
                    } else if let thumbnailURL = video.youtubeThumbnailURL, !thumbnailURL.isEmpty {
                        // let _ = print("🖼️ [CharaScreen] Using YouTube thumbnail: \(thumbnailURL)")
                        AsyncImage(url: URL(string: thumbnailURL)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 180)
                                .clipped()
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 180)
                                .overlay(
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                )
                        }
                    } else {
                        // youtubeThumbnailURLが空の場合、URLから自動生成
                        let generatedThumbnailURL = getYouTubeThumbnailURLForBanner(from: youtubeURL)
                        // let _ = print("🎬 [CharaScreen] Generated thumbnail URL from video URL: \(generatedThumbnailURL)")
                        
                        AsyncImage(url: URL(string: generatedThumbnailURL)) { image in
                            image
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 180)
                                .clipped()
                        } placeholder: {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 180)
                                .overlay(
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                )
                        }
                    }
                }
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 12, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 12))
                .overlay(
                    VStack {
                        Spacer()
                        HStack {
                            VStack(alignment: .leading) {
                                Text(video.title.formatVideoTitle())
                                    .foregroundColor(.white)
                                    .font(.headline)
                                    .multilineTextAlignment(.leading)
                                    .shadow(color: .black.opacity(0.7), radius: 2)
                                if let viewCount = video.viewCount {
                                    Text("\(viewCount.formatted()) views")
                                        .foregroundColor(.white.opacity(0.8))
                                        .font(.caption)
                                        .shadow(color: .black.opacity(0.7), radius: 2)
                                }
                            }
                            Spacer()
                            Image(systemName: "play.circle.fill")
                                .foregroundColor(.white)
                                .font(.title)
                                .shadow(color: .black.opacity(0.7), radius: 2)
                        }
                        .padding()
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.clear, Color.black.opacity(0.6)]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                    }
                )
                .onTapGesture {
                    if let url = URL(string: youtubeURL) {
                        UIApplication.shared.open(url)
                    }
                }
                .padding(.horizontal, 16)
            } else {
                // YouTube動画が登録されていない場合の表示
                ZStack {
                    AnimatedGradientView()
                        .frame(width: UIScreen.main.bounds.width - 32, height: 180)
                        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 12, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 12))
                    
                    VStack {
                        Spacer()
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Image(systemName: "play.rectangle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white)
                                    .shadow(radius: 4)
                                    .padding(.bottom, 4)
                                
                                Text(NSLocalizedString("from_youtube", comment: ""))
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundColor(.white)
                                    .shadow(radius: 2)
                                Text(NSLocalizedString("register_video", comment: ""))
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
                .padding(.horizontal, 16)
            }
        }
    }
    
    // バナーローテーションタイマー開始
    private func startBannerRotation() {
        bannerTimer?.invalidate()
        
        // YouTube動画がある場合のみローテーション
        if !allYouTubeVideos.isEmpty {
            bannerTimer = Timer.scheduledTimer(withTimeInterval: 7.0, repeats: true) { _ in
                // 新しい動画を選択
                self.selectRandomYouTubeVideo()
            }
        }
    }
    
    // YouTube動画を収集
    private func loadYouTubeVideos() {
        // print("🔍 [CharaScreen] Loading YouTube videos...")
        // print("🔍 [CharaScreen] Total characters available: \(characterManager.characters.count)")
        
        // UserDefaultsの全キーを確認
        let allKeys = UserDefaults.standard.dictionaryRepresentation().keys
        let _ = allKeys.filter { $0.contains("video") }
        // print("🔍 [CharaScreen] All video-related keys in UserDefaults: \(videoKeys)")
        
        allYouTubeVideos = []
        for character in characterManager.characters {
            // VideoStorage.swiftを使用して動画を取得
            let videos = VideoStorage.shared.loadVideos(for: character.id.uuidString)
            // print("🔍 [CharaScreen] VideoStorage returned \(videos.count) videos for character: \(character.name)")
            if !videos.isEmpty {
                // print("🔍 [CharaScreen] Found \(videos.count) total videos for character: \(character.name)")
                // YouTube URLを持つ動画のみをフィルタリング
                let youtubeVideos = videos.filter { $0.youtubeURL != nil && !$0.youtubeURL!.isEmpty }
                allYouTubeVideos.append(contentsOf: youtubeVideos)
                // print("🔍 [CharaScreen] Found \(youtubeVideos.count) YouTube videos for character: \(character.name)")
                
                // 個別の動画情報も出力
                for video in videos {
                    if let youtubeURL = video.youtubeURL, !youtubeURL.isEmpty {
                        print("🎥 [CharaScreen] YouTube video: \(video.title) - URL: \(youtubeURL)")
                    } else {
                        // print("📱 [CharaScreen] Local video: \(video.title)")
                    }
                }
            } else {
                // print("❌ [CharaScreen] No video data found for character: \(character.name)")
            }
        }
        // print("🔍 [CharaScreen] Total YouTube videos found: \(allYouTubeVideos.count)")
        
        // 初回のバナー動画を選択
        if !allYouTubeVideos.isEmpty {
            selectRandomYouTubeVideo()
            startBannerRotation()
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

struct HeaderView: View {
    @Binding var showAddSheet: Bool
    @Binding var showSearchBar: Bool
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Text("Chara")
                    .font(.system(size: 32, weight: .bold))
                Spacer()
                HStack(spacing: 20) {
                    Button(action: { showSearchBar.toggle() }) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 17, weight: .medium))
                            .offset(y: 3)
                    }
                    Button(action: { showAddSheet = true }) {
                        Text("+")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.black)
                    }
                }
                .foregroundColor(.black)
                .padding(.trailing, 5)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 4)
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color(.systemGray3))
                .font(.system(size: 18))
            TextField("Search", text: $text)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .font(.system(size: 16))
                .foregroundColor(.black)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .frame(height: 44)
        .padding(.horizontal, 16)
    }
}

struct CharacterRow: View {
    let character: Character
    @ObservedObject var characterManager: CharacterManager
    
    // 最新のキャラクター情報を取得
    private var currentCharacter: Character {
        characterManager.characters.first(where: { $0.id == character.id }) ?? character
    }
    
    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            if let imageIdentifier = currentCharacter.imageIdentifier {
                // 画像パスをIDとして使用して、パスが変わったときに確実に再描画されるようにする
                OptimizedFileImage(
                    path: imageIdentifier,
                    targetSize: CGSize(width: 48, height: 48)
                )
                .aspectRatio(contentMode: .fill)
                .frame(width: 48, height: 48)
                .clipShape(Circle())
                .id(imageIdentifier) // パスが変わったときに強制的に再作成
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: "person")
                            .font(.system(size: 24))
                            .foregroundColor(.gray)
                    )
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(currentCharacter.name)
                    .font(.system(size: 17, weight: .semibold))
            }
            Spacer()
                .foregroundColor(.gray)
                .padding(.top, 4)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .multilineTextAlignment(.trailing)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 0)
        .background(Color.clear)
        .contentShape(Rectangle())
    }
}

struct AddCharacterSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var characters: [Character]
    @EnvironmentObject private var characterManager: CharacterManager
    @State private var name = ""
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var image: UIImage? = nil
    @State private var savedImagePath: String? = nil
    // 事前にキャラクターIDを生成
    @State private var characterId: String = UUID().uuidString

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ヘッダー
                ZStack {
                    Text(NSLocalizedString("add_character", comment: ""))
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                    
                    HStack {
                        Button(action: { dismiss() }) {
                            Text(NSLocalizedString("cancel", comment: ""))
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
                            let newChar = Character(id: UUID(uuidString: characterId) ?? UUID(), imageIdentifier: savedImagePath, name: name, favoriteFood: "", age: "", seichi: "", height: "", customFields: nil)
                            characterManager.addCharacterAtTop(newChar)
                            dismiss()
                        }) {
                            Text(NSLocalizedString("add", comment: ""))
                                .foregroundColor(.white)
                                .fontWeight(.bold)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 8)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            name.isEmpty ? Color.gray.opacity(0.3) : Color(red: 0.6, green: 0.4, blue: 0.9),
                                            name.isEmpty ? Color.gray.opacity(0.3) : Color(red: 0.8, green: 0.5, blue: 0.9)
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(20)
                        }
                        .disabled(name.isEmpty)
                    }
                }
                .padding()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 名前入力
                        TextField(NSLocalizedString("character_name", comment: ""), text: $name)
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
                        
                        // アイコン画像
                        VStack(spacing: 12) {
                            PhotosPicker(selection: $selectedItem, matching: .images) {
                                if let image = image {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 168, height: 168)
                                        .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(Color.gray.opacity(0.2))
                                        .frame(width: 168, height: 168)
                                        .overlay(
                                            Image(systemName: "camera.fill")
                                                .font(.system(size: 56))
                                                .foregroundColor(.gray.opacity(0.6))
                                        )
                                }
                            }
                            Text(NSLocalizedString("select_icon_image", comment: ""))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .onChange(of: selectedItem) { _, newValue in
                            if let newItem = newValue {
                                Task {
                                    if let data = try? await newItem.loadTransferable(type: Data.self), let uiImage = UIImage(data: data) {
                                        image = uiImage
                                        // 事前に生成されたキャラクターIDを使用
                                        let fileName = "character_icon_\(UUID().uuidString).png"
                                        if let path = saveImageToCharacterFolder(uiImage, characterId: characterId, fileName: fileName) {
                                            savedImagePath = path
                                        }
                                    }
                                }
                            }
                        }
                        
                        
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


struct CharacterDetailView: View {
    @Binding var character: Character
    @Binding var characters: [Character]
    var onDismiss: (() -> Void)? = nil
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var characterManager: CharacterManager
    @State private var showArtwork = false
    @State private var showVideo = false
    @State private var showAbout = false
    @State private var showEditBackgroundModal = false
    @State private var showEditIconModal = false // ← 追加
    @State private var showEditTitleTagModal = false
    @State private var showIconAdjustment = false // アイコン位置調整モーダル
    @State private var iconPickerItem: PhotosPickerItem? = nil
    @State private var iconImage: UIImage? = nil
    @State private var tempIconImage: UIImage? = nil
    @State private var backgroundPickerItem: PhotosPickerItem? = nil
    @State private var backgroundImage: UIImage? = nil
    @State private var isProcessingIcon = false
    @State private var showIconUpdateSuccess = false
    
    // バナー管理用の変数を追加
    @State private var bannerVideo: MemoryVideo? = nil
    @State private var bannerTimer: Timer? = nil
    @State private var allYouTubeVideos: [MemoryVideo] = []
    @State private var displayedVideoIds: Set<UUID> = []
    @State private var refreshID = UUID() // 強制リフレッシュ用のID
    
    // 最新のキャラクター情報を取得
    private var currentCharacter: Character {
        characterManager.characters.first(where: { $0.id == character.id }) ?? character
    }

    @ViewBuilder
    private var backgroundView: some View {
        if let backgroundPath = currentCharacter.backgroundImagePath,
           let bgImage = loadImageFromPath(backgroundPath) {
            GeometryReader { geo in
                Image(uiImage: bgImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }
            .ignoresSafeArea()
            .overlay(Color.black.opacity(0.35).ignoresSafeArea())
        } else {
            LinearGradient(
                gradient: Gradient(colors: [Color(red: 0.4, green: 0.6, blue: 0.9), Color(red: 0.3, green: 0.5, blue: 0.8)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        }
    }
    
    @ViewBuilder
    private var profileIconView: some View {
        Button(action: { showEditIconModal = true }) {
            ZStack {
                // 常に最新のデータを表示
                let latestCharacter = characterManager.characters.first(where: { $0.id == character.id }) ?? character
                if let imageIdentifier = latestCharacter.imageIdentifier, let image = loadImageFromPath(imageIdentifier) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .shadow(radius: 8)
                } else {
                    ZStack {
                        Circle()
                            .fill(Color(.systemGray5))
                            .frame(width: 120, height: 120)
                            .shadow(radius: 8)
                            .overlay(
                                Circle().stroke(Color.white, lineWidth: 2)
                            )
                        Image(systemName: "person")
                            .font(.system(size: 50))
                            .foregroundColor(.gray)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
        .id(characterManager.characters.first(where: { $0.id == character.id })?.imageIdentifier ?? UUID().uuidString)
    }
    
    @ViewBuilder
    private var actionButtons: some View {
        HStack {
            Spacer()
            Button(action: { showArtwork = true }) {
                VStack(spacing: 4) {
                    Image(systemName: "photo.on.rectangle")
                        .foregroundColor(.white)
                        .font(.system(size: 24))
                    Text(NSLocalizedString("artwork", comment: "Artwork")).font(.caption2).foregroundColor(.white)
                }
                .frame(width: 90, height: 70)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            Spacer()
            Button(action: { showVideo = true }) {
                VStack(spacing: 4) {
                    Image(systemName: "video")
                        .foregroundColor(.white)
                        .font(.system(size: 24))
                    Text(NSLocalizedString("video", comment: "Video")).font(.caption2).foregroundColor(.white)
                }
                .frame(width: 90, height: 70)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            Spacer()
            Button(action: { showAbout = true }) {
                VStack(spacing: 4) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.white)
                        .font(.system(size: 24))
                    Text(NSLocalizedString("about", comment: "About")).font(.caption2).foregroundColor(.white)
                }
                .frame(width: 90, height: 70)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())
            Spacer()
        }
        .padding(.top, 30)
        .padding(.bottom, 20)
    }
    
    @ViewBuilder
    private var backButton: some View {
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
    }
    
    var body: some View {
        ZStack {
            // 背景を最初に配置
            backgroundView
            
            // コンテンツ
            VStack(alignment: .leading) {
                // 戻るボタン
                backButton
                
                VStack {
                    Spacer().frame(height: 180)
                    // アイコン
                    profileIconView
                    // 名前
                    Text(currentCharacter.name)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 1)
                        .padding(.top, 20)
                        .onTapGesture {
                            showEditTitleTagModal = true
                        }
                        .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 1)
                        .padding(.top, 4)
                    // ボタン群
                    actionButtons
                    Spacer()
                }
                .zIndex(1)
            }
            // モーダル・ページ遷移
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
                        Text(NSLocalizedString("select_icon", comment: ""))
                            .font(.system(size: 20, weight: .bold))
                            .padding(.top, 16)
                        
                        PhotosPicker(selection: $iconPickerItem, matching: .images) {
                            ZStack {
                                if let tempIconImage = tempIconImage {
                                    Image(uiImage: tempIconImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 150, height: 150)
                                        .clipShape(Circle())
                                } else if let imageIdentifier = currentCharacter.imageIdentifier, let image = loadImageFromPath(imageIdentifier) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 150, height: 150)
                                        .clipShape(Circle())
                                } else {
                                    Circle()
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
                        .onChange(of: iconPickerItem) { _, newValue in
                            if let newItem = newValue {
                                Task {
                                    if let data = try? await newItem.loadTransferable(type: Data.self), let uiImage = UIImage(data: data) {
                                        tempIconImage = uiImage
                                        let fileName = "character_icon_\(UUID().uuidString).png"
                                        let imagePath = saveImageToCharacterFolder(uiImage, characterId: currentCharacter.id.uuidString, fileName: fileName)
                                        
                                        // 古い画像ファイルの削除はupdateCharacterに任せる
                                        // print("🔄 [CharaScreen-DetailView] Icon will be updated from \(currentCharacter.imageIdentifier ?? "nil") to \(imagePath ?? "nil")")
                                        
                                        // 最新のデータを取得
                                        if let latestCharacter = characterManager.characters.first(where: { $0.id == character.id }) {
                                            var updatedCharacter = latestCharacter
                                            updatedCharacter.imageIdentifier = imagePath
                                            // backgroundImagePathは最新のデータから保持される
                                            
                                            // CharacterManagerを通じて更新
                                            characterManager.updateCharacter(updatedCharacter)
                                            characterManager.refreshUI()
                                            
                                            // Bindingも更新
                                            character = updatedCharacter
                                            
                                            // charactersリストも更新
                                            if let idx = characters.firstIndex(where: { $0.id == updatedCharacter.id }) {
                                                characters[idx] = updatedCharacter
                                            }
                                        }
                                        
                                        // モーダルを自動的に閉じる
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                            showEditIconModal = false
                                        }
                                    }
                                }
                            }
                        }
                        
                        Text(NSLocalizedString("tap_to_change_image", comment: ""))
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
                .onDisappear {
                    // モーダルが閉じたときにクリーンアップ
                    tempIconImage = nil
                    iconPickerItem = nil
                }
            }
            .sheet(isPresented: $showEditBackgroundModal, onDismiss: {
                // 背景編集モーダルが閉じた時の処理
                // CharacterManagerから最新のデータを取得するだけで、characterは更新しない
                // （EditBackgroundViewが既に更新しているはずなので）
                if let latestChar = characterManager.characters.first(where: { $0.id == character.id }) {
                    // characterの背景が古い場合のみ更新
                    if character.backgroundImagePath != latestChar.backgroundImagePath {
                        character = latestChar
                        if let idx = characters.firstIndex(where: { $0.id == latestChar.id }) {
                            characters[idx] = latestChar
                        }
                    }
                }
            }) {
                EditBackgroundView(character: $character, characterManager: characterManager)
            }
            .fullScreenCover(isPresented: $showArtwork) {
                // 最新のキャラクター情報を渡す
                ArtworkScreen(character: characterManager.characters.first(where: { $0.id == character.id }) ?? character)
                    .environmentObject(characterManager)
            }
            .fullScreenCover(isPresented: $showVideo, onDismiss: {
                // VideoGalleryScreenから戻った時に強制的にリフレッシュ
                // print("🔄 [CharacterDetailView] VideoGalleryScreen dismissed - force refreshing")
                bannerVideo = nil
                allYouTubeVideos = []
                displayedVideoIds.removeAll()
                loadYouTubeVideosForDetail()
            }) {
                VideoGalleryScreen(character: character)
                    .environmentObject(characterManager)
            }
            .onDisappear {
                // タイマーを停止
                bannerTimer?.invalidate()
            }
            .fullScreenCover(isPresented: $showAbout, onDismiss: {
                // アバウトページから戻った時に最新のデータを反映
                characterManager.loadCharacters()
                
                // 最新のキャラクター情報を取得して更新
                if let updatedCharacter = characterManager.characters.first(where: { $0.id == character.id }) {
                    character = updatedCharacter
                    
                    // サウンドトラックが追加されている場合は再生を開始
                    if !updatedCharacter.soundtracks.isEmpty {
                        SoundtrackManager.shared.collectAllSoundtracks(
                            characters: [updatedCharacter],
                            animes: []
                        )
                        if !SoundtrackManager.shared.isPlaying {
                            SoundtrackManager.shared.startRandomPlayback()
                        }
                    }
                    
                    // UIを強制的に更新
                    DispatchQueue.main.async {
                        characterManager.objectWillChange.send()
                        refreshID = UUID()
                    }
                }
            }) {
                AboutView(characters: $characters, characterId: character.id, onClose: { 
                    showAbout = false
                })
                    .environmentObject(characterManager)
            }
            .sheet(isPresented: $showEditTitleTagModal) {
                EditTitleTagBackgroundView(
                    character: $character,
                    characterManager: characterManager
                )
            }
            // アイコン位置調整モーダル
            .sheet(isPresented: $showIconAdjustment, onDismiss: {
                // アイコン調整後にUIを更新
                characterManager.refreshUI()
                refreshID = UUID() // Force refresh the banner view
            }) {
                CharacterIconAdjustmentView(character: $character, characterManager: characterManager)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            // デバッグ情報を表示
            let currentCharacter = characterManager.characters.first(where: { $0.id == character.id }) ?? character
            if let backgroundPath = currentCharacter.backgroundImagePath {
                if loadImageFromPath(backgroundPath) != nil {
                } else {
                }
            } else {
            }
            
            // 音楽の自動準備・自動再生は一切行わない
            // ユーザーが「音楽を再生」ボタンを押した時のみ処理される
            
            // CharacterDetailView用のバナー初期化
            loadYouTubeVideosForDetail()
            
            // ビデオ更新通知を受信
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("VideoDataUpdated"),
                object: nil,
                queue: .main
            ) { _ in
                // print("🔄 [CharacterDetailView] Received VideoDataUpdated notification")
                // バナーを強制的にクリアしてから再読み込み
                bannerVideo = nil
                allYouTubeVideos = []
                displayedVideoIds.removeAll()
                // タイマーも一度停止
                bannerTimer?.invalidate()
                // 遅延を入れて確実にリフレッシュ
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    loadYouTubeVideosForDetail()
                }
            }
        }
        // サントラプレイヤーを下部に表示
        .overlay(
            VStack {
                Spacer()
                SoundtrackPlayerView()
                    .padding(.bottom, 40)
            }
        )
        // 音楽再生ボタン（プレイヤーが非表示の時のみ表示）
        .overlay(
            PlayMusicButtonViewForCharacter(character: currentCharacter)
        )
        .onDisappear {
            // ページから離れる時に音楽を完全に停止してリセット
            SoundtrackManager.shared.stopPlayback()
            SoundtrackManager.shared.isPlayerVisible = false
        }
    }
    
    // MARK: - Banner Management Functions
    private func loadYouTubeVideosForDetail() {
        // print("🎬 [CharacterDetailView] Loading YouTube videos for banner")
        
        // VideoStorage経由で動画を取得
        let videos = VideoStorage.shared.loadVideos(for: character.id.uuidString)
        allYouTubeVideos = videos.filter { video in
            video.youtubeURL != nil && 
            !video.youtubeURL!.isEmpty
        }
        
        // print("🎬 [CharacterDetailView] Found \(allYouTubeVideos.count) YouTube videos")
        
        // 最初のランダム動画を選択
        selectRandomYouTubeVideoForDetail()
        
        // バナーローテーションを開始
        startBannerRotationForDetail()
    }
    
    private func selectRandomYouTubeVideoForDetail() {
        guard !allYouTubeVideos.isEmpty else {
            // print("❌ [CharacterDetailView] No YouTube videos available")
            bannerVideo = nil
            return
        }
        
        // 表示されていない動画がある場合はそれを優先
        let unDisplayedVideos = allYouTubeVideos.filter { !displayedVideoIds.contains($0.id) }
        
        let availableVideos = unDisplayedVideos.isEmpty ? allYouTubeVideos : unDisplayedVideos
        
        if let randomVideo = availableVideos.randomElement() {
            bannerVideo = randomVideo
            displayedVideoIds.insert(randomVideo.id)
            // print("🎬 [CharacterDetailView] Selected random video: \(randomVideo.title)")
            
            // 全動画を表示し終わったらリセット
            if displayedVideoIds.count >= allYouTubeVideos.count {
                displayedVideoIds.removeAll()
                // print("🔄 [CharacterDetailView] Reset displayed videos list")
            }
        }
    }
    
    private func startBannerRotationForDetail() {
        // 既存のタイマーを停止
        bannerTimer?.invalidate()
        
        // 動画が2つ以上ある場合のみローテーション
        guard allYouTubeVideos.count > 1 else {
            // print("🔄 [CharacterDetailView] Not enough videos for rotation")
            return
        }
        
        bannerTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: true) { _ in
            // print("🔄 [CharacterDetailView] Timer triggered - selecting next video")
            selectRandomYouTubeVideoForDetail()
        }
        
        print("⏰ [CharacterDetailView] Banner rotation started")
    }
}

// Helper functions
// 注: saveImageToDocuments関数はImageUtils.swiftに移動しました

extension DateFormatter {
    static let monthDayEnglish: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d"
        return formatter
    }()
    
    static let monthDayLocalized: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = NSLocalizedString("date_format_month_day", comment: "Month and day format")
        return formatter
    }()
    
}

struct AboutView: View {
    @Binding var characters: [Character]
    let characterId: UUID
    var onClose: () -> Void
    @State private var profileDescription: String = ""
    @State private var editedName: String = ""
    @State private var editedAge: String = ""
    @State private var editedFavoriteFood: String = ""
    // @State private var editedCupSize: String = "" // removed
    @State private var isEditingProfile: Bool = false
    @State private var isEditingDescription: Bool = false
    @State private var iconPickerItem: PhotosPickerItem? = nil
    @State private var newIconImage: UIImage?
    @State private var showIconAdjustment: Bool = false
    
    // Debouncing用のタイマー
    @State private var saveDebounceTimer: Timer?
    
    // シート管理用のenum
    enum ActiveSheet: Identifiable {
        case soundtrackEdit
        case iconPicker
        case editSelection
        
        var id: Int {
            switch self {
            case .soundtrackEdit: return 0
            case .iconPicker: return 1
            case .editSelection: return 2
            }
        }
    }
    @State private var activeSheet: ActiveSheet?
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var characterManager: CharacterManager

    // characters配列から該当キャラを取得
    private var characterIndex: Int? {
        characters.firstIndex(where: { $0.id == characterId })
    }
    private var character: Character? {
        characterIndex.flatMap { characters[$0] }
    }
    
    @ViewBuilder
    private var bannerView: some View {
        if let character = character {
            VStack(spacing: 0) {
                Button(action: {
                    showIconAdjustment = true
                }) {
                    if let imageIdentifier = character.imageIdentifier, let image = loadImageFromPath(imageIdentifier) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity, maxHeight: 200)
                            .scaleEffect(CGFloat(character.iconScale))
                            .offset(x: CGFloat(character.iconOffsetX), y: CGFloat(character.iconOffsetY))
                            .clipped()
                            .overlay(Color.black.opacity(0.4))
                            .overlay(bannerOverlay)
                            .id("\(character.id)_\(character.iconScale)_\(character.iconOffsetX)_\(character.iconOffsetY)") // Force refresh when scale or offset changes
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(maxWidth: .infinity, maxHeight: 200)
                            .overlay(
                                VStack(spacing: 4) {
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.gray)
                                    Text(NSLocalizedString("tap_to_add", comment: ""))
                                        .font(.system(size: 12))
                                        .foregroundColor(.gray)
                                }
                            )
                            .overlay(Color.black.opacity(0.4))
                            .overlay(bannerOverlay)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.top, 20)
            .padding(.bottom, 10)
        }
    }
    
    @ViewBuilder
    private var bannerOverlay: some View {
        VStack {
            Spacer()
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(isEditingProfile ? editedName : character?.name ?? "")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                }
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
        }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // キャラクターバナー画像
                    bannerView
                    
                    // プロフィールセクション
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text(NSLocalizedString("profile", comment: ""))
                                .font(.system(size: 20, weight: .bold))
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 16)
                        
                        // プロフィール項目
                        VStack(spacing: 0) {
                            if isEditingProfile {
                                editableProfileRow(label: NSLocalizedString("name", comment: ""), text: $editedName)
                                    .onChange(of: editedName) { debouncedSaveCharacter() }
                                Divider().padding(.leading, 20)
                                editableProfileRow(label: NSLocalizedString("age", comment: ""), text: $editedAge)
                                    .onChange(of: editedAge) { debouncedSaveCharacter() }
                                Divider().padding(.leading, 20)
                                editableProfileRow(label: NSLocalizedString("favorite_food", comment: ""), text: $editedFavoriteFood)
                                    .onChange(of: editedFavoriteFood) { debouncedSaveCharacter() }
                                Divider().padding(.leading, 20)
                                // Cup size removed
                            } else {
                                profileRow(label: NSLocalizedString("name", comment: ""), value: character?.name ?? "")
                                Divider().padding(.leading, 20)
                                profileRow(label: NSLocalizedString("age", comment: ""), value: character?.age ?? NSLocalizedString("not_set", comment: ""))
                                Divider().padding(.leading, 20)
                                profileRow(label: NSLocalizedString("favorite_food", comment: ""), value: character?.favoriteFood ?? NSLocalizedString("not_set", comment: ""))
                                Divider().padding(.leading, 20)
                                // Cup size display removed
                            }
                        }
                        .background(Color.white)
                    }
                    
                    // 概要セクション
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text(NSLocalizedString("description", comment: ""))
                                .font(.system(size: 20, weight: .bold))
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 32)
                        .padding(.bottom, 16)
                        
                        // 概要テキスト
                        if isEditingDescription {
                            ZStack(alignment: .topLeading) {
                                if profileDescription.isEmpty {
                                    Text(NSLocalizedString("enter_description", comment: ""))
                                        .font(.system(size: 16))
                                        .foregroundColor(.gray)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 16)
                                }
                                
                                TextEditor(text: $profileDescription)
                                    .font(.system(size: 16))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .frame(minHeight: 200)
                                    .onChange(of: profileDescription) { debouncedSaveCharacter() }
                                    .scrollContentBackground(.hidden)
                                    .background(Color.clear)
                                    .autocorrectionDisabled(true)
                            }
                            .background(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .padding(.horizontal, 20)
                        } else {
                            if profileDescription.isEmpty {
                                Text(NSLocalizedString("description_not_set", comment: ""))
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 16)
                            } else {
                                Text(profileDescription)
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
                            Text(NSLocalizedString("soundtrack", comment: ""))
                                .font(.system(size: 20, weight: .bold))
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 32)
                        .padding(.bottom, 16)
                        
                        // サントラリスト
                        if character?.soundtracks.isEmpty ?? true {
                            Text(NSLocalizedString("soundtrack_not_set", comment: ""))
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 16)
                        } else {
                            VStack(spacing: 12) {
                                ForEach(character?.soundtracks ?? [], id: \.id) { soundtrack in
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
            .navigationBarTitle(NSLocalizedString("about", comment: ""), displayMode: .inline)
            .navigationBarItems(
                leading: Button(action: {
                    saveCharacter()
                    onClose()
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.black)
                        .font(.system(size: 20, weight: .bold))
                },
                trailing: Button(action: {
                    if isEditingProfile || isEditingDescription {
                        // 編集モードを終了（自動保存されているので保存処理は不要）
                        isEditingProfile = false
                        isEditingDescription = false
                    } else {
                        // 編集選択モーダルを表示
                        activeSheet = .editSelection
                    }
                }) {
                    Text(isEditingProfile || isEditingDescription ? NSLocalizedString("complete", comment: "") : NSLocalizedString("edit", comment: ""))
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
            loadCharacterDescription()
            if let character = character {
                editedName = character.name
                editedAge = character.age
                editedFavoriteFood = character.favoriteFood
                // editedCupSize = character.cupSize // removed
                
            }
        }
        .onDisappear {
            // Cancel any pending save timer
            saveDebounceTimer?.invalidate()
            // Save immediately when leaving the view
            saveCharacter()
        }
        /* .sheet(isPresented: $showIconPicker) {
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
                            activeSheet = nil
                        }
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    
                    Button(NSLocalizedString("cancel", comment: "")) {
                        showIconPicker = false
                        newIconImage = nil
                        iconPickerItem = nil
                    }
                    .foregroundColor(.red)
                }
                .padding()
            }
            .onChange(of: iconPickerItem) { _, newValue in
                if let newValue = newValue {
                    Task {
                        if let data = try? await newValue.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            newIconImage = image
                        }
                    }
                }
            } */
            .sheet(item: $activeSheet) { item in
                switch item {
                case .soundtrackEdit:
                    SoundtrackEditView { soundtrack in
                        // サントラを保存
                        guard let idx = characterIndex else { return }
                        var updatedCharacter = characters[idx]
                        var soundtracks = updatedCharacter.soundtracks
                        soundtracks.append(soundtrack)
                        updatedCharacter.soundtracks = soundtracks
                        characters[idx] = updatedCharacter
                        characterManager.updateCharacter(updatedCharacter)
                        
                        // SoundtrackManagerのリストを更新
                        SoundtrackManager.shared.collectAllSoundtracks(
                            characters: characterManager.characters,
                            animes: AnimeManager().animes
                        )
                    }
                    .onAppear {
                    }
                case .iconPicker:
                    NavigationView {
                        VStack(spacing: 20) {
                            Text(NSLocalizedString("select_icon", comment: ""))
                                .font(.headline)
                            
                            if let newIconImage = newIconImage {
                                Image(uiImage: newIconImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 150, height: 150)
                                    .clipShape(Circle())
                            }
                            
                            PhotosPicker(selection: $iconPickerItem, matching: .images) {
                                Text(NSLocalizedString("select_image", comment: ""))
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            
                            if newIconImage != nil {
                                Button(NSLocalizedString("save", comment: "")) {
                                    saveNewIcon()
                                    activeSheet = nil
                                }
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            
                            Button(NSLocalizedString("cancel", comment: "")) {
                                activeSheet = nil
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
                                    // 画像を保存
                                    let fileName = "character_icon_\(Date().timeIntervalSince1970).jpg"
                                    if let savedPath = saveImageToCharacterFolderAsJPEG(image, characterId: characters[characterIndex ?? 0].id.uuidString, fileName: fileName),
                                       let idx = characterIndex {
                                        var updatedCharacter = characters[idx]
                                        // print("🔄 [CharaScreen-IconSheet] Icon will be updated from \(updatedCharacter.imageIdentifier ?? "nil") to \(savedPath)")
                                        updatedCharacter.imageIdentifier = savedPath
                                        characters[idx] = updatedCharacter
                                        characterManager.updateCharacter(updatedCharacter)
                                    }
                                }
                            }
                        }
                    }
                case .editSelection:
                    CharaEditSelectionSheet(
                        isEditingProfile: $isEditingProfile,
                        isEditingDescription: $isEditingDescription,
                        activeSheet: $activeSheet
                    )
                }
            }
            // アイコン位置調整モーダル
            .sheet(isPresented: $showIconAdjustment, onDismiss: {
                // アイコン調整後にUIを更新
                characterManager.refreshUI()
            }) {
                if let character = character {
                    CharacterIconAdjustmentView(
                        character: Binding(
                            get: { character },
                            set: { newCharacter in
                                if let idx = characterIndex {
                                    characters[idx] = newCharacter
                                    characterManager.updateCharacter(newCharacter)
                                }
                            }
                        ),
                        characterManager: characterManager
                    )
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
            
            // 月と日のみ選択できるPicker
            HStack {
                Picker("月", selection: Binding(
                    get: { Calendar.current.component(.month, from: date.wrappedValue) },
                    set: { newMonth in
                        let components = Calendar.current.dateComponents([.year, .month, .day], from: date.wrappedValue)
                        if let newDate = Calendar.current.date(from: DateComponents(year: components.year, month: newMonth, day: components.day)) {
                            date.wrappedValue = newDate
                        }
                    }
                )) {
                    ForEach(1...12, id: \.self) { month in
                        Text("\(month)月").tag(month)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                Picker("日", selection: Binding(
                    get: { Calendar.current.component(.day, from: date.wrappedValue) },
                    set: { newDay in
                        let components = Calendar.current.dateComponents([.year, .month, .day], from: date.wrappedValue)
                        if let newDate = Calendar.current.date(from: DateComponents(year: components.year, month: components.month, day: newDay)) {
                            date.wrappedValue = newDate
                        }
                    }
                )) {
                    let _ = Calendar.current.component(.month, from: date.wrappedValue)
                    let daysInMonth = Calendar.current.range(of: .day, in: .month, for: date.wrappedValue)?.count ?? 30
                    ForEach(1...daysInMonth, id: \.self) { day in
                        Text("\(day)日").tag(day)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
    
    // MARK: - Helper Methods
    private func loadCharacterDescription() {
        guard let character = character else { return }
        // カスタムフィールドから"概要"フィールドを探す
        if let customFields = character.customFields,
           let descriptionField = customFields.first(where: { $0.name == "概要" }) {
            profileDescription = descriptionField.value
        }
    }
    
    // Debounced save function
    private func debouncedSaveCharacter() {
        // Cancel previous timer
        saveDebounceTimer?.invalidate()
        
        // Start new timer with 0.5 second delay
        saveDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { _ in
            saveCharacter()
        }
    }
    
    private func saveCharacter() {
        guard let idx = characters.firstIndex(where: { $0.id == characterId }) else { return }
        
        // 編集中の場合は編集内容を保存
        var updatedCharacter = characters[idx]
        
        // プロフィール編集内容を常に保存
        updatedCharacter.name = editedName
        updatedCharacter.age = editedAge
        updatedCharacter.favoriteFood = editedFavoriteFood
        // updatedCharacter.cupSize = editedCupSize // removed
        
        // 概要をカスタムフィールドに保存
        if updatedCharacter.customFields == nil {
            updatedCharacter.customFields = []
        }
        
        // 既存の"概要"フィールドを更新または新規作成
        if let index = updatedCharacter.customFields?.firstIndex(where: { $0.name == "概要" }) {
            updatedCharacter.customFields?[index].value = profileDescription
        } else {
            updatedCharacter.customFields?.append(CustomField(name: "概要", value: profileDescription))
        }
        
        // 先にcharacterManagerを更新してから、バインディング配列を更新
        characterManager.updateCharacter(updatedCharacter)
        
        // メインスレッドで確実に更新
        DispatchQueue.main.async {
            self.characters[idx] = updatedCharacter
            // UIを強制的にリフレッシュ
            self.characterManager.refreshUI()
        }
    }
    
    // アイコン保存機能
    private func saveNewIcon() {
        guard let iconImage = newIconImage,
              let idx = characters.firstIndex(where: { $0.id == characterId }) else { return }
        
        // 画像をDocumentsディレクトリに保存
        let fileName = "character_icon_\(UUID().uuidString).png"
        if let savedPath = saveImageToCharacterFolder(iconImage, characterId: characters[idx].id.uuidString, fileName: fileName) {
            var updatedCharacter = characters[idx]
            
            // 古いアイコンの削除はupdateCharacterに任せる
            // （ここで削除すると、updateCharacter内の処理が動かない）
            
            // 新しいアイコンパスを設定
            updatedCharacter.imageIdentifier = savedPath
            
            // print("🔄 [CharaScreen] Updating character icon from \(characters[idx].imageIdentifier ?? "nil") to \(savedPath)")
            
            characters[idx] = updatedCharacter
            characterManager.updateCharacter(updatedCharacter)
        }
        
        newIconImage = nil
        iconPickerItem = nil
    }
    
    // 注: saveImageToDocuments関数はImageUtils.swiftのものを使用します
    
    private func deleteSoundtrack(_ soundtrack: Soundtrack) {
        guard let idx = characterIndex else { return }
        var updatedCharacter = characters[idx]
        var soundtracks = updatedCharacter.soundtracks
        soundtracks.removeAll { $0.id == soundtrack.id }
        updatedCharacter.soundtracks = soundtracks
        characters[idx] = updatedCharacter
        characterManager.updateCharacter(updatedCharacter)
        
        // Delete the actual soundtrack files from disk
        SoundtrackStorage.shared.deleteSoundtrack(id: soundtrack.id.uuidString)
    }
}

// --- 追加: 高さ自動調整＆空行削除付きTextEditor ---
struct AutoSizingTextEditor: UIViewRepresentable {
    @Binding var text: String
    var minHeight: CGFloat = 36
    var font: UIFont = .systemFont(ofSize: 17)
    var onEndEditing: (() -> Void)? = nil

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isScrollEnabled = false
        textView.font = font
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        return textView
    }
    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        // 行数分だけ高さを強制（空行は含めない）
        let lines = text.components(separatedBy: "\n").filter { !$0.isEmpty }
        let lineCount = max(1, lines.count)
        let lineHeight = font.lineHeight
        let padding: CGFloat = 16 // 上下8ずつ
        let totalHeight = CGFloat(lineCount) * lineHeight + padding
        if uiView.constraints.first(where: { $0.identifier == "height" }) == nil {
            let heightConstraint = uiView.heightAnchor.constraint(equalToConstant: minHeight)
            heightConstraint.identifier = "height"
            heightConstraint.isActive = true
        }
        uiView.constraints.first(where: { $0.identifier == "height" })?.constant = max(minHeight, totalHeight)
        uiView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
    }
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: AutoSizingTextEditor
        init(_ parent: AutoSizingTextEditor) { self.parent = parent }
        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text ?? ""
        }
        func textViewDidEndEditing(_ textView: UITextView) {
            // 空行を削除
            let lines = (textView.text ?? "").components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            parent.text = lines.joined(separator: "\n")
            parent.onEndEditing?()
        }
    }
}
// --- ここまで追加 ---


// キャラクターランキング行ビュー
struct CharacterRankingRow: View {
    let ranking: CharacterRanking
    
    var body: some View {
        HStack(spacing: 12) {
            // 順位表示
            ZStack {
                Circle()
                    .fill(rankColor)
                    .frame(width: 24, height: 24)
                Text("\(ranking.rank)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // キャラクターアイコン
            if let imagePath = ranking.characterImagePath,
               let image = loadImageFromPath(imagePath) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                    )
            }
            
            // キャラクター名
            VStack(alignment: .leading, spacing: 2) {
                Text(ranking.characterName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.black)
                    .lineLimit(1)
                Text(String(format: NSLocalizedString("rank_format", comment: ""), ranking.rank))
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
            
            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(.systemGray6))
        .cornerRadius(8)
    }
    
    private var rankColor: Color {
        switch ranking.rank {
        case 1:
            return Color.yellow
        case 2:
            return Color.gray
        case 3:
            return Color.orange
        default:
            return Color.blue
        }
    }
}

// キャラクター広告行ビュー
struct CharacterAdRow: View {
    let ad: Advertisement
    // Firebase removed
    
    var body: some View {
        Button(action: {
            if let url = URL(string: ad.linkURL) {
                // Firebase ad tracking removed
                UIApplication.shared.open(url)
            }
        }) {
            HStack(spacing: 12) {
                // 広告アイコン
                AsyncImage(url: URL(string: ad.imageURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "megaphone.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.gray)
                        )
                }
                
                // 広告テキスト
                VStack(alignment: .leading, spacing: 2) {
                    Text(ad.title)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.black)
                        .lineLimit(1)
                    Text(ad.description)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .lineLimit(2)
                }
                
                Spacer()
                
                // 広告マーク
                Text("AD")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue)
                    .cornerRadius(4)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
        .onAppear {
            // Firebase ad tracking removed
        }
    }
}

// キャラクターランキング管理画面
struct CharacterRankingAdminView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var rankingManager = CharacterRankingManager()
    @StateObject private var characterManager = CharacterManager()
    @State private var selectedRank: Int = 1
    @State private var selectedCharacter: Character? = nil
    @State private var showingCharacterPicker = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // タイトル
                HStack {
                    Text(NSLocalizedString("character_ranking_management", comment: ""))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.black)
                    Spacer()
                    Button(NSLocalizedString("close", comment: "")) {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 20)
                
                // ランキング設定リスト
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(1...7, id: \.self) { rank in
                            RankingSettingRow(
                                rank: rank,
                                currentRanking: rankingManager.getRanking(for: rank),
                                onTap: {
                                    selectedRank = rank
                                    showingCharacterPicker = true
                                },
                                onRemove: {
                                    rankingManager.removeRanking(rank: rank)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
                
                Spacer()
            }
            .background(Color(.systemGray6))
        }
        .sheet(isPresented: $showingCharacterPicker) {
            CharacterPickerView(
                characters: characterManager.characters,
                selectedRank: selectedRank,
                onSelect: { character in
                    rankingManager.updateRanking(
                        characterId: character.id,
                        rank: selectedRank,
                        characterName: character.name,
                        characterImagePath: character.imageIdentifier
                    )
                    showingCharacterPicker = false
                }
            )
        }
    }
}

// ランキング設定行ビュー
struct RankingSettingRow: View {
    let rank: Int
    let currentRanking: CharacterRanking?
    let onTap: () -> Void
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // 順位表示
            ZStack {
                Circle()
                    .fill(rankColor)
                    .frame(width: 32, height: 32)
                Text("\(rank)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
            }
            
            // キャラクター情報
            if let ranking = currentRanking {
                HStack(spacing: 12) {
                    // キャラクターアイコン
                    if let imagePath = ranking.characterImagePath,
                       let image = loadImageFromPath(imagePath) {
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
                                Image(systemName: "person.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.gray)
                            )
                    }
                    
                    // キャラクター名
                    Text(ranking.characterName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.black)
                    
                    Spacer()
                    
                    // 削除ボタン
                    Button(action: onRemove) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.red)
                    }
                }
            } else {
                Text(NSLocalizedString("select_character_message", comment: ""))
                    .font(.system(size: 16))
                    .foregroundColor(.gray)
                Spacer()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.2), radius: 2, x: 0, y: 1)
        .onTapGesture {
            onTap()
        }
    }
    
    private var rankColor: Color {
        switch rank {
        case 1:
            return Color.yellow
        case 2:
            return Color.gray
        case 3:
            return Color.orange
        default:
            return Color.blue
        }
    }
}

// キャラクター選択ビュー
struct CharacterPickerView: View {
    @Environment(\.dismiss) var dismiss
    let characters: [Character]
    let selectedRank: Int
    let onSelect: (Character) -> Void
    @State private var searchText = ""
    
    var filteredCharacters: [Character] {
        let result: [Character]
        if searchText.isEmpty {
            result = characters.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        } else {
            result = characters.filter {
                !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        // Sort by order
        return result.sorted(by: { $0.order < $1.order })
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // タイトル
                HStack {
                    Text(String(format: NSLocalizedString("select_rank_character", comment: ""), selectedRank))
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)
                    Spacer()
                    Button(NSLocalizedString("cancel", comment: "")) {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 10)
                
                // 検索バー
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField(NSLocalizedString("search_character", comment: ""), text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
                .padding(.horizontal, 16)
                .padding(.bottom, 10)
                
                // キャラクターリスト
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredCharacters) { character in
                            CharacterPickerRow(
                                character: character,
                                onSelect: {
                                    onSelect(character)
                                }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                }
                
                Spacer()
            }
            .background(Color(.systemGray6))
        }
    }
}

// キャラクター選択行ビュー
struct CharacterPickerRow: View {
    let character: Character
    let onSelect: () -> Void
    
    var body: some View {
        HStack(spacing: 12) {
            // キャラクターアイコン
            if let imageIdentifier = character.imageIdentifier,
               let image = loadImageFromPath(imageIdentifier) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 25))
                            .foregroundColor(.gray)
                    )
            }
            
            // キャラクター情報
            VStack(alignment: .leading, spacing: 4) {
                Text(character.name)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.black)
            }
            
            Spacer()
            
            // 選択ボタン
            Button(NSLocalizedString("select", comment: "")) {
                onSelect()
            }
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.blue)
            .cornerRadius(6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color.white)
        .cornerRadius(12)
        .shadow(color: .gray.opacity(0.2), radius: 2, x: 0, y: 1)
    }
}

struct NavigationBarItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let onTap: () -> Void
    @State private var isPressed: Bool = false
    
    var body: some View {
        VStack(spacing: 4) {
            if icon == "visit_event_icon" {
                Image(icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22)
                    .foregroundColor(isSelected ? .blue : .gray)
            } else {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(isSelected ? .blue : .gray)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 75)
        .background(isPressed ? Color.gray.opacity(0.2) : Color.clear)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: isPressed)
        .contentShape(Rectangle())
        .onTapGesture {
            // 即座にタップアクションを実行
            onTap()
            
            // シンプルなフィードバック
            isPressed = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isPressed = false
            }
        }
    }
}

struct EditBackgroundView: View {
    @Binding var character: Character
    @ObservedObject var characterManager: CharacterManager
    @State private var backgroundPickerItem: PhotosPickerItem? = nil
    @State private var backgroundImage: UIImage? = nil
    @Environment(\.dismiss) var dismiss
    
    // 最新のキャラクター情報を取得
    private var currentCharacter: Character {
        characterManager.characters.first(where: { $0.id == character.id }) ?? character
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text(NSLocalizedString("select_background_image", comment: ""))
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
                        } else if let imagePath = currentCharacter.backgroundImagePath,
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
                                        Text(NSLocalizedString("select_background_image", comment: ""))
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
                                await MainActor.run {
                                    backgroundImage = uiImage
                                    
                                    // 即座に背景を更新
                                    let fileName = "character_bg_\(UUID().uuidString).png"
                                    if let imagePath = saveImageToCharacterFolder(uiImage, characterId: character.id.uuidString, fileName: fileName) {
                                        // 古い画像を削除
                                        if let oldPath = character.backgroundImagePath {
                                            try? FileManager.default.removeItem(atPath: oldPath)
                                        }
                                        
                                        // 新しいCharacterオブジェクトを作成して更新
                                        var updatedCharacter = character
                                        updatedCharacter.backgroundImagePath = imagePath
                                        
                                        // CharacterManagerを通じて更新
                                        characterManager.updateCharacter(updatedCharacter)
                                        
                                        // Bindingも更新
                                        character = updatedCharacter
                                        
                                        // モーダルを自動的に閉じる
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                            dismiss()
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                Text(NSLocalizedString("image_auto_change_notice", comment: ""))
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.top, 10)
                
                Spacer()
            }
            .padding()
            .navigationBarTitle(NSLocalizedString("change_background_image", comment: ""), displayMode: .inline)
            .navigationBarItems(
                trailing: Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.gray)
                }
            )
        }
        .onDisappear {
            // モーダルが閉じたときに状態をリセット
            backgroundImage = nil
            backgroundPickerItem = nil
        }
    }
}

// アニメーション付きグラデーションビュー
struct AnimatedGradientView: View {
    @State private var animateGradient = false
    
    var body: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.6, green: 0.4, blue: 0.9),
                Color(red: 0.8, green: 0.5, blue: 0.9),
                Color(red: 0.6, green: 0.4, blue: 0.9)
            ]),
            startPoint: animateGradient ? .topLeading : .bottomTrailing,
            endPoint: animateGradient ? .bottomTrailing : .topLeading
        )
        .onAppear {
            withAnimation(
                Animation.easeInOut(duration: 3.0)
                    .repeatForever(autoreverses: true)
            ) {
                animateGradient.toggle()
            }
        }
    }
}

#Preview {
    CharaScreen()
}

// キャラクター編集選択シート（アニメページと同じスタイル）
struct CharaEditSelectionSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var isEditingProfile: Bool
    @Binding var isEditingDescription: Bool
    @Binding var activeSheet: AboutView.ActiveSheet?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                VStack(spacing: 15) {
                    Button(action: {
                        isEditingProfile = true
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "person.crop.circle")
                                .foregroundColor(.blue)
                            Text(NSLocalizedString("edit_profile", comment: ""))
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    }
                    
                    Button(action: {
                        isEditingDescription = true
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "text.alignleft")
                                .foregroundColor(.blue)
                            Text(NSLocalizedString("edit_description", comment: ""))
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    }
                    
                    Button(action: {
                        dismiss()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            activeSheet = .soundtrackEdit
                        }
                    }) {
                        HStack {
                            Image(systemName: "music.note")
                                .foregroundColor(.blue)
                            Text(NSLocalizedString("add_soundtrack", comment: ""))
                                .foregroundColor(.primary)
                            Spacer()
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(10)
                    }
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle(NSLocalizedString("select_edit_item_title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("cancel", comment: "")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// タイトル、タグ、背景編集ビュー
struct EditTitleTagBackgroundView: View {
    @Binding var character: Character
    @ObservedObject var characterManager: CharacterManager
    @Environment(\.dismiss) var dismiss
    @State private var editedName: String = ""
    @State private var backgroundPickerItem: PhotosPickerItem? = nil
    @State private var tempBackgroundImage: UIImage? = nil
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // タイトル編集
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("name", comment: ""))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                    TextField(NSLocalizedString("character_name", comment: ""), text: $editedName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocorrectionDisabled(true)
                        .textInputAutocapitalization(.never)
                }
                .padding(.horizontal)
                
                // 背景画像編集
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("background_image", comment: ""))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                        .padding(.horizontal)
                    
                    PhotosPicker(selection: $backgroundPickerItem, matching: .images) {
                        ZStack {
                            if let tempBackgroundImage = tempBackgroundImage {
                                Image(uiImage: tempBackgroundImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 150)
                                    .clipped()
                                    .cornerRadius(10)
                            } else if let backgroundPath = character.backgroundImagePath,
                                      let backgroundImage = loadImageFromPath(backgroundPath) {
                                Image(uiImage: backgroundImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 150)
                                    .clipped()
                                    .cornerRadius(10)
                            } else {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.gray.opacity(0.2))
                                    .frame(height: 150)
                                    .overlay(
                                        VStack(spacing: 8) {
                                            Image(systemName: "photo")
                                                .font(.system(size: 40))
                                                .foregroundColor(.gray)
                                            Text(NSLocalizedString("tap_to_select_background", comment: ""))
                                                .font(.system(size: 14))
                                                .foregroundColor(.gray)
                                        }
                                    )
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // 背景削除ボタン
                    if character.backgroundImagePath != nil || tempBackgroundImage != nil {
                        Button(action: {
                            showDeleteConfirmation = true
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                    .foregroundColor(.red)
                                Text(NSLocalizedString("delete_background", comment: ""))
                                    .foregroundColor(.red)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.top)
            .navigationTitle(NSLocalizedString("edit", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("cancel", comment: "")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveChanges()
                    }
                    .fontWeight(.bold)
                }
            }
            .onAppear {
                editedName = character.name
            }
            .onChange(of: backgroundPickerItem) { _, newValue in
                if let newItem = newValue {
                    Task {
                        if let data = try? await newItem.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            tempBackgroundImage = uiImage
                        }
                    }
                }
            }
            .alert(NSLocalizedString("delete_background_confirm", comment: ""), isPresented: $showDeleteConfirmation) {
                Button(NSLocalizedString("delete", comment: ""), role: .destructive) {
                    deleteBackground()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text(NSLocalizedString("delete_background_message", comment: ""))
            }
        }
    }
    
    private func saveChanges() {
        var updatedCharacter = character
        updatedCharacter.name = editedName
        
        // 背景画像の保存
        if let tempBackgroundImage = tempBackgroundImage {
            let fileName = "character_background_\(UUID().uuidString).png"
            let imagePath = saveImageToCharacterFolder(tempBackgroundImage, characterId: character.id.uuidString, fileName: fileName)
            
            // 古い背景画像を削除
            if let oldPath = character.backgroundImagePath {
                try? FileManager.default.removeItem(atPath: oldPath)
            }
            
            updatedCharacter.backgroundImagePath = imagePath
        }
        
        // 更新を反映
        character = updatedCharacter
        characterManager.updateCharacter(updatedCharacter)
        characterManager.refreshUI()
        
        dismiss()
    }
    
    private func deleteBackground() {
        var updatedCharacter = character
        
        // 背景画像ファイルを削除
        if let backgroundPath = character.backgroundImagePath {
            try? FileManager.default.removeItem(atPath: backgroundPath)
        }
        
        updatedCharacter.backgroundImagePath = nil
        tempBackgroundImage = nil
        
        // 更新を反映
        character = updatedCharacter
        characterManager.updateCharacter(updatedCharacter)
        characterManager.refreshUI()
    }
    
    // MARK: - YouTube Thumbnail Helper
    private func getYouTubeThumbnailURLForBanner(from youtubeURL: String) -> String {
        print("🎥 [DEBUG] YouTube URL input: \(youtubeURL)")
        
        // YouTube URLからvideo IDを抽出
        let videoId = extractVideoId(from: youtubeURL)
        print("🎥 [DEBUG] Extracted video ID: \(videoId)")
        
        if videoId.isEmpty {
            // print("❌ [ERROR] Failed to extract video ID from URL: \(youtubeURL)")
            return ""
        }
        
        // 高解像度サムネイルURLを生成（複数の候補を試す）
        let thumbnailUrls = [
            "https://img.youtube.com/vi/\(videoId)/maxresdefault.jpg",  // 最高解像度
            "https://img.youtube.com/vi/\(videoId)/hqdefault.jpg",     // 高解像度
            "https://img.youtube.com/vi/\(videoId)/mqdefault.jpg",     // 中解像度
            "https://img.youtube.com/vi/\(videoId)/default.jpg"        // デフォルト解像度
        ]
        
        let selectedUrl = thumbnailUrls[0] // まずは最高解像度を試す
        print("🎥 [DEBUG] Generated thumbnail URL: \(selectedUrl)")
        
        return selectedUrl
    }
    
    private func extractVideoId(from url: String) -> String {
        // print("🔍 [DEBUG] Extracting video ID from: \(url)")
        
        // 各種YouTube URLフォーマットに対応
        let patterns = [
            "(?:youtube\\.com/watch\\?v=|youtu\\.be/|youtube\\.com/embed/)([a-zA-Z0-9_-]{11})",
            "(?:youtube\\.com/watch\\?.*&v=)([a-zA-Z0-9_-]{11})",
            "(?:youtube\\.com/v/)([a-zA-Z0-9_-]{11})"
        ]
        
        for pattern in patterns {
            do {
                let regex = try NSRegularExpression(pattern: pattern, options: .caseInsensitive)
                let range = NSRange(location: 0, length: url.utf16.count)
                
                if let match = regex.firstMatch(in: url, options: [], range: range) {
                    let videoIdRange = match.range(at: 1)
                    if let swiftRange = Range(videoIdRange, in: url) {
                        let videoId = String(url[swiftRange])
                        // print("✅ [DEBUG] Successfully extracted video ID: \(videoId)")
                        return videoId
                    }
                }
            } catch {
                // print("❌ [ERROR] Regex error for pattern \(pattern): \(error)")
            }
        }
        
        // print("❌ [ERROR] No video ID found in URL: \(url)")
        return ""
    }
}


// アイコン位置調整ビュー（キャラクター用）
struct CharacterIconAdjustmentView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var character: Character
    @ObservedObject var characterManager: CharacterManager
    @State private var iconPickerItem: PhotosPickerItem? = nil
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // プレビュー
                ZStack {
                    if let imageIdentifier = character.imageIdentifier, let image = loadImageFromPath(imageIdentifier) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: UIScreen.main.bounds.width, height: 200)
                            .scaleEffect(CGFloat(character.iconScale))
                            .offset(x: CGFloat(character.iconOffsetX), y: CGFloat(character.iconOffsetY))
                            .frame(maxWidth: .infinity, maxHeight: 200)
                            .clipped()
                            .background(Color.gray.opacity(0.2))
                    } else {
                        PhotosPicker(selection: $iconPickerItem, matching: .images) {
                            Rectangle()
                                .fill(Color.gray.opacity(0.3))
                                .frame(width: UIScreen.main.bounds.width, height: 200)
                                .overlay(
                                    VStack(spacing: 4) {
                                        Image(systemName: "photo.badge.plus")
                                            .font(.system(size: 40))
                                            .foregroundColor(.gray)
                                        Text(NSLocalizedString("tap_to_add", comment: ""))
                                            .font(.system(size: 12))
                                            .foregroundColor(.gray)
                                    }
                                )
                        }
                    }
                }
                .frame(height: 200)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(10)
                .padding(.horizontal)
                
                // 画像変更ボタン（画像が存在する場合）
                if character.imageIdentifier != nil {
                    PhotosPicker(selection: $iconPickerItem, matching: .images) {
                        HStack {
                            Image(systemName: "photo")
                            Text(NSLocalizedString("change_image", comment: "Change Image"))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(8)
                    }
                }
                
                // 調整スライダー
                VStack(spacing: 15) {
                    // 大きさ
                    VStack(alignment: .leading) {
                        Text(NSLocalizedString("icon_scale", comment: "Size"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Slider(value: $character.iconScale, in: 0.5...2.0)
                    }
                    
                    // 横位置
                    VStack(alignment: .leading) {
                        Text(NSLocalizedString("icon_horizontal_position", comment: "Horizontal Position"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Slider(value: $character.iconOffsetX, in: -200...200)
                    }
                    
                    // 縦位置
                    VStack(alignment: .leading) {
                        Text(NSLocalizedString("icon_vertical_position", comment: "Vertical Position"))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Slider(value: $character.iconOffsetY, in: -200...200)
                    }
                }
                .padding(.horizontal)
                
                // リセットボタン
                Button(action: {
                    character.iconScale = 1.0
                    character.iconOffsetX = 0.0
                    character.iconOffsetY = 0.0
                }) {
                    Text(NSLocalizedString("reset", comment: "Reset"))
                        .padding(.horizontal, 30)
                        .padding(.vertical, 10)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(8)
                }
                
                Spacer()
            }
            .navigationTitle(NSLocalizedString("adjust_icon_position", comment: "Adjust icon position"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("cancel", comment: "Cancel")) {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("done", comment: "Done")) {
                        // 変更を保存
                        characterManager.updateCharacter(character)
                        characterManager.refreshUI()
                        dismiss()
                    }
                }
            }
            .onChange(of: iconPickerItem) { _, newValue in
                if let newValue = newValue {
                    Task {
                        if let data = try? await newValue.loadTransferable(type: Data.self),
                           let uiImage = UIImage(data: data) {
                            let fileName = "character_icon_\(Date().timeIntervalSince1970).jpg"
                            if let savedPath = saveImageToCharacterFolderAsJPEG(uiImage, characterId: character.id.uuidString, fileName: fileName) {
                                // 古い画像ファイルの削除はupdateCharacterに任せる
                                // print("🔄 [CharaScreen-EditIcon] Icon will be updated from \(character.imageIdentifier ?? "nil") to \(savedPath)")
                                
                                // キャラクターを更新
                                character.imageIdentifier = savedPath
                                characterManager.updateCharacter(character)
                            }
                        }
                    }
                }
            }
        }
    }
}

// キャラクター用の音楽再生ボタンビュー
struct PlayMusicButtonViewForCharacter: View {
    let character: Character
    @ObservedObject private var soundtrackManager = SoundtrackManager.shared
    @State private var showSoundtrackAlert = false
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                if !soundtrackManager.isPlayerVisible {
                    Button(action: {
                        if character.soundtracks.isEmpty {
                            // サントラがない場合はアラートを表示
                            showSoundtrackAlert = true
                        } else {
                            // サントラがある場合は再生
                            soundtrackManager.collectAllSoundtracks(
                                characters: [character],
                                animes: []
                            )
                            soundtrackManager.startRandomPlayback()
                        }
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "music.note")
                                .font(.system(size: 16))
                            Text(NSLocalizedString("play_music", comment: "音楽を再生"))
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.purple)
                        .cornerRadius(20)
                        .shadow(color: Color.black.opacity(0.2), radius: 5, x: 0, y: 2)
                    }
                    .padding(.trailing, 20)
                    .padding(.bottom, 50)
                    .alert(NSLocalizedString("no_soundtrack_title", comment: "サントラが登録されていません"), isPresented: $showSoundtrackAlert) {
                        Button(NSLocalizedString("ok", comment: "OK")) {
                            showSoundtrackAlert = false
                        }
                    } message: {
                        Text(NSLocalizedString("add_soundtrack_from_about", comment: "アバウトページからサントラを追加してください"))
                    }
                }
            }
        }
    }
}
