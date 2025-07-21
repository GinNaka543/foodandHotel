import SwiftUI
import AVKit
import AVFoundation
import UIKit

struct VideoPlayerScreen: View {
    let video: MemoryVideo
    let character: Character?
    let anime: Anime?
    let allVideos: [MemoryVideo]
    var onSave: ((String, [String]) -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onThumbnailUpdate: ((Data?) -> Void)? = nil
    @Environment(\.presentationMode) var presentationMode
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var showControls = true
    @State private var selectedVideo: MemoryVideo?
    @State private var hideControlsWorkItem: DispatchWorkItem?
    @State private var showMenuSheet = false
    @State private var editTitle: String = ""
    @State private var editTags: String = ""
    @State private var showDeleteAlert = false
    @State private var showFullscreen = false
    @State private var showExpandButton = false
    @State private var showThumbnailPicker = false
    // フルスクリーン用
    @State private var fullscreenShowControls = true
    @State private var fullscreenPlayer: AVPlayer? = nil
    // YouTube動画確認用
    @State private var activeSheet: ActiveSheet? = nil
    @State private var editText = ""
    
    enum ActiveSheet: Identifiable {
        case youtubeConfirmation(MemoryVideo)
        case editTitle(MemoryVideo)
        case editTags(MemoryVideo)
        case thumbnailPicker(MemoryVideo)
        
        var id: String {
            switch self {
            case .youtubeConfirmation: return "youtubeConfirmation"
            case .editTitle: return "editTitle"
            case .editTags: return "editTags"
            case .thumbnailPicker: return "thumbnailPicker"
            }
        }
    }
    
    @ViewBuilder
    var body: some View {
        Group {
            // YouTube動画の場合は、YouTubeアプリで開く
            if let youtubeURL = video.youtubeURL, !youtubeURL.isEmpty {
                YouTubeVideoView(
                    video: video,
                    openYouTubeVideo: openYouTubeVideo,
                    dismiss: { presentationMode.wrappedValue.dismiss() }
                )
            } else {
            // 通常の動画プレイヤー
            GeometryReader { geometry in
                ZStack(alignment: .bottomTrailing) {
                    ScrollView {
                        VStack(spacing: 0) {
                            // 動画プレイヤー部分
                            if let player = player {
                                VideoPlayer(player: player)
                                    .frame(width: geometry.size.width, height: geometry.size.width * 9.0 / 16.0)
                                    .background(Color.black)
                                    .onAppear {
                                        print("VideoPlayer表示されました")
                                        print("Player: \(player)")
                                        print("CurrentItem: \(String(describing: player.currentItem))")
                                        print("Rate: \(player.rate)")
                                        print("Status: \(player.status.rawValue)")
                                    }
                            } else {
                                Rectangle()
                                    .fill(Color.black)
                                    .frame(width: geometry.size.width, height: geometry.size.width * 9.0 / 16.0)
                                    .overlay(
                                        Text("プレイヤーを初期化中...")
                                            .foregroundColor(.white)
                                    )
                            }
                            
                            // --- 動画情報・関連動画 ---
                            VStack(alignment: .leading, spacing: 12) {
                                VideoInfoView(
                                    video: video,
                                    showMenuSheet: { showMenuSheet = true },
                                    showFullscreen: { showFullscreen = true }
                                )
                                
                                // 関連動画
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("関連動画")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 16)
                                    LazyVStack(spacing: 0) {
                                        Spacer().frame(height: 5)
                                        ForEach(Array(allVideos.filter { $0.id != video.id }.enumerated()), id: \.element.id) { idx, relatedVideo in
                                            if idx > 0 {
                                                Spacer().frame(height: 15.9)
                                            }
                                            Button(action: {
                                                selectedVideo = relatedVideo
                                            }) {
                                                HStack(alignment: .top, spacing: 8) {
                                                    // サムネイル
                                                    if let thumbnailData = relatedVideo.thumbnailData, let uiImage = UIImage(data: thumbnailData) {
                                                        Image(uiImage: uiImage)
                                                            .resizable()
                                                            .scaledToFill()
                                                            .frame(width: 165, height: 90)
                                                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                                            .clipped()
                                                    } else if let youtubeThumbnailURL = relatedVideo.youtubeThumbnailURL {
                                                        AsyncImage(url: URL(string: youtubeThumbnailURL)) { image in
                                                            image
                                                                .resizable()
                                                                .scaledToFill()
                                                                .frame(width: 165, height: 90)
                                                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                                                .clipped()
                                                        } placeholder: {
                                                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                                .fill(Color.gray.opacity(0.3))
                                                                .frame(width: 165, height: 90)
                                                                .overlay(ProgressView())
                                                        }
                                                    } else {
                                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                            .fill(Color.gray.opacity(0.3))
                                                            .frame(width: 165, height: 90)
                                                    }
                                                    
                                                    // タイトルとタグ
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text(relatedVideo.title)
                                                            .font(.system(size: 16.5, weight: .semibold))
                                                            .foregroundColor(.black)
                                                            .padding(.vertical, 4)
                                                        
                                                        // ハッシュタグ
                                                        if let firstTag = relatedVideo.tags.first {
                                                            Text("#\(firstTag)")
                                                                .font(.system(size: 12, weight: .regular))
                                                                .foregroundColor(.gray)
                                                        }
                                                        
                                                        Text("\(formatViewCount(relatedVideo.viewCount ?? 0))回・\(timeAgo(from: relatedVideo.date))")
                                                            .font(.system(size: 13.8, weight: .regular))
                                                            .foregroundColor(.gray)
                                                            .padding(.vertical, 1)
                                                    }
                                                    .frame(alignment: .leading)
                                                    .padding(.top, 3)
                                                    .padding(.leading, 8)
                                                    
                                                    Spacer()
                                                }
                                                .padding(.leading, 8)
                                            }
                                            .buttonStyle(PlainButtonStyle())
                                        }
                                    }
                                    .padding(.bottom, 100) // 戻るボタンのためのスペースを確保
                                }
                            }
                        }
                    }
                    
                    // 画面全体の右下に戻るボタン（固定位置）
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button(action: {
                                presentationMode.wrappedValue.dismiss()
                            }) {
                                Text("戻る")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 24)
                                    .padding(.vertical, 12)
                                    .background(Color.black.opacity(0.8))
                                    .cornerRadius(20)
                            }
                            .padding(.trailing, 24)
                            .padding(.bottom, 24)
                        }
                    }
                }
                // フルスクリーンView
                .fullScreenCover(isPresented: $showFullscreen) {
                    FullScreenVideoPlayer(player: player, onDismiss: { showFullscreen = false })
                }
            }
        }
        }
        .navigationBarHidden(true)
        .onAppear {
            print("VideoPlayerScreen onAppear - video path: \(video.videoPath)")
            print("VideoPlayerScreen onAppear - youtube URL: \(video.youtubeURL ?? "nil")")
            setupPlayer()
            editTitle = video.title
            editTags = video.tags.joined(separator: ",")
            // 少し遅延を入れてから再生
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let player = self.player {
                    player.play()
                    print("動画を再生開始しました - rate: \(player.rate)")
                    print("プレイヤーステータス: \(player.status.rawValue)")
                    if let currentItem = player.currentItem {
                        print("現在のアイテムステータス: \(currentItem.status.rawValue)")
                    }
                } else {
                    print("プレイヤーがnilのため再生できません")
                }
            }
            isPlaying = true
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
        .onChange(of: selectedVideo) { newVideo in
            if let newVideo = newVideo {
                handleVideoSelection(newVideo)
            }
        }
        // --- 編集・削除用シート ---
        .sheet(isPresented: $showMenuSheet) {
            VStack(spacing: 24) {
                Text("動画の編集")
                    .font(.headline)
                TextField("タイトル", text: $editTitle)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("タグ（カンマ区切り）", text: $editTags)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                Button("タイトル・タグを保存") {
                    let tagsArray = editTags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    onSave?(editTitle, tagsArray)
                    showMenuSheet = false
                }
                .font(.headline)
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                Button("サムネイルを変更") {
                    showMenuSheet = false
                    // 少し遅延させてからサムネイルピッカーを表示
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        showThumbnailPicker = true
                    }
                }
                .font(.headline)
                .padding()
                .background(Color.green)
                .foregroundColor(.white)
                .cornerRadius(10)
                Button("動画を削除") {
                    print("[DEBUG] 動画を削除ボタンが押されました")
                    showDeleteAlert = true
                }
                .foregroundColor(.red)
                Button("キャンセル") {
                    showMenuSheet = false
                }
            }
            .padding(32)
            .alert(isPresented: $showDeleteAlert) {
                Alert(
                    title: Text("本当に削除しますか？"),
                    message: Text("この動画は完全に削除されます。"),
                    primaryButton: .destructive(Text("削除")) {
                        print("[DEBUG] VideoPlayerScreen: Alertの削除ボタンが押されました")
                        print("[DEBUG] VideoPlayerScreen: onDeleteクロージャを呼び出します")
                        onDelete?()
                        print("[DEBUG] VideoPlayerScreen: onDeleteクロージャ呼び出し完了")
                        showMenuSheet = false
                        print("[DEBUG] VideoPlayerScreen: showMenuSheet = \(showMenuSheet)")
                        presentationMode.wrappedValue.dismiss()
                        print("[DEBUG] VideoPlayerScreen: presentationModeで画面を閉じました")
                    },
                    secondaryButton: .cancel(Text("キャンセル"))
                )
            }
        }
        .sheet(isPresented: $showThumbnailPicker) {
            ThumbnailPickerView(
                video: video,
                onSave: { newThumbnailData in
                    onThumbnailUpdate?(newThumbnailData)
                    showThumbnailPicker = false
                },
                onCancel: {
                    showThumbnailPicker = false
                }
            )
        }
        .sheet(item: $activeSheet) { sheet in
            Group {
                switch sheet {
                case .youtubeConfirmation(let video):
                    youtubeConfirmationSheet(video: video)
                case .editTitle(let video):
                    editTitleSheet(video: video)
                case .editTags(let video):
                    editTagsSheet(video: video)
                case .thumbnailPicker(let video):
                    ThumbnailPickerView(
                        video: video,
                        onSave: { newThumbnailData in
                            onThumbnailUpdate?(newThumbnailData)
                            activeSheet = nil
                        },
                        onCancel: {
                            activeSheet = nil
                        }
                    )
                }
            }
        }
    }
}

