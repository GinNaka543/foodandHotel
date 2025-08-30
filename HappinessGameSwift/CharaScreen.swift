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
        // Ranking admin view removed
        //.sheet(isPresented: $showRankingAdmin) {
        //    CharacterRankingAdminView()
        //}
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
                    LinearGradient(
                        gradient: Gradient(colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
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
    @State private var showList = false
    @State private var showEditBackgroundModal = false
    @State private var showEditIconModal = false // ← 追加
    @State private var showEditNameModal = false
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
            Button(action: { showList = true }) {
                VStack(spacing: 4) {
                    Image(systemName: "list.bullet")
                        .foregroundColor(.white)
                        .font(.system(size: 24))
                    Text("リスト").font(.caption2).foregroundColor(.white)
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
                            showEditNameModal = true
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
                // EditBackgroundView removed - functionality not needed
                EmptyView()
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
            .fullScreenCover(isPresented: $showList, onDismiss: {
                // リストページから戻った時に最新のデータを反映
                characterManager.loadCharacters()
                
                // 最新のキャラクター情報を取得して更新
                if let updatedCharacter = characterManager.characters.first(where: { $0.id == character.id }) {
                    character = updatedCharacter
                    
                    // UIを強制的に更新
                    DispatchQueue.main.async {
                        characterManager.objectWillChange.send()
                        refreshID = UUID()
                    }
                }
            }) {
                RestaurantListView(characters: $characters, characterId: character.id, onClose: { 
                    showList = false
                })
                    .environmentObject(characterManager)
            }
            // Name edit modal
            .sheet(isPresented: $showEditNameModal) {
                EditCharacterNameView(
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

// Restaurant item model
struct RestaurantItem: Identifiable, Codable {
    let id = UUID()
    var name: String
    var imagePath: String?
    var memo: String = ""
    var createdAt = Date()
}

struct RestaurantListView: View {
    @Binding var characters: [Character]
    let characterId: UUID
    var onClose: () -> Void
    @State private var restaurants: [RestaurantItem] = []
    @State private var showAddRestaurant = false
    @State private var newRestaurantName = ""
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var selectedImage: UIImage? = nil
    @State private var editingRestaurant: RestaurantItem? = nil
    @State private var selectedRestaurantForDetail: RestaurantItem? = nil
    
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
                    // Do nothing for now - icon adjustment removed
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
                    Text(character?.name ?? "")
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
            VStack(spacing: 0) {
                // レストランリスト
                if restaurants.isEmpty {
                    VStack(spacing: 20) {
                        Spacer()
                        Image(systemName: "fork.knife.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.gray)
                        Text("登録されていません")
                            .font(.title3)
                            .foregroundColor(.gray)
                        Text("右上の追加ボタンからお店や商品を登録してください")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        Spacer()
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                            ForEach(restaurants) { restaurant in
                                VStack(spacing: 8) {
                                    if let imagePath = restaurant.imagePath,
                                       let image = loadImageFromPath(imagePath) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: (UIScreen.main.bounds.width - 48) / 2, height: 150)
                                            .clipped()
                                            .cornerRadius(12)
                                    } else {
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: (UIScreen.main.bounds.width - 48) / 2, height: 150)
                                            .overlay(
                                                Image(systemName: "photo")
                                                    .font(.system(size: 40))
                                                    .foregroundColor(.gray)
                                            )
                                    }
                                    
                                    Text(restaurant.name)
                                        .font(.system(size: 14, weight: .medium))
                                        .lineLimit(2)
                                        .multilineTextAlignment(.center)
                                        .padding(.horizontal, 4)
                                }
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedRestaurantForDetail = restaurant
                                }
                                .contextMenu {
                                    Button(action: {
                                        editingRestaurant = restaurant
                                        newRestaurantName = restaurant.name
                                        if let imagePath = restaurant.imagePath,
                                           let image = loadImageFromPath(imagePath) {
                                            selectedImage = image
                                        }
                                        showAddRestaurant = true
                                    }) {
                                        Label("編集", systemImage: "pencil")
                                    }
                                    
                                    Button(role: .destructive, action: {
                                        deleteRestaurant(restaurant)
                                    }) {
                                        Label("削除", systemImage: "trash")
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationBarTitle("リスト", displayMode: .inline)
            .navigationBarItems(
                leading: Button(action: {
                    saveRestaurants()
                    onClose()
                }) {
                    Image(systemName: "chevron.left")
                        .foregroundColor(.black)
                        .font(.system(size: 20, weight: .bold))
                },
                trailing: Button(action: {
                    editingRestaurant = nil
                    newRestaurantName = ""
                    selectedImage = nil
                    selectedPhotoItem = nil
                    showAddRestaurant = true
                }) {
                    Text("追加")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color.black)
                        .cornerRadius(8)
                }
            )
            .sheet(isPresented: $showAddRestaurant) {
                NavigationView {
                    VStack(spacing: 20) {
                        // 写真選択
                        PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                            if let selectedImage = selectedImage {
                                Image(uiImage: selectedImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 200, height: 200)
                                    .clipped()
                                    .cornerRadius(12)
                            } else {
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 200, height: 200)
                                    .overlay(
                                        VStack(spacing: 8) {
                                            Image(systemName: "camera.fill")
                                                .font(.system(size: 40))
                                            Text("写真を選択")
                                                .font(.caption)
                                        }
                                        .foregroundColor(.gray)
                                    )
                            }
                        }
                        .onChange(of: selectedPhotoItem) { _, newItem in
                            Task {
                                if let data = try? await newItem?.loadTransferable(type: Data.self),
                                   let image = UIImage(data: data) {
                                    selectedImage = image
                                }
                            }
                        }
                        
                        // 店名入力
                        TextField("例: 東京ラーメン", text: $newRestaurantName)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal)
                        
                        Spacer()
                    }
                    .padding(.top, 20)
                    .navigationBarTitle(editingRestaurant != nil ? "お店を編集" : "お店を追加", displayMode: .inline)
                    .navigationBarItems(
                        leading: Button("キャンセル") {
                            showAddRestaurant = false
                            editingRestaurant = nil
                            newRestaurantName = ""
                            selectedImage = nil
                            selectedPhotoItem = nil
                        },
                        trailing: Button("保存") {
                            saveRestaurant()
                        }
                        .disabled(newRestaurantName.isEmpty)
                    )
                }
            }
            .sheet(item: $selectedRestaurantForDetail) { restaurant in
                RestaurantDetailView(
                    restaurant: restaurant,
                    restaurants: $restaurants,
                    saveRestaurants: saveRestaurants
                )
            }
        }
        .onAppear {
            loadRestaurants()
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
    }
    
    // MARK: - Helper Functions
    
    private func loadRestaurants() {
        if let data = UserDefaults.standard.data(forKey: "restaurants_\(characterId.uuidString)"),
           let decoded = try? JSONDecoder().decode([RestaurantItem].self, from: data) {
            restaurants = decoded
        }
    }
    
    private func saveRestaurants() {
        if let encoded = try? JSONEncoder().encode(restaurants) {
            UserDefaults.standard.set(encoded, forKey: "restaurants_\(characterId.uuidString)")
        }
    }
    
    private func saveRestaurant() {
        if let editingRestaurant = editingRestaurant {
            // 編集モード
            if let index = restaurants.firstIndex(where: { $0.id == editingRestaurant.id }) {
                restaurants[index].name = newRestaurantName
                
                // 画像を保存
                if let image = selectedImage {
                    let fileName = "restaurant_\(UUID().uuidString).png"
                    if let imagePath = saveImageToCharacterFolder(image, characterId: characterId.uuidString, fileName: fileName) {
                        // 古い画像を削除
                        if let oldPath = restaurants[index].imagePath {
                            try? FileManager.default.removeItem(atPath: oldPath)
                        }
                        restaurants[index].imagePath = imagePath
                    }
                }
            }
        } else {
            // 新規追加
            var newRestaurant = RestaurantItem(name: newRestaurantName)
            
            // 画像を保存
            if let image = selectedImage {
                let fileName = "restaurant_\(UUID().uuidString).png"
                if let imagePath = saveImageToCharacterFolder(image, characterId: characterId.uuidString, fileName: fileName) {
                    newRestaurant.imagePath = imagePath
                }
            }
            
            restaurants.append(newRestaurant)
        }
        
        saveRestaurants()
        showAddRestaurant = false
        editingRestaurant = nil
        newRestaurantName = ""
        selectedImage = nil
        selectedPhotoItem = nil
    }
    
    private func deleteRestaurant(_ restaurant: RestaurantItem) {
        // 画像を削除
        if let imagePath = restaurant.imagePath {
            try? FileManager.default.removeItem(atPath: imagePath)
        }
        
        restaurants.removeAll { $0.id == restaurant.id }
        saveRestaurants()
    }
}

// Old AboutView code has been removed
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

// Restaurant Detail View
struct RestaurantDetailView: View {
    let restaurant: RestaurantItem
    @Binding var restaurants: [RestaurantItem]
    let saveRestaurants: () -> Void
    
    @State private var tempName: String = ""
    @State private var tempMemo: String = ""
    @State private var isEditingName: Bool = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 写真表示
                if let imagePath = restaurant.imagePath,
                   let image = loadImageFromPath(imagePath) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxHeight: 300)
                        .clipped()
                        .cornerRadius(12)
                        .padding(.horizontal)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 300)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.system(size: 60))
                                .foregroundColor(.gray)
                        )
                        .padding(.horizontal)
                }
                
                // 店名
                if isEditingName {
                    TextField("店名", text: $tempName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding(.horizontal)
                        .onSubmit {
                            isEditingName = false
                        }
                } else {
                    HStack {
                        Text(tempName)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        Image(systemName: "pencil")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                    }
                    .padding(.horizontal)
                    .onTapGesture {
                        isEditingName = true
                    }
                }
                
                // メモ欄
                VStack(alignment: .leading, spacing: 8) {
                    Text("メモ")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    TextEditor(text: $tempMemo)
                        .padding(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .frame(minHeight: 120)
                        .padding(.horizontal)
                }
                
                Spacer()
            }
            .padding(.top)
            .navigationBarTitle("詳細", displayMode: .inline)
            .navigationBarItems(
                leading: Button("キャンセル") {
                    dismiss()
                },
                trailing: Button("保存") {
                    if let index = restaurants.firstIndex(where: { $0.id == restaurant.id }) {
                        if !tempName.isEmpty && tempName != restaurant.name {
                            restaurants[index].name = tempName
                        }
                        restaurants[index].memo = tempMemo
                        saveRestaurants()
                        dismiss()
                    }
                }
            )
        }
        .onAppear {
            tempName = restaurant.name
            tempMemo = restaurant.memo
        }
    }
    
    private func loadImageFromPath(_ path: String) -> UIImage? {
        return UIImage(contentsOfFile: path)
    }
}

