import SwiftUI
import PhotosUI
import UIKit
import Foundation
import Photos
import FirebaseFirestore

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
            
            // Firebaseにも同期（現在のユーザープロファイルが存在する場合）
            if let profileData = UserDefaultsHelper.shared.getData(forKey: "currentUserProfile"),
               let userProfile = try? JSONDecoder().decode(UserProfile.self, from: profileData) {
                FirebaseManager.shared.saveUserProfile(userProfile) { result in
                    switch result {
                    case .success():
                        break
                    case .failure(_):
                        break
                    }
                }
            }
        } else {
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
    var externalLink: String? // 外部リンク（Firebaseから取得）
    
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
    var tag: String
    var birthday: Date
    var favoriteFood: String
    var age: String // 年齢
    var voiceActor: String // 声優
    var cupSize: String // カップ数
    var seichi: String // 聖地
    var height: String // 身長
    var customFields: [CustomField]? // カスタムフィールド
    var order: Int = 0 // 表示順序用フィールド

    static func == (lhs: Character, rhs: Character) -> Bool {
        lhs.id == rhs.id
    }
    // Codable対応
    enum CodingKeys: String, CodingKey {
        case id, imageIdentifier, backgroundImagePath, name, tag, birthday, favoriteFood, age, voiceActor, cupSize, seichi, height, customFields, order
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(tag, forKey: .tag)
        try container.encode(birthday, forKey: .birthday)
        try container.encode(favoriteFood, forKey: .favoriteFood)
        try container.encode(age, forKey: .age)
        try container.encode(voiceActor, forKey: .voiceActor)
        try container.encode(cupSize, forKey: .cupSize)
        try container.encode(seichi, forKey: .seichi)
        try container.encode(height, forKey: .height)
        try container.encodeIfPresent(imageIdentifier, forKey: .imageIdentifier)
        try container.encodeIfPresent(backgroundImagePath, forKey: .backgroundImagePath)
        try container.encodeIfPresent(customFields, forKey: .customFields)
        try container.encode(order, forKey: .order)
    }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        tag = try container.decode(String.self, forKey: .tag)
        birthday = try container.decode(Date.self, forKey: .birthday)
        favoriteFood = (try? container.decode(String.self, forKey: .favoriteFood)) ?? ""
        age = (try? container.decode(String.self, forKey: .age)) ?? ""
        voiceActor = (try? container.decode(String.self, forKey: .voiceActor)) ?? ""
        cupSize = (try? container.decode(String.self, forKey: .cupSize)) ?? ""
        seichi = (try? container.decode(String.self, forKey: .seichi)) ?? ""
        height = (try? container.decode(String.self, forKey: .height)) ?? ""
        imageIdentifier = try? container.decodeIfPresent(String.self, forKey: .imageIdentifier)
        backgroundImagePath = try? container.decodeIfPresent(String.self, forKey: .backgroundImagePath)
        customFields = try? container.decodeIfPresent([CustomField].self, forKey: .customFields)
        order = (try? container.decode(Int.self, forKey: .order)) ?? 0
    }
    init(id: UUID, imageIdentifier: String?, backgroundImagePath: String? = nil, name: String, tag: String, birthday: Date, favoriteFood: String = "", age: String, voiceActor: String, cupSize: String, seichi: String, height: String, customFields: [CustomField]? = nil, order: Int = 0) {
        self.id = id
        self.imageIdentifier = imageIdentifier
        self.backgroundImagePath = backgroundImagePath
        self.name = name
        self.tag = tag
        self.birthday = birthday
        self.favoriteFood = favoriteFood
        self.age = age
        self.voiceActor = voiceActor
        self.cupSize = cupSize
        self.seichi = seichi
        self.height = height
        self.customFields = customFields
        self.order = order
    }
}

