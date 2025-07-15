import Foundation

enum EventType: String, CaseIterable, Codable {
    case findLocation = "場所を探す"
    case takePhoto = "写真を撮る"
    case animeScene = "アニメシーンを探す"
    case animeQuiz = "アニメクイズ"
}

struct SpotEvent: Identifiable, Codable {
    var id: UUID
    var type: EventType
    var description: String
    var question: String = ""
    var answer: String = ""
    init(id: UUID = UUID(), type: EventType, description: String, question: String = "", answer: String = "") {
        self.id = id
        self.type = type
        self.description = description
        self.question = question
        self.answer = answer
    }
}

struct TransportInfo: Codable {
    var method: String = "電車"
    var duration: Int = 30
    var cost: Int = 0
    var route: String = ""
}

struct VisitSpot: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var address: String = ""
    var notes: String = ""
    var event: SpotEvent?
    var nearestStation: String = ""
    var arrivalTime: Date?
    var departureTime: Date?
    var stayDuration: Int = 60
    var transportToNext: TransportInfo?
    var isCompleted: Bool = false
    var timeRange: String = ""
    var activity: String = ""
    var imageData: Data? // サムネイル画像（メイン画像）
    var detailImagesData: [Data]? // 詳細画像（予約情報などのスクショ）
    var dayNumber: Int = 1
    var spotCost: Int = 0
    var imageUrl: String = "" // GitHub画像URL（メイン画像）
    var images: [String] = [] // 複数の画像URL
    
    init(id: UUID = UUID(), name: String, address: String = "", notes: String = "", event: SpotEvent? = nil, 
         nearestStation: String = "", arrivalTime: Date? = nil, departureTime: Date? = nil,
         stayDuration: Int = 60, transportToNext: TransportInfo? = nil, timeRange: String = "", 
         activity: String = "", imageData: Data? = nil, detailImagesData: [Data]? = nil, dayNumber: Int = 1, spotCost: Int = 0, imageUrl: String = "", images: [String] = []) {
        self.id = id
        self.name = name
        self.address = address
        self.notes = notes
        self.event = event
        self.nearestStation = nearestStation
        self.arrivalTime = arrivalTime
        self.departureTime = departureTime
        self.stayDuration = stayDuration
        self.transportToNext = transportToNext
        self.timeRange = timeRange
        self.activity = activity
        self.imageData = imageData
        self.detailImagesData = detailImagesData
        self.dayNumber = dayNumber
        self.spotCost = spotCost
        self.imageUrl = imageUrl
        self.images = images
    }
    
    static func == (lhs: VisitSpot, rhs: VisitSpot) -> Bool {
        return lhs.id == rhs.id
    }
}

struct VisitPlanData: Identifiable, Codable {
    var id: UUID
    var animeName: String
    var title: String
    var duration: String
    var spots: [VisitSpot]
    var thumbnailData: Data?
    var thumbnailUrl: String?
    var createdDate: Date = Date()
    var startTime: Date = Date()
    var totalCost: Int = 0
    var numberOfDays: Int = 1
    var isPurchased: Bool = false
    var isDraft: Bool = false
    
    init(id: UUID = UUID(), animeName: String, title: String, duration: String, spots: [VisitSpot], thumbnailData: Data? = nil, thumbnailUrl: String? = nil, createdDate: Date = Date(), startTime: Date = Date(), numberOfDays: Int = 1, isPurchased: Bool = false, isDraft: Bool = false) {
        self.id = id
        self.animeName = animeName
        self.title = title
        self.duration = duration
        self.spots = spots
        self.thumbnailData = thumbnailData
        self.thumbnailUrl = thumbnailUrl
        self.createdDate = createdDate
        self.startTime = startTime
        self.numberOfDays = numberOfDays
        self.isPurchased = isPurchased
        self.isDraft = isDraft
    }
} 