// Character Name Edit Modal
struct EditCharacterNameView: View {
    @Environment(\.dismiss) var dismiss
    @Binding var character: Character
    @ObservedObject var characterManager: CharacterManager
    @State private var tempName: String = ""
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Spacer()
                
                // Character Icon
                if let imageIdentifier = character.imageIdentifier, 
                   let image = loadImageFromPath(imageIdentifier) {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .shadow(radius: 5)
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 100, height: 100)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                        )
                }
                
                // Name input field
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("character_name", comment: "Character Name"))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    TextField(NSLocalizedString("character_name", comment: "Character Name"), text: $tempName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.title2)
                        .multilineTextAlignment(.center)
                        .focused($isTextFieldFocused)
                        .onSubmit {
                            saveAndDismiss()
                        }
                }
                .padding(.horizontal, 40)
                
                Spacer()
                
                // Save button
                Button(action: {
                    saveAndDismiss()
                }) {
                    Text(NSLocalizedString("save", comment: "Save"))
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    tempName.isEmpty ? Color.gray : Color(red: 0.6, green: 0.4, blue: 0.9),
                                    tempName.isEmpty ? Color.gray : Color(red: 0.8, green: 0.5, blue: 0.9)
                                ]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                }
                .disabled(tempName.isEmpty)
                .padding(.horizontal, 40)
                .padding(.bottom, 20)
            }
            .navigationBarTitle(NSLocalizedString("edit_name", comment: "Edit Name"), displayMode: .inline)
            .navigationBarItems(
                leading: Button(NSLocalizedString("cancel", comment: "Cancel")) {
                    dismiss()
                }
            )
        }
        .onAppear {
            tempName = character.name
            // Auto-focus the text field
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isTextFieldFocused = true
            }
        }
    }
    
    private func saveAndDismiss() {
        guard !tempName.isEmpty else { return }
        
        // Update character name
        character.name = tempName
        
        // Save through CharacterManager
        characterManager.updateCharacter(character)
        characterManager.refreshUI()
        
        dismiss()
    }
}
