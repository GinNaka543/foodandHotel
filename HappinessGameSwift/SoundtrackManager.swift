import Foundation
import AVFoundation
import SwiftUI

class SoundtrackManager: NSObject, ObservableObject, AVAudioPlayerDelegate {
    static let shared = SoundtrackManager()
    
    @Published var isPlaying = false
    @Published var currentSoundtrack: Soundtrack?
    
    private var audioPlayer: AVAudioPlayer?
    private var fadeTimer: Timer?
    private var allSoundtracks: [Soundtrack] = []
    private let fadeInDuration: TimeInterval = 3.0 // フェードイン時間（秒）
    private let maxVolume: Float = 0.7 // 最大音量
    
    private override init() {
        super.init()
    }
    
    // すべてのキャラクターとアニメからサントラを収集
    func collectAllSoundtracks(characters: [Character], animes: [Anime]) {
        allSoundtracks = []
        
        // キャラクターのサントラを追加
        for character in characters {
            allSoundtracks.append(contentsOf: character.soundtracks)
        }
        
        // アニメのサントラを追加
        for anime in animes {
            allSoundtracks.append(contentsOf: anime.soundtracks)
        }
        
        // 重複を削除（同じIDのサントラを削除）
        let uniqueSoundtracks = Dictionary(grouping: allSoundtracks, by: { $0.id })
            .compactMap { $0.value.first }
        allSoundtracks = uniqueSoundtracks
    }
    
    // ランダムに再生を開始
    func startRandomPlayback() {
        guard !allSoundtracks.isEmpty else { return }
        
        // 現在再生中の場合は停止
        stopPlayback()
        
        // ランダムにサントラを選択
        if let randomSoundtrack = allSoundtracks.randomElement() {
            playSoundtrack(randomSoundtrack)
        }
    }
    
    // 特定のサントラを再生
    private func playSoundtrack(_ soundtrack: Soundtrack) {
        guard let audioData = soundtrack.audioData else { return }
        
        do {
            audioPlayer = try AVAudioPlayer(data: audioData)
            audioPlayer?.delegate = self
            audioPlayer?.volume = 0.0 // 初期音量を0に設定
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            
            currentSoundtrack = soundtrack
            isPlaying = true
            
            // フェードインを開始
            startFadeIn()
        } catch {
            print("サントラの再生に失敗: \(error)")
        }
    }
    
    // フェードイン効果
    private func startFadeIn() {
        fadeTimer?.invalidate()
        
        let fadeSteps = 30 // フェードのステップ数
        let fadeInterval = fadeInDuration / Double(fadeSteps)
        let volumeIncrement = maxVolume / Float(fadeSteps)
        
        var currentStep = 0
        
        fadeTimer = Timer.scheduledTimer(withTimeInterval: fadeInterval, repeats: true) { [weak self] timer in
            guard let self = self else {
                timer.invalidate()
                return
            }
            
            currentStep += 1
            
            if currentStep >= fadeSteps {
                self.audioPlayer?.volume = self.maxVolume
                timer.invalidate()
                self.fadeTimer = nil
            } else {
                self.audioPlayer?.volume = volumeIncrement * Float(currentStep)
            }
        }
    }
    
    // 再生を停止
    func stopPlayback() {
        fadeTimer?.invalidate()
        fadeTimer = nil
        
        audioPlayer?.stop()
        audioPlayer = nil
        
        isPlaying = false
        currentSoundtrack = nil
    }
    
    // 一時停止
    func pausePlayback() {
        audioPlayer?.pause()
        isPlaying = false
    }
    
    // 再開
    func resumePlayback() {
        audioPlayer?.play()
        isPlaying = true
    }
    
    // AVAudioPlayerDelegate - 再生が終了したとき
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        if flag {
            // 次のランダム曲を再生
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
                self?.startRandomPlayback()
            }
        }
    }
}

// サントラ再生コントロールビュー
struct SoundtrackPlayerView: View {
    @ObservedObject var manager = SoundtrackManager.shared
    
    var body: some View {
        if manager.isPlaying, let soundtrack = manager.currentSoundtrack {
            VStack {
                HStack(spacing: 12) {
                    // サムネイル
                    if let thumbnailData = soundtrack.thumbnailData,
                       let image = UIImage(data: thumbnailData) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 40, height: 40)
                            .cornerRadius(8)
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.purple.opacity(0.1))
                                .frame(width: 40, height: 40)
                            Image(systemName: "music.note")
                                .foregroundColor(.purple)
                                .font(.system(size: 16))
                        }
                    }
                    
                    // タイトル
                    VStack(alignment: .leading, spacing: 2) {
                        Text(soundtrack.title)
                            .font(.system(size: 14, weight: .medium))
                            .lineLimit(1)
                        
                        if let artist = soundtrack.artist {
                            Text(artist)
                                .font(.system(size: 12))
                                .foregroundColor(.gray)
                                .lineLimit(1)
                        }
                    }
                    
                    Spacer()
                    
                    // コントロールボタン
                    Button(action: {
                        if manager.isPlaying {
                            manager.pausePlayback()
                        } else {
                            manager.resumePlayback()
                        }
                    }) {
                        Image(systemName: manager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(.purple)
                    }
                    
                    Button(action: {
                        manager.startRandomPlayback()
                    }) {
                        Image(systemName: "forward.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.purple)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white)
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                .onTapGesture {
                    // バー全体をタップした時も曲を変更
                    manager.startRandomPlayback()
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: manager.isPlaying)
        }
    }
}