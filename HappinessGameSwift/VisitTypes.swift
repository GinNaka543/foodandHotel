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

struct VisitSpot: Identifiable, Codable {
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
    var imageData: Data?
    var imagesData: [Data]? // 複数画像対応
    var dayNumber: Int = 1
    var spotCost: Int = 0
    
    init(id: UUID = UUID(), name: String, address: String = "", notes: String = "", event: SpotEvent? = nil, 
         nearestStation: String = "", arrivalTime: Date? = nil, departureTime: Date? = nil,
         stayDuration: Int = 60, transportToNext: TransportInfo? = nil, timeRange: String = "", 
         activity: String = "", imageData: Data? = nil, imagesData: [Data]? = nil, dayNumber: Int = 1, spotCost: Int = 0) {
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
        self.imagesData = imagesData
        self.dayNumber = dayNumber
        self.spotCost = spotCost
    }
}

struct VisitPlanData: Identifiable, Codable {
    var id: UUID
    var animeName: String
    var title: String
    var duration: String
    var spots: [VisitSpot]
    var thumbnailData: Data?
    var createdDate: Date = Date()
    var startTime: Date = Date()
    var totalCost: Int = 0
    var numberOfDays: Int = 1
    
    init(id: UUID = UUID(), animeName: String, title: String, duration: String, spots: [VisitSpot], thumbnailData: Data? = nil, createdDate: Date = Date(), startTime: Date = Date(), numberOfDays: Int = 1) {
        self.id = id
        self.animeName = animeName
        self.title = title
        self.duration = duration
        self.spots = spots
        self.thumbnailData = thumbnailData
        self.createdDate = createdDate
        self.startTime = startTime
        self.numberOfDays = numberOfDays
    }
} 