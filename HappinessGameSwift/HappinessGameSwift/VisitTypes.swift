import Foundation

enum EventType: String, CaseIterable, Codable {
    case findLocation = "場所を探す"
    case takePhoto = "写真を撮る"
    case animeScene = "アニメシーンを探す"
    case animeQuiz = "アニメクイズ"
}

struct SpotEvent: Identifiable, Codable {
    let id = UUID()
    var type: EventType
    var description: String
    var question: String = ""
    var answer: String = ""
    init(type: EventType, description: String, question: String = "", answer: String = "") {
        self.type = type
        self.description = description
        self.question = question
        self.answer = answer
    }
}

struct VisitSpot: Identifiable, Codable {
    let id = UUID()
    var name: String
    var address: String = ""
    var notes: String = ""
    var event: SpotEvent?
    init(name: String, address: String = "", notes: String = "", event: SpotEvent? = nil) {
        self.name = name
        self.address = address
        self.notes = notes
        self.event = event
    }
}

struct VisitPlanData: Identifiable, Codable {
    let id = UUID()
    var animeName: String
    var title: String
    var duration: String
    var spots: [VisitSpot]
    var thumbnailData: Data?
    var createdDate: Date = Date()
    init(animeName: String, title: String, duration: String, spots: [VisitSpot], thumbnailData: Data? = nil, createdDate: Date = Date()) {
        self.animeName = animeName
        self.title = title
        self.duration = duration
        self.spots = spots
        self.thumbnailData = thumbnailData
        self.createdDate = createdDate
    }
} 