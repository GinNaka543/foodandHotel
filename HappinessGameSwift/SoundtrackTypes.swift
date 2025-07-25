import Foundation
import SwiftUI
import AVFoundation

// サントラ構造体の定義
struct Soundtrack: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var audioData: Data?
    var thumbnailData: Data?
    var duration: TimeInterval?
    var artist: String?
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

// キャラクター用のサントラ拡張
extension Character {
    var soundtracks: [Soundtrack] {
        get {
            return SoundtrackStorage.shared.loadSoundtracks(for: id.uuidString)
        }
        set {
            SoundtrackStorage.shared.saveSoundtracks(for: id.uuidString, soundtracks: newValue)
        }
    }
}

// アニメ用のサントラ拡張
extension Anime {
    var soundtracks: [Soundtrack] {
        get {
            return SoundtrackStorage.shared.loadAnimeSoundtracks(for: id.uuidString)
        }
        set {
            SoundtrackStorage.shared.saveAnimeSoundtracks(for: id.uuidString, soundtracks: newValue)
        }
    }
}

// サントラ行のビュー
struct SoundtrackRow: View {
    let soundtrack: Soundtrack
    let onDelete: () -> Void
    @State private var isPlaying = false
    @State private var audioPlayer: AVAudioPlayer?
    
    var body: some View {
        HStack(spacing: 12) {
            // サムネイル
            if let thumbnailData = soundtrack.thumbnailData,
               let image = UIImage(data: thumbnailData) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 50, height: 50)
                    .cornerRadius(8)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.purple.opacity(0.1))
                        .frame(width: 50, height: 50)
                    Image(systemName: "music.note")
                        .foregroundColor(.purple)
                        .font(.system(size: 20))
                }
            }
            
            // タイトルとアーティスト
            VStack(alignment: .leading, spacing: 4) {
                Text(soundtrack.title)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)
                
                if let artist = soundtrack.artist, !artist.isEmpty {
                    Text(artist)
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                
                if let duration = soundtrack.duration {
                    Text(formatDuration(duration))
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            // 再生ボタン
            Button(action: togglePlayback) {
                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 30))
                    .foregroundColor(.purple)
            }
            
            // 削除ボタン
            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 16))
                    .foregroundColor(.red)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onAppear {
            setupAudioPlayer()
        }
        .onDisappear {
            audioPlayer?.stop()
        }
    }
    
    private func togglePlayback() {
        if isPlaying {
            audioPlayer?.pause()
            isPlaying = false
        } else {
            audioPlayer?.play()
            isPlaying = true
        }
    }
    
    private func setupAudioPlayer() {
        guard let audioData = soundtrack.audioData else { return }
        do {
            audioPlayer = try AVAudioPlayer(data: audioData)
            audioPlayer?.prepareToPlay()
        } catch {
        }
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}