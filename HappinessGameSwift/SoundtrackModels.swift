import Foundation
import SwiftUI

// サントラ情報を保持する構造体
struct Soundtrack: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var audioData: Data? // MP3ファイルのデータ
    var thumbnailData: Data? // サムネイル画像のデータ
    var duration: TimeInterval? // 曲の長さ
    var artist: String? // アーティスト名
    var createdAt: Date
    
    init(id: UUID = UUID(), title: String, audioData: Data? = nil, thumbnailData: Data? = nil, duration: TimeInterval? = nil, artist: String? = nil, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.audioData = audioData
        self.thumbnailData = thumbnailData
        self.duration = duration
        self.artist = artist
        self.createdAt = createdAt
    }
}

// キャラクター用の拡張
extension Character {
    var soundtracks: [Soundtrack] {
        get {
            if let data = UserDefaults.standard.data(forKey: "character_soundtracks_\(id.uuidString)"),
               let soundtracks = try? JSONDecoder().decode([Soundtrack].self, from: data) {
                return soundtracks
            }
            return []
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "character_soundtracks_\(id.uuidString)")
            }
        }
    }
}

// アニメ用の拡張
extension Anime {
    var soundtracks: [Soundtrack] {
        get {
            if let data = UserDefaults.standard.data(forKey: "anime_soundtracks_\(id.uuidString)"),
               let soundtracks = try? JSONDecoder().decode([Soundtrack].self, from: data) {
                return soundtracks
            }
            return []
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "anime_soundtracks_\(id.uuidString)")
            }
        }
    }
}