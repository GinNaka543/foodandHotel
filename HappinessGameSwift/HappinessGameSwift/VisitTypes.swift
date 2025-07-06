import Foundation

public enum EventType: String, CaseIterable, Codable {
    case findLocation = "場所を探す"
    case takePhoto = "写真を撮る"
    case animeScene = "アニメシーンを探す"
    case animeQuiz = "アニメクイズ"
}

public struct SpotEvent: Identifiable, Codable {
    public let id = UUID()
    public var type: EventType
    public var description: String
    public var question: String = ""
    public var answer: String = ""
    public init(type: EventType, description: String, question: String = "", answer: String = "") {
        self.type = type
        self.description = description
        self.question = question
        self.answer = answer
    }
}

public struct VisitSpot: Identifiable, Codable {
    public let id = UUID()
    public var name: String
    public var address: String = ""
    public var notes: String = ""
    public var event: SpotEvent?
    public init(name: String, address: String = "", notes: String = "", event: SpotEvent? = nil) {
        self.name = name
        self.address = address
        self.notes = notes
        self.event = event
    }
}

public struct VisitPlanData: Identifiable, Codable {
    public let id = UUID()
    public var animeName: String
    public var title: String
    public var duration: String
    public var spots: [VisitSpot]
    public var thumbnailData: Data?
    public var createdDate: Date = Date()
    public init(animeName: String, title: String, duration: String, spots: [VisitSpot], thumbnailData: Data? = nil, createdDate: Date = Date()) {
        self.animeName = animeName
        self.title = title
        self.duration = duration
        self.spots = spots
        self.thumbnailData = thumbnailData
        self.createdDate = createdDate
    }
} 