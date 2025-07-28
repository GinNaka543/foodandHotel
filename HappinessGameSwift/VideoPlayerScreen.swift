import SwiftUI
import AVKit
import AVFoundation
import UIKit

struct VideoPlayerScreen: View {
    @State private var video: MemoryVideo
    let character: Character?
    let anime: Anime?
    let allVideos: [MemoryVideo]
    var onSave: ((String, [String]) -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onThumbnailUpdate: ((Data?) -> Void)? = nil
    @Environment(\.presentationMode) var presentationMode
    @State private var searchText = ""
    @State private var filteredVideos: [MemoryVideo] = []
    @State private var showSearchBar = false
    
    init(video: MemoryVideo, character: Character?, anime: Anime?, allVideos: [MemoryVideo], onSave: ((String, [String]) -> Void)? = nil, onDelete: (() -> Void)? = nil, onThumbnailUpdate: ((Data?) -> Void)? = nil) {
        self._video = State(initialValue: video)
        self.character = character
        self.anime = anime
        self.allVideos = allVideos
        self.onSave = onSave
        self.onDelete = onDelete
        self.onThumbnailUpdate = onThumbnailUpdate
    }
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
    @State private var shouldScrollToPlayer = false
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
                normalVideoPlayer
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            filteredVideos = allVideos
            setupPlayer()
            editTitle = video.title
            editTags = video.tags.joined(separator: ",")
            // 少し遅延を入れてから再生
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if let player = self.player {
                    player.play()
                } else {
                }
            }
            isPlaying = true
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
        .onChange(of: selectedVideo) { oldValue, newValue in
            if let newVideo = newValue {
                handleVideoSelection(newVideo)
            }
        }
        // --- 編集・削除用シート ---
        .sheet(isPresented: $showMenuSheet) {
            menuSheet
        }
        .sheet(isPresented: $showThumbnailPicker) {
            ThumbnailPickerView(
                video: video,
                onSave: { newThumbnailData in
                    // ローカルのvideoも更新
                    video.thumbnailData = newThumbnailData
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
                case .editTitle(_):
                    editTitleSheet()
                case .editTags(_):
                    editTagsSheet()
                case .thumbnailPicker(let video):
                    ThumbnailPickerView(
                        video: video,
                        onSave: { newThumbnailData in
                            // ローカルのvideoも更新
                            self.video.thumbnailData = newThumbnailData
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
    
    @ViewBuilder
    private var normalVideoPlayer: some View {
        // 通常の動画プレイヤー
        GeometryReader { geometry in
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    // ヘッダー
                    HStack(spacing: 12) {
                        // White logo（左端に配置）
                        if let logoImage = UIImage(named: "whitelogo") {
                            Image(uiImage: logoImage)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(height: 38)
                        }
                        
                        Spacer()
                        
                        // 検索バー（表示時）
                        if showSearchBar {
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.gray)
                                    .font(.system(size: 14))
                                TextField(NSLocalizedString("search", comment: "Search"), text: $searchText)
                                    .foregroundColor(.white)
                                    .accentColor(.white)
                                    .onChange(of: searchText) { _ in
                                        filterVideos()
                                    }
                                if !searchText.isEmpty {
                                    Button(action: {
                                        searchText = ""
                                        filterVideos()
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.gray)
                                            .font(.system(size: 14))
                                    }
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(20)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                            .frame(maxWidth: 250)
                        }
                        
                        // 虫眼鏡アイコン
                        if !showSearchBar {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showSearchBar.toggle()
                                }
                            }) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.white)
                                    .font(.system(size: 20))
                                    .padding(8)
                                    .background(Color.white.opacity(0.2))
                                    .clipShape(Circle())
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
                    .background(Color.black)
                    
                    ScrollViewReader { scrollProxy in
                        ScrollView {
                            VStack(spacing: 0) {
                                // 動画プレイヤー部分
                            if let player = player {
                            VideoPlayer(player: player)
                                .frame(width: geometry.size.width, height: geometry.size.width * 9.0 / 16.0)
                                .background(Color.black)
                                .onAppear {
                                }
                                .id("player")
                        } else {
                            Rectangle()
                                .fill(Color.black)
                                .frame(width: geometry.size.width, height: geometry.size.width * 9.0 / 16.0)
                                .id("player")
                                .overlay(
                                    Text(NSLocalizedString("initializing_player", comment: "Initializing player..."))
                                        .foregroundColor(.white)
                                )
                        }
                        
                        // --- 動画情報・関連動画 ---
                        VStack(alignment: .leading, spacing: 0) {
                            VideoInfoView(
                                video: video,
                                character: character,
                                anime: anime,
                                showMenuSheet: { showMenuSheet = true },
                                showFullscreen: { showFullscreen = true },
                                allVideos: allVideos
                            )
                            .padding(.bottom, 16)
                            
                            // 関連動画
                            VStack(alignment: .leading, spacing: 16) {
                                Text(NSLocalizedString("related_videos", comment: "Related videos"))
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 16)
                                LazyVStack(spacing: 0) {
                                    Spacer().frame(height: 5)
                                    ForEach(Array(getRelatedVideos().enumerated()), id: \.element.id) { idx, relatedVideo in
                                        if idx > 0 {
                                            Spacer().frame(height: 15.9)
                                        }
                                        Button(action: {
                                            selectedVideo = relatedVideo
                                        }) {
                                            VStack(alignment: .leading, spacing: 8) {
                                                // サムネイル
                                                if let thumbnailData = relatedVideo.thumbnailData, let uiImage = UIImage(data: thumbnailData) {
                                                    Image(uiImage: uiImage)
                                                        .resizable()
                                                        .scaledToFill()
                                                        .frame(width: UIScreen.main.bounds.width, height: UIDevice.current.userInterfaceIdiom == .pad ? 400 : 200)
                                                        .clipped()
                                                } else if let youtubeThumbnailURL = relatedVideo.youtubeThumbnailURL {
                                                    AsyncImage(url: URL(string: youtubeThumbnailURL)) { image in
                                                        image
                                                            .resizable()
                                                            .scaledToFill()
                                                            .frame(width: UIScreen.main.bounds.width, height: UIDevice.current.userInterfaceIdiom == .pad ? 400 : 200)
                                                            .clipped()
                                                    } placeholder: {
                                                        Rectangle()
                                                            .fill(Color.gray.opacity(0.3))
                                                            .frame(width: UIScreen.main.bounds.width, height: UIDevice.current.userInterfaceIdiom == .pad ? 400 : 200)
                                                            .overlay(ProgressView())
                                                    }
                                                } else {
                                                    Rectangle()
                                                        .fill(Color.gray.opacity(0.3))
                                                        .frame(width: UIScreen.main.bounds.width, height: UIDevice.current.userInterfaceIdiom == .pad ? 400 : 200)
                                                }
                                                
                                                // アイコンとタイトル・タグ
                                                HStack(alignment: .top, spacing: 12) {
                                                    // Character or Anime icon
                                                    if let character = character, let imageIdentifier = character.imageIdentifier,
                                                       let uiImage = loadImageFromPath(imageIdentifier) {
                                                        Image(uiImage: uiImage)
                                                            .resizable()
                                                            .scaledToFill()
                                                            .frame(width: 43, height: 43)
                                                            .clipShape(Circle())
                                                    } else if let anime = anime, let imageIdentifier = anime.imageIdentifier,
                                                              let uiImage = loadImageFromPath(imageIdentifier) {
                                                        Image(uiImage: uiImage)
                                                            .resizable()
                                                            .scaledToFill()
                                                            .frame(width: 43, height: 43)
                                                            .clipShape(Circle())
                                                    } else {
                                                        Circle()
                                                            .fill(Color.gray.opacity(0.3))
                                                            .frame(width: 43, height: 43)
                                                    }
                                                    
                                                    VStack(alignment: .leading, spacing: 2) {
                                                        Text(relatedVideo.title)
                                                            .font(.system(size: 16.5, weight: .semibold))
                                                            .foregroundColor(.black)
                                                            .lineLimit(2)
                                                        
                                                        Text(character?.name ?? anime?.title ?? NSLocalizedString("app_name", comment: "ANICOLLE"))
                                                            .font(.system(size: 12))
                                                            .foregroundColor(.gray)
                                                        
                                                        Text(String(format: NSLocalizedString("view_count_time_ago", comment: "%@ views • %@"), formatViewCount(relatedVideo.viewCount ?? 0), timeAgo(from: relatedVideo.date)))
                                                            .font(.system(size: 12))
                                                            .foregroundColor(.gray)
                                                    }
                                                    
                                                    Spacer()
                                                }
                                                .padding(.horizontal, 16)
                                            }
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                                .padding(.bottom, 100) // 戻るボタンのためのスペースを確保
                            }
                        }
                    }
                }
                .onChange(of: shouldScrollToPlayer) { shouldScroll in
                    if shouldScroll {
                        withAnimation(.easeInOut(duration: 0.5)) {
                            scrollProxy.scrollTo("player", anchor: .top)
                        }
                        shouldScrollToPlayer = false
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
                            Text(NSLocalizedString("back", comment: "Back"))
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
    
    @ViewBuilder
    private var menuSheet: some View {
        VStack(spacing: 24) {
            Text(NSLocalizedString("edit_video", comment: "Edit video"))
                .font(.headline)
            TextField(NSLocalizedString("title", comment: "Title"), text: $editTitle)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            TextField(NSLocalizedString("tags_comma_separated", comment: "Tags (comma separated)"), text: $editTags)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            Button(NSLocalizedString("save_title_tags", comment: "Save title and tags")) {
                let tagsArray = editTags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                // ローカルのvideoも更新
                video.title = editTitle
                video.tags = tagsArray
                onSave?(editTitle, tagsArray)
                showMenuSheet = false
            }
            .font(.headline)
            .padding()
            .background(Color.blue)
            .foregroundColor(.white)
            .cornerRadius(10)
            Button(NSLocalizedString("change_thumbnail", comment: "Change thumbnail")) {
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
            Button(NSLocalizedString("delete_video", comment: "Delete video")) {
                showDeleteAlert = true
            }
            .foregroundColor(.red)
            Button(NSLocalizedString("cancel", comment: "Cancel")) {
                showMenuSheet = false
            }
        }
        .padding(32)
        .alert(isPresented: $showDeleteAlert) {
            Alert(
                title: Text(NSLocalizedString("really_delete", comment: "Really delete?")),
                message: Text(NSLocalizedString("delete_video_confirm_message", comment: "This video will be permanently deleted.")),
                primaryButton: .destructive(Text(NSLocalizedString("delete", comment: "Delete"))) {
                    onDelete?()
                    showMenuSheet = false
                    presentationMode.wrappedValue.dismiss()
                },
                secondaryButton: .cancel(Text(NSLocalizedString("cancel", comment: "Cancel")))
            )
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
            return String(format: NSLocalizedString("years_ago", comment: "%d years ago"), years)
        } else if let months = components.month, months > 0 {
            return String(format: NSLocalizedString("months_ago", comment: "%d months ago"), months)
        } else if let days = components.day, days > 0 {
            return String(format: NSLocalizedString("days_ago", comment: "%d days ago"), days)
        } else if let hours = components.hour, hours > 0 {
            return String(format: NSLocalizedString("hours_ago", comment: "%d hours ago"), hours)
        } else if let minutes = components.minute, minutes > 0 {
            return String(format: NSLocalizedString("minutes_ago", comment: "%d minutes ago"), minutes)
        } else {
            return NSLocalizedString("just_now", comment: "Just now")
        }
    }
    
    func setupPlayer() {
        // YouTube動画の場合はプレイヤーを設定しない
        if let youtubeURL = video.youtubeURL, !youtubeURL.isEmpty {
            return
        }
        
        guard let videoURL = loadVideoURLFromPath(video.videoPath) else {
            return
        }
        
        
        // ファイルが存在しない場合、追加のチェック
        if !FileManager.default.fileExists(atPath: videoURL.path) {
            // ドキュメントディレクトリの内容を確認
            if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                do {
                    let contents = try FileManager.default.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
                    for _ in contents {
                    }
                } catch {
                }
            }
        }
        
        // AVPlayerを作成する前にAVAudioSessionを設定
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
        }
        
        // AVPlayerItemを作成
        let playerItem = AVPlayerItem(url: videoURL)
        
        // 新しいプレイヤーを作成
        let newPlayer = AVPlayer(playerItem: playerItem)
        
        // メインスレッドでプレイヤーを設定
        DispatchQueue.main.async {
            self.player = newPlayer
            
            // プレイヤーの準備状態を確認
            if playerItem.error != nil {
            }
            
            // アセットのプロパティをロード
            let asset = playerItem.asset
            Task {
                do {
                    let _ = try await asset.load(.isPlayable)
                } catch {
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
            }
        }
        
        // 再生状態の監視
        player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { time in
            currentTime = CMTimeGetSeconds(time)
        }
    }
    
    func openYouTubeVideo(url: String) {
        if let youtubeURL = URL(string: url) {
            UIApplication.shared.open(youtubeURL) { success in
            }
        } else {
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
        
        // YouTubeの動画の場合は確認ページに移動
        if let youtubeURL = newVideo.youtubeURL, !youtubeURL.isEmpty {
            // YouTube動画の確認ページを表示
            showYouTubeConfirmation(for: youtubeURL, title: newVideo.title)
        } else {
            // 自分でアップロードした動画の場合は動画プレイヤーを切り替え
            switchToVideo(newVideo)
        }
        
        // 選択状態をリセット
        selectedVideo = nil
    }
    
    func showYouTubeConfirmation(for url: String, title: String) {
        if let youtubeVideo = allVideos.first(where: { $0.youtubeURL == url }) {
            activeSheet = .youtubeConfirmation(youtubeVideo)
        }
    }
    
    func switchToVideo(_ newVideo: MemoryVideo) {
        // 現在の動画を停止
        player?.pause()
        player = nil
        
        // プレイヤーまでスクロール
        shouldScrollToPlayer = true
        
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
                }
            }
            
            // 動画を再生
            newPlayer.play()
            isPlaying = true
            
            // タイトルとタグを更新
            editTitle = newVideo.title
            editTags = newVideo.tags.joined(separator: ",")
            
        } else {
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
                        Text(NSLocalizedString("open_in_youtube", comment: "Open in YouTube"))
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
                    Text(NSLocalizedString("close", comment: "Close"))
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
    func editTitleSheet() -> some View {
        VStack(spacing: 24) {
            Text(NSLocalizedString("edit_title", comment: "Edit title"))
                .font(.headline)
                .padding(.top, 24)
            
            TextField(NSLocalizedString("title", comment: "Title"), text: $editText)
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
                    // ローカルのvideoも更新
                    video.title = editText
                    onSave?(editText, tags)
                    activeSheet = nil
                }) {
                    Text(NSLocalizedString("save", comment: "Save"))
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
    func editTagsSheet() -> some View {
        VStack(spacing: 24) {
            Text(NSLocalizedString("edit_tags", comment: "Edit tags"))
                .font(.headline)
                .padding(.top, 24)
            
            TextField(NSLocalizedString("tags_comma_separated", comment: "Tags (comma separated)"), text: $editText)
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
                    // ローカルのvideoも更新
                    video.tags = tags
                    onSave?(title, tags)
                    activeSheet = nil
                }) {
                    Text(NSLocalizedString("save", comment: "Save"))
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
            guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                return nil
            }
            let fullURL = documentsDirectory.appendingPathComponent(path)
            return fullURL
        }
    }
    
    private func filterVideos() {
        if searchText.isEmpty {
            filteredVideos = allVideos
        } else {
            filteredVideos = allVideos.filter { video in
                video.title.localizedCaseInsensitiveContains(searchText) ||
                video.tags.contains { tag in
                    tag.localizedCaseInsensitiveContains(searchText)
                }
            }
        }
    }
    
    private func getRelatedVideos() -> [MemoryVideo] {
        let videos = searchText.isEmpty ? allVideos : filteredVideos
        return videos.filter { $0.id != video.id }
    }
}

// MARK: - VideoInfoView
private struct VideoInfoView: View {
    let video: MemoryVideo
    let character: Character?
    let anime: Anime?
    let showMenuSheet: () -> Void
    let showFullscreen: () -> Void
    let allVideos: [MemoryVideo]
    @State private var isLiked = false
    @State private var likeCount = 0
    
    // 総動画再生数を計算
    private var totalViewCount: Int {
        allVideos.reduce(0) { sum, video in
            sum + (video.viewCount ?? 0)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Title and view info
            VStack(alignment: .leading, spacing: 8) {
                Text(video.title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.black)
                    .lineLimit(2)
                
                HStack(spacing: 4) {
                    Text(String(format: NSLocalizedString("views_count", comment: "%@ views"), formatViewCount(video.viewCount ?? 0)))
                    Text("・")
                    Text("\(timeAgo(from: video.date))")
                    Text(NSLocalizedString("show_more", comment: "Show more"))
                        .foregroundColor(.gray)
                    Spacer()
                }
                .font(.system(size: 14))
                .foregroundColor(.gray)
            }
            
            // Channel/Character info
            HStack(spacing: 12) {
                // Character or Anime icon
                if let character = character, let imageIdentifier = character.imageIdentifier,
                   let uiImage = loadImageFromPath(imageIdentifier) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                } else if let anime = anime, let imageIdentifier = anime.imageIdentifier,
                          let uiImage = loadImageFromPath(imageIdentifier) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipShape(Circle())
                } else {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 40, height: 40)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                        )
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(character?.name ?? anime?.title ?? "Unknown")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                    
                    Text(String(format: NSLocalizedString("total_video_views", comment: "Total video views %@ times"), formatViewCount(totalViewCount)))
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                Button(action: showMenuSheet) {
                    Text(NSLocalizedString("edit", comment: "Edit"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(22)
                }
                .contentShape(Rectangle())
                .buttonStyle(PlainButtonStyle())
                
                // Fullscreen button
                Button(action: showFullscreen) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 18))
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.2))
                        .cornerRadius(20)
                }
            }
            
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .onAppear {
            likeCount = Int.random(in: 50...500)
        }
    }
    
    // Helper functions
    func formatViewCount(_ count: Int) -> String {
        if count >= 10000 {
            let formatted = Double(count) / 10000.0
            return String(format: "%.1f万", formatted)
        } else {
            return "\(count)"
        }
    }
    
    func timeAgo(from date: Date) -> String {
        let calendar = Calendar.current
        let now = Date()
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date, to: now)
        
        if let years = components.year, years > 0 {
            return String(format: NSLocalizedString("years_ago", comment: "%d years ago"), years)
        } else if let months = components.month, months > 0 {
            return String(format: NSLocalizedString("months_ago", comment: "%d months ago"), months)
        } else if let days = components.day, days > 0 {
            return String(format: NSLocalizedString("days_ago", comment: "%d days ago"), days)
        } else if let hours = components.hour, hours > 0 {
            return String(format: NSLocalizedString("hours_ago", comment: "%d hours ago"), hours)
        } else if let minutes = components.minute, minutes > 0 {
            return String(format: NSLocalizedString("minutes_ago", comment: "%d minutes ago"), minutes)
        } else {
            return NSLocalizedString("just_now", comment: "Just now")
        }
    }
    
    func loadImageFromPath(_ imagePath: String) -> UIImage? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let imageURL = documentsPath.appendingPathComponent(imagePath)
        return UIImage(contentsOfFile: imageURL.path)
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
                        Text(NSLocalizedString("open_in_youtube", comment: "Open in YouTube"))
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
                    Text(NSLocalizedString("close", comment: "Close"))
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
                    Text(NSLocalizedString("back", comment: "Back"))
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