// MARK: - VideoPlayerScreen Extension
extension VideoPlayerScreen {
    // View count formatter
    func formatViewCount(_ count: Int) -> String {
        if count >= 10000 {
            let formatted = Double(count) / 10000.0
            return String(format: "%.1f万", formatted)
        } else {
            return "\(count)"
        }
    }
    
    // Time ago formatter
    func timeAgo(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date, to: now)
        
        if let years = components.year, years > 0 {
            return "\(years)年前"
        } else if let months = components.month, months > 0 {
            return "\(months)ヶ月前"
        } else if let days = components.day, days > 0 {
            return "\(days)日前"
        } else if let hours = components.hour, hours > 0 {
            return "\(hours)時間前"
        } else if let minutes = components.minute, minutes > 0 {
            return "\(minutes)分前"
        } else {
            return "たった今"
        }
    }
    
    func setupPlayer() {
        // YouTube動画の場合はプレイヤーを設定しない
        if video.youtubeURL != nil && !video.youtubeURL!.isEmpty {
            return
        }
        
        guard let videoURL = loadVideoURLFromPath(video.videoPath) else {
            print("動画ファイルが見つかりません: \(video.videoPath)")
            return
        }
        
        print("動画URLを生成しました: \(videoURL)")
        print("動画パス: \(videoURL.path)")
        print("動画URLの存在確認: \(FileManager.default.fileExists(atPath: videoURL.path))")
        
        // ファイルが存在しない場合、追加のチェック
        if !FileManager.default.fileExists(atPath: videoURL.path) {
            print("警告: ファイルが存在しません。パスを確認してください。")
            // ドキュメントディレクトリの内容を確認
            if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                do {
                    let contents = try FileManager.default.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
                    print("ドキュメントディレクトリの内容:")
                    for url in contents {
                        print("  - \(url.lastPathComponent)")
                    }
                } catch {
                    print("ディレクトリ内容の取得エラー: \(error)")
                }
            }
        }
        
        // AVPlayerを作成する前にAVAudioSessionを設定
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
            print("AVAudioSessionを設定しました")
        } catch {
            print("AVAudioSessionの設定に失敗: \(error)")
        }
        
        // AVPlayerItemを作成
        let playerItem = AVPlayerItem(url: videoURL)
        
        // 新しいプレイヤーを作成
        let newPlayer = AVPlayer(playerItem: playerItem)
        print("AVPlayerを作成しました")
        
        // メインスレッドでプレイヤーを設定
        DispatchQueue.main.async {
            self.player = newPlayer
            print("プレイヤーを設定しました")
            
            // プレイヤーの準備状態を確認
            print("現在のアイテムステータス: \(playerItem.status.rawValue)")
            if let error = playerItem.error {
                print("プレイヤーアイテムエラー: \(error)")
            }
            
            // アセットのプロパティをロード
            let asset = playerItem.asset
            Task {
                do {
                    let isPlayable = try await asset.load(.isPlayable)
                    print("動画は再生可能か: \(isPlayable)")
                } catch {
                    print("再生可能性の確認エラー: \(error)")
                }
            }
        }
        
        // 動画の長さを取得
        let asset = AVURLAsset(url: videoURL)
        Task {
            do {
                let tracks = try await asset.loadTracks(withMediaType: .video)
                if let firstTrack = tracks.first {
                    let timeRange = try await firstTrack.load(.timeRange)
                    await MainActor.run {
                        duration = CMTimeGetSeconds(timeRange.duration)
                    }
                }
            } catch {
                print("Failed to load video duration: \(error)")
            }
        }
        
        // 再生状態の監視
        player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { time in
            currentTime = CMTimeGetSeconds(time)
        }
    }
    
    func openYouTubeVideo(url: String) {
        print("YouTube動画を開こうとしています: \(url)")
        if let youtubeURL = URL(string: url) {
            print("URL変換成功: \(youtubeURL)")
            UIApplication.shared.open(youtubeURL) { success in
                print("YouTube動画を開く結果: \(success)")
            }
        } else {
            print("URL変換失敗: \(url)")
        }
    }

    func resetHideControlsTimer() {
        hideControlsWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            withAnimation {
                showControls = false
            }
        }
        hideControlsWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: workItem)
    }
    
    func handleVideoSelection(_ newVideo: MemoryVideo) {
        print("動画が選択されました: \(newVideo.title)")
        
        // YouTubeの動画の場合は確認ページに移動
        if let youtubeURL = newVideo.youtubeURL, !youtubeURL.isEmpty {
            print("YouTube動画です: \(youtubeURL)")
            // YouTube動画の確認ページを表示
            showYouTubeConfirmation(for: youtubeURL, title: newVideo.title)
        } else {
            print("自分でアップロードした動画です: \(newVideo.videoPath)")
            // 自分でアップロードした動画の場合は動画プレイヤーを切り替え
            switchToVideo(newVideo)
        }
        
        // 選択状態をリセット
        selectedVideo = nil
    }
    
    func showYouTubeConfirmation(for url: String, title: String) {
        print("YouTube確認ダイアログを表示します: \(title)")
        if let youtubeVideo = allVideos.first(where: { $0.youtubeURL == url }) {
            activeSheet = .youtubeConfirmation(youtubeVideo)
        }
    }
    
    func switchToVideo(_ newVideo: MemoryVideo) {
        // 現在の動画を停止
        player?.pause()
        player = nil
        
        // 新しい動画のプレイヤーを設定
        if let videoURL = loadVideoURLFromPath(newVideo.videoPath) {
            let newPlayer = AVPlayer(url: videoURL)
            player = newPlayer
            
            // 動画の長さを取得
            let asset = AVURLAsset(url: videoURL)
            Task {
                do {
                    let duration = try await asset.load(.duration)
                    await MainActor.run {
                        self.duration = CMTimeGetSeconds(duration)
                        self.currentTime = 0
                    }
                } catch {
                    print("動画の長さの取得に失敗しました: \(error)")
                }
            }
            
            // 動画を再生
            newPlayer.play()
            isPlaying = true
            
            // タイトルとタグを更新
            editTitle = newVideo.title
            editTags = newVideo.tags.joined(separator: ",")
            
            print("動画を切り替えました: \(newVideo.title)")
        } else {
            print("動画ファイルの読み込みに失敗しました: \(newVideo.videoPath)")
        }
    }
    
    // YouTube確認ページ
    @ViewBuilder
    func youtubeConfirmationSheet(video: MemoryVideo) -> some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 20) {
                // サムネイル
                if let thumbnailData = video.thumbnailData, let uiImage = UIImage(data: thumbnailData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity, maxHeight: 300)
                        .cornerRadius(12)
                } else if let thumbnailURL = video.youtubeThumbnailURL {
                    AsyncImage(url: URL(string: thumbnailURL)) { image in
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: 300)
                            .cornerRadius(12)
                    } placeholder: {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 200)
                            .overlay(ProgressView())
                    }
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 200)
                }
                
                Text(video.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button(action: {
                    if let youtubeURL = video.youtubeURL, let url = URL(string: youtubeURL) {
                        UIApplication.shared.open(url)
                    }
                    activeSheet = nil
                }) {
                    HStack {
                        Image(systemName: "play.circle.fill")
                            .font(.title)
                        Text("YouTubeで開く")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.red)
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                Button(action: {
                    activeSheet = nil
                }) {
                    Text("閉じる")
                        .foregroundColor(.gray)
                        .padding()
                }
            }
            
            Spacer()
        }
        .background(Color(.systemBackground))
    }
    
    // タイトル編集シート
    @ViewBuilder
    func editTitleSheet(video: MemoryVideo) -> some View {
        VStack(spacing: 24) {
            Text("タイトルを編集")
                .font(.headline)
                .padding(.top, 24)
            
            TextField("タイトル", text: $editText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.system(size: 18))
                .padding(.horizontal, 24)
            
            HStack(spacing: 24) {
                Button(action: {
                    activeSheet = nil
                }) {
                    Text("キャンセル")
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
                
                Button(action: {
                    let tags = video.tags
                    onSave?(editText, tags)
                    activeSheet = nil
                }) {
                    Text("保存")
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.black)
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Color.white)
        .cornerRadius(20)
        .shadow(radius: 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.3))
        .edgesIgnoringSafeArea(.all)
    }
    
    // タグ編集シート
    @ViewBuilder
    func editTagsSheet(video: MemoryVideo) -> some View {
        VStack(spacing: 24) {
            Text("タグを編集")
                .font(.headline)
                .padding(.top, 24)
            
            TextField("タグ（カンマ区切り）", text: $editText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.system(size: 18))
                .padding(.horizontal, 24)
            
            HStack(spacing: 24) {
                Button(action: {
                    activeSheet = nil
                }) {
                    Text("キャンセル")
                        .foregroundColor(.red)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                }
                
                Button(action: {
                    let title = video.title
                    let tags = editText.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                    onSave?(title, tags)
                    activeSheet = nil
                }) {
                    Text("保存")
                        .foregroundColor(.white)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.black)
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
        }
        .background(Color.white)
        .cornerRadius(20)
        .shadow(radius: 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.3))
        .edgesIgnoringSafeArea(.all)
    }
    
    func loadVideoURLFromPath(_ path: String) -> URL? {
        if path.hasPrefix("http") {
            return URL(string: path)
        } else if path.hasPrefix("/") {
            // 絶対パスの場合
            return URL(fileURLWithPath: path)
        } else {
            // 相対パスの場合、ドキュメントディレクトリからの相対パスと仮定
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let fullURL = documentsDirectory.appendingPathComponent(path)
            print("相対パスを絶対パスに変換: \(path) → \(fullURL.path)")
            return fullURL
        }
    }
}