struct CharaScreen: View {
    @EnvironmentObject var characterManager: CharacterManager
    @EnvironmentObject var mainTab: MainTabSelection
    @State private var showAddSheet = false
    @State private var selectedCharacter: Character? = nil
    @State private var showRankingAdmin = false
    @State private var showNavigationMenu = false
    @State private var showCharacterOrderModal = false
    @State private var showPrivacyPolicy = false
    @State private var bannerTimer: Timer? = nil
    @State private var bannerVideo: MemoryVideo? = nil
    @State private var allYouTubeVideos: [MemoryVideo] = []
    @State private var displayedVideoIds: Set<UUID> = []
    
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
                            Text("キャラを追加")
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
                // スクロール可能なコンテンツ
                ScrollView {
                    VStack(spacing: 0) {
                        // 広告バナー
                        bannerView
                        
                        // キャラリスト
                        if filteredCharacters.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "person.2.square.stack")
                                    .font(.system(size: 50))
                                    .foregroundColor(.purple)
                                Text("お気に入りのキャラクターを追加しよう")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.black)
                                Text("推しキャラの情報を管理して、いつでも確認できます")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, 20)
                                
                                Button(action: { showAddSheet = true }) {
                                    HStack {
                                        Image(systemName: "plus")
                                        Text("キャラクターを追加")
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
        .sheet(isPresented: $showCharacterOrderModal, onDismiss: {
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
            // 最初の動画を選択
            selectRandomYouTubeVideo()
            // 動画をローテーション表示
            
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
        .fullScreenCover(item: $selectedCharacter) { character in
            CharacterDetailView(character: Binding(
                get: { character },
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
    )
    }
    // UserDefaults保存・読込
    private func saveCharacters() {
        characterManager.saveCharacters()
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
                            Text(video.title.isEmpty ? "動画" : video.title)
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.3), radius: 0, x: 0, y: 1)
                                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                                .lineLimit(1)
                            
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
                    if let url = URL(string: youtubeURL) {
                        UIApplication.shared.open(url)
                    }
                }
            } else {
                // YouTube動画が登録されていない場合の表示
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
        allYouTubeVideos = []
        for character in characterManager.characters {
            let key = "videos_\(character.id.uuidString)"
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
    
    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            if let imageIdentifier = character.imageIdentifier, let image = loadImageFromPath(imageIdentifier) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
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
                Text(character.name)
                    .font(.system(size: 17, weight: .semibold))
                Text("#" + character.tag)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .lineLimit(1)
                    .frame(maxWidth: 200, alignment: .leading)
            }
            Spacer()
            Text(DateFormatter.monthDayEnglish.string(from: character.birthday))
                .font(.system(size: 14))
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
    @State private var tag = ""
    @State private var voiceActor = ""
    @State private var birthday = Date()
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var image: UIImage? = nil
    @State private var savedImagePath: String? = nil
    // 月日Picker用
    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var selectedDay: Int = Calendar.current.component(.day, from: Date())

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // ヘッダー
                ZStack {
                    Text("キャラ追加")
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
                            let components = DateComponents(year: 2000, month: selectedMonth, day: selectedDay)
                            let calendar = Calendar.current
                            let date = calendar.date(from: components) ?? Date()
                            let newChar = Character(id: UUID(), imageIdentifier: savedImagePath, name: name, tag: tag, birthday: date, favoriteFood: "", age: "", voiceActor: voiceActor, cupSize: "", seichi: "", height: "", customFields: nil)
                            characterManager.addCharacterAtTop(newChar)
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
                                            (name.isEmpty || tag.isEmpty) ? Color.gray.opacity(0.3) : Color(red: 0.6, green: 0.4, blue: 0.9),
                                            (name.isEmpty || tag.isEmpty) ? Color.gray.opacity(0.3) : Color(red: 0.8, green: 0.5, blue: 0.9)
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .cornerRadius(20)
                        }
                        .disabled(name.isEmpty || tag.isEmpty)
                    }
                }
                .padding()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // 名前入力
                        TextField("キャラクター名", text: $name)
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
                            Text("アイコン画像を選択")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        .onChange(of: selectedItem) { _, newValue in
                            if let newItem = newValue {
                                Task {
                                    if let data = try? await newItem.loadTransferable(type: Data.self), let uiImage = UIImage(data: data) {
                                        image = uiImage
                                        let fileName = "icon_\(UUID().uuidString).png"
                                        if let path = saveImageToDocuments(uiImage, fileName: fileName) {
                                            savedImagePath = path
                                        }
                                    }
                                }
                            }
                        }
                        
                        // タグ入力
                        TextField("タグ", text: $tag)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding(.vertical, 8)
                            .overlay(
                                VStack {
                                    Spacer()
                                    Divider()
                                        .background(Color.gray.opacity(0.5))
                                }
                            )
                            .padding(.horizontal)
                        
                        // 声優入力
                        TextField("声優名", text: $voiceActor)
                            .textFieldStyle(PlainTextFieldStyle())
                            .padding(.vertical, 8)
                            .overlay(
                                VStack {
                                    Spacer()
                                    Divider()
                                        .background(Color.gray.opacity(0.5))
                                }
                            )
                            .padding(.horizontal)
                        
                        // 誕生日
                        VStack(spacing: 12) {
                            HStack(spacing: 8) {
                                Image(systemName: "gift.fill")
                                    .foregroundColor(.gray.opacity(0.6))
                                    .font(.system(size: 20))
                                Text("誕生日")
                                    .foregroundColor(.gray.opacity(0.8))
                                    .font(.system(size: 16))
                                Spacer()
                                
                                HStack(spacing: 4) {
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
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
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
    // 月ごとの日数を返す
    private func daysInMonth(_ month: Int) -> Int {
        let calendar = Calendar.current
        let dateComponents = DateComponents(year: 2000, month: month)
        let date = calendar.date(from: dateComponents) ?? Date()
        return calendar.range(of: .day, in: .month, for: date)?.count ?? 30
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
    @State private var iconPickerItem: PhotosPickerItem? = nil
    @State private var iconImage: UIImage? = nil
    @State private var tempIconImage: UIImage? = nil
    @State private var backgroundPickerItem: PhotosPickerItem? = nil
    @State private var backgroundImage: UIImage? = nil

    var body: some View {
        ZStack {
            // 背景を最初に配置
            let currentCharacter = characterManager.characters.first(where: { $0.id == character.id }) ?? character
            
            // 背景画像 or グラデーション
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
                        if let imageIdentifier = currentCharacter.imageIdentifier, let image = loadImageFromPath(imageIdentifier) {
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
                    .onTapGesture { showEditIconModal = true }
                    // 名前
                    Text(currentCharacter.name)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 1)
                        .padding(.top, 20)
                        .onTapGesture {
                            showEditTitleTagModal = true
                        }
                    // 誕生日
                    Text(DateFormatter.monthDayEnglish.string(from: currentCharacter.birthday).uppercased())
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 1)
                        .padding(.top, 4)
                    // ボタン群
                    HStack {
                        Spacer()
                        Button(action: { showArtwork = true }) {
                            VStack(spacing: 4) {
                                Image(systemName: "photo.on.rectangle")
                                    .foregroundColor(.white)
                                    .font(.system(size: 24))
                                Text("ArtWork").font(.caption2).foregroundColor(.white)
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
                                Text("Video").font(.caption2).foregroundColor(.white)
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
                                Text("About").font(.caption2).foregroundColor(.white)
                            }
                            .frame(width: 90, height: 70)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PlainButtonStyle())
                        Spacer()
                    }
                    .padding(.top, 40)
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
                                        let fileName = "icon_\(UUID().uuidString).png"
                                        let imagePath = saveImageToDocuments(uiImage, fileName: fileName)
                                        
                                        // 古い画像ファイルを削除
                                        if let oldPath = currentCharacter.imageIdentifier {
                                            try? FileManager.default.removeItem(atPath: oldPath)
                                        }
                                        
                                        // 新しいCharacterオブジェクトを作成して更新
                                        var updatedCharacter = character
                                        updatedCharacter.imageIdentifier = imagePath
                                        
                                        // Bindingを通じて更新（これがsetterを呼び出す）
                                        character = updatedCharacter
                                        
                                        // CharacterManagerも更新してUI全体を更新
                                        characterManager.updateCharacter(updatedCharacter)
                                        characterManager.refreshUI()
                                        
                                        // モーダルを自動的に閉じる
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                            showEditIconModal = false
                                        }
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
                .onDisappear {
                    // モーダルが閉じたときにクリーンアップ
                    tempIconImage = nil
                    iconPickerItem = nil
                }
            }
            .sheet(isPresented: $showEditBackgroundModal) {
                // 最新のキャラクター情報を取得
                if let updatedCharacter = characterManager.characters.first(where: { $0.id == character.id }) {
                    EditBackgroundView(character: Binding(
                        get: { updatedCharacter },
                        set: { newValue in
                            character = newValue
                            characterManager.updateCharacter(newValue)
                        }
                    ), characterManager: characterManager)
                } else {
                    EditBackgroundView(character: $character, characterManager: characterManager)
                }
            }
            .fullScreenCover(isPresented: $showArtwork) {
                // 最新のキャラクター情報を渡す
                ArtworkScreen(character: characterManager.characters.first(where: { $0.id == character.id }) ?? character)
                    .environmentObject(characterManager)
            }
            .fullScreenCover(isPresented: $showVideo) {
                VideoGalleryScreen(character: character)
                    .environmentObject(characterManager)
            }
            .fullScreenCover(isPresented: $showAbout) {
                AboutView(characters: $characters, characterId: character.id, onClose: { 
                    showAbout = false
                    // 最新のキャラクター情報を取得して更新
                    if let updatedCharacter = characterManager.characters.first(where: { $0.id == character.id }) {
                        character = updatedCharacter
                    }
                })
                    .environmentObject(characterManager)
            }
            .sheet(isPresented: $showEditTitleTagModal) {
                EditTitleTagBackgroundView(
                    character: $character,
                    characterManager: characterManager
                )
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
            
            // キャラクターのサントラがある場合、ランダムに再生
            if !currentCharacter.soundtracks.isEmpty {
                SoundtrackManager.shared.collectAllSoundtracks(
                    characters: [currentCharacter],
                    animes: []
                )
                SoundtrackManager.shared.startRandomPlayback()
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
        .onDisappear {
            // ビューが消える時に音楽を停止
            SoundtrackManager.shared.stopPlayback()
        }
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
    
    static let monthDayJapanese: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日"
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
    @State private var editedVoiceActor: String = ""
    @State private var editedCupSize: String = ""
    @State private var editedBirthday: Date = Date()
    @State private var editedTag: String = ""
    @State private var isEditingProfile: Bool = false
    @State private var isEditingDescription: Bool = false
    @State private var iconPickerItem: PhotosPickerItem? = nil
    @State private var newIconImage: UIImage?
    
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

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // キャラクターバナー画像
                    if let character = character {
                        VStack(spacing: 0) {
                            Button(action: {
                                activeSheet = .iconPicker
                            }) {
                                if let imageIdentifier = character.imageIdentifier, let image = loadImageFromPath(imageIdentifier) {
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
                                                        Text(isEditingProfile ? editedName : character.name)
                                                            .font(.system(size: 24, weight: .bold))
                                                            .foregroundColor(.white)
                                                        
                                                        let tagText = isEditingProfile ? editedTag : character.tag
                                                        if !tagText.isEmpty {
                                                            Text(tagText)
                                                                .font(.system(size: 16, weight: .medium))
                                                                .foregroundColor(.white)
                                                        }
                                                        
                                                        let voiceActorText = isEditingProfile ? editedVoiceActor : character.voiceActor
                                                        if !voiceActorText.isEmpty {
                                                            Text(voiceActorText)
                                                                .font(.system(size: 14, weight: .regular))
                                                                .foregroundColor(.white.opacity(0.8))
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
                                                Image(systemName: "person.fill")
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
                                                        Text(isEditingProfile ? editedName : character.name)
                                                            .font(.system(size: 24, weight: .bold))
                                                            .foregroundColor(.white)
                                                        
                                                        let tagText = isEditingProfile ? editedTag : character.tag
                                                        if !tagText.isEmpty {
                                                            Text(tagText)
                                                                .font(.system(size: 16, weight: .medium))
                                                                .foregroundColor(.white)
                                                        }
                                                        
                                                        let voiceActorText = isEditingProfile ? editedVoiceActor : character.voiceActor
                                                        if !voiceActorText.isEmpty {
                                                            Text(voiceActorText)
                                                                .font(.system(size: 14, weight: .regular))
                                                                .foregroundColor(.white.opacity(0.8))
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
                        .padding(.top, 20)
                        .padding(.bottom, 10)
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
                                editableProfileRow(label: "名前", text: $editedName)
                                    .onChange(of: editedName) { saveCharacter() }
                                Divider().padding(.leading, 20)
                                editableProfileRow(label: "タグ", text: $editedTag)
                                    .onChange(of: editedTag) { saveCharacter() }
                                Divider().padding(.leading, 20)
                                dateProfileRow(label: "誕生日", date: $editedBirthday)
                                    .onChange(of: editedBirthday) { saveCharacter() }
                                Divider().padding(.leading, 20)
                                editableProfileRow(label: "年齢", text: $editedAge)
                                    .onChange(of: editedAge) { saveCharacter() }
                                Divider().padding(.leading, 20)
                                editableProfileRow(label: "好きな食べ物", text: $editedFavoriteFood)
                                    .onChange(of: editedFavoriteFood) { saveCharacter() }
                                Divider().padding(.leading, 20)
                                editableProfileRow(label: "声優", text: $editedVoiceActor)
                                    .onChange(of: editedVoiceActor) { saveCharacter() }
                                Divider().padding(.leading, 20)
                                editableProfileRow(label: "カップ数", text: $editedCupSize)
                                    .onChange(of: editedCupSize) { saveCharacter() }
                            } else {
                                profileRow(label: "名前", value: character?.name ?? "")
                                Divider().padding(.leading, 20)
                                profileRow(label: "タグ", value: "#\(character?.tag ?? "")")
                                Divider().padding(.leading, 20)
                                profileRow(label: "誕生日", value: DateFormatter.monthDayJapanese.string(from: character?.birthday ?? Date()))
                                Divider().padding(.leading, 20)
                                profileRow(label: "年齢", value: character?.age ?? "未設定")
                                Divider().padding(.leading, 20)
                                profileRow(label: "好きな食べ物", value: character?.favoriteFood ?? "未設定")
                                Divider().padding(.leading, 20)
                                profileRow(label: "声優", value: character?.voiceActor ?? "未設定")
                                if let cupSize = character?.cupSize, !cupSize.isEmpty {
                                    Divider().padding(.leading, 20)
                                    profileRow(label: "カップ数", value: cupSize)
                                }
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
                                if profileDescription.isEmpty {
                                    Text("概要を入力してください...")
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
                                    .onChange(of: profileDescription) { saveCharacter() }
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
                            if profileDescription.isEmpty {
                                Text("概要が未設定です")
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
                            Text("サントラ")
                                .font(.system(size: 20, weight: .bold))
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 32)
                        .padding(.bottom, 16)
                        
                        // サントラリスト
                        if character?.soundtracks.isEmpty ?? true {
                            Text("サントラが未設定です")
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
            .navigationBarTitle("About", displayMode: .inline)
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
                    Text(isEditingProfile || isEditingDescription ? "完了" : "編集")
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
                editedVoiceActor = character.voiceActor
                editedCupSize = character.cupSize
                editedBirthday = character.birthday
                editedTag = character.tag
                
            }
        }
        // サントラプレイヤーを表示
        .overlay(
            VStack {
                Spacer()
                SoundtrackPlayerView()
                    .padding(.bottom, 20)
            }
        )
        .onDisappear {
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
                    
                    Button("キャンセル") {
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
                            Text("アイコンを選択")
                                .font(.headline)
                            
                            if let newIconImage = newIconImage {
                                Image(uiImage: newIconImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 150, height: 150)
                                    .clipShape(Circle())
                            }
                            
                            PhotosPicker(selection: $iconPickerItem, matching: .images) {
                                Text("画像を選択")
                                    .padding()
                                    .background(Color.blue)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                            }
                            
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
                            
                            Button("キャンセル") {
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
                                    newIconImage = image
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
    
    private func saveCharacter() {
        guard let idx = characters.firstIndex(where: { $0.id == characterId }) else { return }
        
        // 編集中の場合は編集内容を保存
        var updatedCharacter = characters[idx]
        
        // プロフィール編集内容を常に保存
        updatedCharacter.name = editedName
        updatedCharacter.age = editedAge
        updatedCharacter.favoriteFood = editedFavoriteFood
        updatedCharacter.voiceActor = editedVoiceActor
        updatedCharacter.cupSize = editedCupSize
        updatedCharacter.birthday = editedBirthday
        updatedCharacter.tag = editedTag
        
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
        if let savedPath = saveImageToDocuments(iconImage, fileName: fileName) {
            var updatedCharacter = characters[idx]
            
            // 古いアイコンを削除
            if let oldPath = updatedCharacter.imageIdentifier {
                try? FileManager.default.removeItem(atPath: oldPath)
            }
            
            // 新しいアイコンパスを設定
            updatedCharacter.imageIdentifier = savedPath
            
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
                Text("\(ranking.rank)位")
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
    @StateObject private var firebaseManager = FirebaseManager.shared
    
    var body: some View {
        Button(action: {
            if let url = URL(string: ad.linkURL) {
                firebaseManager.recordAdClick(advertisementId: ad.id ?? "")
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
            firebaseManager.recordAdImpression(advertisementId: ad.id ?? "")
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
                    Text("キャラクターランキング管理")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.black)
                    Spacer()
                    Button("閉じる") {
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
                Text("キャラクターを選択してください")
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
                    Text("\(selectedRank)位のキャラクターを選択")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.black)
                    Spacer()
                    Button("キャンセル") {
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
                    TextField("キャラクターを検索", text: $searchText)
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
                Text("#\(character.tag)")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // 選択ボタン
            Button("選択") {
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

// 文字列をn文字ごとに分割するchunked拡張を追加
extension String {
    func chunked(_ length: Int) -> [String] {
        var result: [String] = []
        var start = startIndex
        while start < endIndex {
            let end = index(start, offsetBy: length, limitedBy: endIndex) ?? endIndex
            result.append(String(self[start..<end]))
            start = end
        }
        return result
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
                                await MainActor.run {
                                    backgroundImage = uiImage
                                    
                                    // 即座に背景を更新
                                    let fileName = "bg_\(UUID().uuidString).png"
                                    if let imagePath = saveImageToDocuments(uiImage, fileName: fileName) {
                                        // 古い画像を削除
                                        if let oldPath = character.backgroundImagePath {
                                            try? FileManager.default.removeItem(atPath: oldPath)
                                        }
                                        
                                        // 新しいCharacterオブジェクトを作成して更新
                                        var updatedCharacter = character
                                        updatedCharacter.backgroundImagePath = imagePath
                                        
                                        // Bindingを通じて更新
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
                
                Text("画像を選択すると自動的に背景が変更されます")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.top, 10)
                
                Spacer()
            }
            .padding()
            .navigationBarTitle("背景画像を変更", displayMode: .inline)
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
                Text("編集する項目を選択してください")
                    .font(.headline)
                    .padding()
                
                VStack(spacing: 15) {
                    Button(action: {
                        isEditingProfile = true
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "person.crop.circle")
                                .foregroundColor(.blue)
                            Text("プロフィールを編集")
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
                            Text("概要を編集")
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
                            Text("サントラ追加")
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
            .navigationTitle("編集項目選択")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("キャンセル") {
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
    @State private var editedTag: String = ""
    @State private var backgroundPickerItem: PhotosPickerItem? = nil
    @State private var tempBackgroundImage: UIImage? = nil
    @State private var showDeleteConfirmation = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // タイトル編集
                VStack(alignment: .leading, spacing: 8) {
                    Text("名前")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                    TextField("キャラクター名", text: $editedName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)
                
                // タグ編集
                VStack(alignment: .leading, spacing: 8) {
                    Text("タグ")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                    TextField("#タグ", text: $editedTag)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)
                
                // 背景画像編集
                VStack(alignment: .leading, spacing: 8) {
                    Text("背景画像")
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
                                            Text("タップして背景を選択")
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
                                Text("背景を削除")
                                    .foregroundColor(.red)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
                
                Spacer()
            }
            .padding(.top)
            .navigationTitle("編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
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
                editedTag = character.tag
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
            .alert("背景を削除", isPresented: $showDeleteConfirmation) {
                Button("削除", role: .destructive) {
                    deleteBackground()
                }
                Button("キャンセル", role: .cancel) {}
            } message: {
                Text("背景画像を削除しますか？")
            }
        }
    }
    
    private func saveChanges() {
        var updatedCharacter = character
        updatedCharacter.name = editedName
        updatedCharacter.tag = editedTag
        
        // 背景画像の保存
        if let tempBackgroundImage = tempBackgroundImage {
            let fileName = "background_\(UUID().uuidString).png"
            let imagePath = saveImageToDocuments(tempBackgroundImage, fileName: fileName)
            
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
}
