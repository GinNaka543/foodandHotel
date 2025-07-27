import Foundation

// カスタムフィールド用構造体
struct AnimeCustomField: Hashable, Codable {
    var name: String
    var value: String
}

// 視聴ステータス用enum
enum WatchStatus: String, CaseIterable, Codable {
    case none = "none"
    case watching = "watching"
    case completed = "completed"
    case dropped = "dropped"
    case willWatch = "willWatch"
    case watchAgain = "watchAgain"
    case thisTerm = "thisTerm"
    
    var displayName: String {
        switch self {
        case .none:
            return "未設定"
        case .watching:
            return "視聴中"
        case .completed:
            return "完了"
        case .dropped:
            return "中断"
        case .willWatch:
            return "視聴予定"
        case .watchAgain:
            return "再視聴"
        case .thisTerm:
            return "今期"
        }
    }
}

// アニメジャンル用enum
enum AnimeGenre: String, Codable, CaseIterable {
    case serious = "serious"
    case romcom = "romcom"
    case sports = "sports"
    case comedy = "comedy"
    case isekai = "isekai"
    case sf = "sf"
    case art = "art"
    case brain = "brain"
    case healing = "healing"
    case action = "action"
    case adventure = "adventure"
    case drama = "drama"
    case fantasy = "fantasy"
    case horror = "horror"
    case mystery = "mystery"
    case psychological = "psychological"
    case romance = "romance"
    case slice_of_life = "slice_of_life"
    case supernatural = "supernatural"
    case thriller = "thriller"
    case mecha = "mecha"
    case music = "music"
    case school = "school"
    case military = "military"
    case historical = "historical"
    
    var displayName: String {
        switch self {
        case .serious:
            return NSLocalizedString("serious", comment: "Serious")
        case .romcom:
            return NSLocalizedString("romcom", comment: "Romantic Comedy")
        case .sports:
            return NSLocalizedString("sports", comment: "Sports")
        case .comedy:
            return NSLocalizedString("comedy", comment: "Comedy")
        case .isekai:
            return NSLocalizedString("isekai", comment: "Isekai")
        case .sf:
            return NSLocalizedString("sf", comment: "Science Fiction")
        case .art:
            return NSLocalizedString("art", comment: "Art")
        case .brain:
            return NSLocalizedString("brain", comment: "Brain")
        case .healing:
            return NSLocalizedString("healing", comment: "Healing")
        case .action:
            return NSLocalizedString("action", comment: "Action")
        case .adventure:
            return NSLocalizedString("adventure", comment: "Adventure")
        case .drama:
            return NSLocalizedString("drama", comment: "Drama")
        case .fantasy:
            return NSLocalizedString("fantasy", comment: "Fantasy")
        case .horror:
            return NSLocalizedString("horror", comment: "Horror")
        case .mystery:
            return NSLocalizedString("mystery", comment: "Mystery")
        case .psychological:
            return NSLocalizedString("psychological", comment: "Psychological")
        case .romance:
            return NSLocalizedString("romance", comment: "Romance")
        case .slice_of_life:
            return NSLocalizedString("slice_of_life", comment: "Slice of Life")
        case .supernatural:
            return NSLocalizedString("supernatural", comment: "Supernatural")
        case .thriller:
            return NSLocalizedString("thriller", comment: "Thriller")
        case .mecha:
            return NSLocalizedString("mecha", comment: "Mecha")
        case .music:
            return NSLocalizedString("music", comment: "Music")
        case .school:
            return NSLocalizedString("school", comment: "School")
        case .military:
            return NSLocalizedString("military", comment: "Military")
        case .historical:
            return NSLocalizedString("historical", comment: "Historical")
        }
    }
}

// メインのAnime構造体
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
    var genres: [AnimeGenre] = []  // ジャンルリスト
    var iconScale: Double = 1.0
    var iconOffsetX: Double = 0.0
    var iconOffsetY: Double = 0.0
    var watchLink: String = ""  // 視聴リンク
    
    init(id: UUID = UUID(),
         imageIdentifier: String? = nil,
         backgroundImagePath: String? = nil,
         title: String,
         hashtag: String,
         releaseDate: Date = Date(),
         customFields: [AnimeCustomField]? = nil,
         watchStatus: WatchStatus = .none,
         watchStatuses: [WatchStatus] = [],
         order: Int = 0,
         rating: Double = 0.0,
         voiceActors: [String] = [],
         characters: [String] = [],
         genres: [AnimeGenre] = [],
         iconScale: Double = 1.0,
         iconOffsetX: Double = 0.0,
         iconOffsetY: Double = 0.0,
         watchLink: String = "") {
        self.id = id
        self.imageIdentifier = imageIdentifier
        self.backgroundImagePath = backgroundImagePath
        self.title = title
        self.hashtag = hashtag
        self.releaseDate = releaseDate
        self.customFields = customFields
        self.watchStatus = watchStatus
        self.watchStatuses = watchStatuses
        self.order = order
        self.rating = rating
        self.voiceActors = voiceActors
        self.characters = characters
        self.genres = genres
        self.iconScale = iconScale
        self.iconOffsetX = iconOffsetX
        self.iconOffsetY = iconOffsetY
        self.watchLink = watchLink
    }
}