// MARK: - VideoInfoView
private struct VideoInfoView: View {
    let video: MemoryVideo
    let showMenuSheet: () -> Void
    let showFullscreen: () -> Void
    
    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text(video.title)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.black)
                    .lineLimit(2)
                Text("#" + (video.tags.isEmpty ? "nakajimaginsei" : video.tags.joined(separator: " #")))
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            Spacer(minLength: 8)
            Button(action: showMenuSheet) {
                Text("編集")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 16)
                    .background(Color.black)
                    .cornerRadius(8)
            }
            .padding(.trailing, 4)
            Button(action: showFullscreen) {
                Image(systemName: "arrow.up.left.and.arrow.down.right.square")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.black.opacity(0.7))
                    .clipShape(Circle())
            }
            .padding(.trailing, 8)
        }
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }
}

// MARK: - YouTubeVideoView
private struct YouTubeVideoView: View {
    let video: MemoryVideo
    let openYouTubeVideo: (String) -> Void
    let dismiss: () -> Void
    
    var body: some View {
        VStack {
            Spacer()
            VStack(spacing: 20) {
                // Thumbnail
                thumbnailView
                
                Text(video.title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button(action: {
                    if let url = video.youtubeURL {
                        openYouTubeVideo(url)
                    }
                }) {
                    HStack {
                        Image(systemName: "play.circle.fill")
                            .font(.title)
                        Text("YouTubeで開く")
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.red)
                    .cornerRadius(12)
                    .padding(.horizontal)
                }
                
                Button(action: dismiss) {
                    Text("閉じる")
                        .foregroundColor(.gray)
                        .padding()
                }
            }
            Spacer()
        }
        .background(Color(.systemBackground))
    }
    
    @ViewBuilder
    private var thumbnailView: some View {
        if let thumbnailData = video.thumbnailData, let uiImage = UIImage(data: thumbnailData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: .infinity, maxHeight: 300)
                .cornerRadius(12)
        } else if let thumbnailURL = video.youtubeThumbnailURL {
            AsyncImage(url: URL(string: thumbnailURL)) { image in
                image
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 300)
                    .cornerRadius(12)
            } placeholder: {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 200)
                    .overlay(ProgressView())
            }
        } else {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.3))
                .frame(height: 200)
        }
    }
}

// フルスクリーン用のViewを追加
struct FullScreenVideoPlayer: View {
    var player: AVPlayer?
    var onDismiss: () -> Void
    @State private var showControls = true
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()
            VideoPlayer(player: player)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    withAnimation { showControls.toggle() }
                }
            if showControls {
                Button(action: { onDismiss() }) {
                    Text("戻る")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(20)
                }
                .padding(.trailing, 24)
                .padding(.top, 24)
            }
        }
    }
} 
