import SwiftUI
import AVKit
import AVFoundation
import UIKit

struct VideoPlayerScreen: View {
    let video: MemoryVideo
    let character: Character?
    let anime: Anime?
    let allVideos: [MemoryVideo]
    var onSave: ((String, [String]) -> Void)? = nil // タイトル・タグ保存用
    var onDelete: (() -> Void)? = nil // 削除用
    var onThumbnailUpdate: ((Data?) -> Void)? = nil // サムネイル更新用
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
    
    var body: some View {
        // YouTube動画の場合は、YouTubeアプリで開く
        if let youtubeURL = video.youtubeURL, !youtubeURL.isEmpty {
            VStack {
                Spacer()
                VStack(spacing: 20) {
                    // カスタムサムネイルを優先して表示
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
                        openYouTubeVideo(url: youtubeURL)
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
                        presentationMode.wrappedValue.dismiss()
                    }) {
                        Text("閉じる")
                            .foregroundColor(.gray)
                            .padding()
                    }
                }
                Spacer()
            }
            .background(Color(.systemBackground))
        } else {
            // 通常の動画プレイヤー
            GeometryReader { geometry in
                ZStack(alignment: .topLeading) {
                    VStack(spacing: 0) {
                        ZStack(alignment: .topLeading) {
                            VideoPlayer(player: player)
                                .aspectRatio(16.0/9.0, contentMode: .fill)
                                .frame(width: geometry.size.width, height: geometry.size.height < geometry.size.width ? geometry.size.height : geometry.size.width * 9.0 / 16.0)
                                .clipped()
                                .background(Color.black)
                                .padding(.top, -10)
                            // AirPlayロゴの位置を10px下げる
                            Spacer().frame(height: 10)
                        }
                        .frame(width: geometry.size.width, height: geometry.size.height < geometry.size.width ? geometry.size.height : geometry.size.width * 9.0 / 16.0)
                        .background(Color.black)
                    // --- 動画情報・関連動画 ---
                    VStack(alignment: .leading, spacing: 12) {
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
                            Button(action: {
                                showMenuSheet = true
                            }) {
                                Text("編集")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 16)
                                    .background(Color.black)
                                    .cornerRadius(8)
                            }
                            .padding(.trailing, 4)
                            Button(action: {
                                showFullscreen = true
                            }) {
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
                        // 関連動画
                        VStack(alignment: .leading, spacing: 12) {
                            Text("関連動画")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                            ScrollView {
                                LazyVStack(spacing: 12) {
                                    ForEach(allVideos.filter { $0.id != video.id }, id: \.id) { relatedVideo in
                                        Button(action: {
                                            selectedVideo = relatedVideo
                                        }) {
                                            HStack(spacing: 16) {
                                                if let thumbnailData = relatedVideo.thumbnailData, let uiImage = UIImage(data: thumbnailData) {
                                                    Image(uiImage: uiImage)
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                        .frame(width: 160, height: 90)
                                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                                } else if let youtubeThumbnailURL = relatedVideo.youtubeThumbnailURL {
                                                    AsyncImage(url: URL(string: youtubeThumbnailURL)) { image in
                                                        image
                                                            .resizable()
                                                            .aspectRatio(contentMode: .fill)
                                                            .frame(width: 160, height: 90)
                                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                                    } placeholder: {
                                                        RoundedRectangle(cornerRadius: 8)
                                                            .fill(Color.gray.opacity(0.3))
                                                            .frame(width: 160, height: 90)
                                                            .overlay(ProgressView())
                                                    }
                                                } else {
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .fill(Color.gray.opacity(0.3))
                                                        .frame(width: 160, height: 90)
                                                }
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(relatedVideo.title)
                                                        .font(.system(size: 16, weight: .semibold))
                                                        .foregroundColor(.black)
                                                        .lineLimit(2)
                                                        .multilineTextAlignment(.leading)
                                                    Text("#" + (relatedVideo.tags.isEmpty ? "nakajimaginsei" : relatedVideo.tags.joined(separator: " #")))
                                                        .font(.system(size: 14))
                                                        .foregroundColor(.gray)
                                                        .lineLimit(1)
                                                }
                                                Spacer()
                                            }
                                            .padding(.horizontal, 16)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                }
                            }
                        }
                    }
                }
                // 画面全体の右下に戻るボタン
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
                // フルスクリーンView
                .fullScreenCover(isPresented: $showFullscreen) {
                    FullScreenVideoPlayer(player: player, onDismiss: { showFullscreen = false })
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            setupPlayer()
            editTitle = video.title
            editTags = video.tags.joined(separator: ",")
            player?.play()
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
                    },
                    onCancel: {
                        activeSheet = nil
                    }
                )
            }
        }
        }
    }
    
    private func setupPlayer() {
        // YouTube動画の場合はプレイヤーを設定しない
        if video.youtubeURL != nil && !video.videoPath.isEmpty {
            return
        }
        
        guard let videoURL = loadVideoURLFromPath(video.videoPath) else {
            print("動画ファイルが見つかりません: \(video.videoPath)")
            return
        }
        
        player = AVPlayer(url: videoURL)
        
        // 動画の長さを取得
        let asset = AVURLAsset(url: videoURL)
        let durationItem = asset.tracks(withMediaType: .video).first
        if let durationItem = durationItem {
            duration = CMTimeGetSeconds(durationItem.timeRange.duration)
        }
        
        // 再生状態の監視
        player?.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { time in
            currentTime = CMTimeGetSeconds(time)
        }
    }
    
    private func openYouTubeVideo(url: String) {
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

    private func resetHideControlsTimer() {
        hideControlsWorkItem?.cancel()
        let workItem = DispatchWorkItem {
            withAnimation {
                showControls = false
            }
        }
        hideControlsWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: workItem)
    }
    
    private func handleVideoSelection(_ newVideo: MemoryVideo) {
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
    
    private func showYouTubeConfirmation(for url: String, title: String) {
        print("YouTube確認ダイアログを表示します: \(title)")
        if let youtubeVideo = allVideos.first(where: { $0.youtubeURL == url }) {
            activeSheet = .youtubeConfirmation(youtubeVideo)
        }
    }
    
    private func switchToVideo(_ newVideo: MemoryVideo) {
        // 現在の動画を停止
        player?.pause()
        player = nil
        
        // 新しい動画のプレイヤーを設定
        if let videoURL = loadVideoURLFromPath(newVideo.videoPath) {
            let newPlayer = AVPlayer(url: videoURL)
            player = newPlayer
            
            // 動画の長さを取得
            let asset = AVAsset(url: videoURL)
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
    private func youtubeConfirmationSheet(video: MemoryVideo) -> some View {
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
    private func editTitleSheet(video: MemoryVideo) -> some View {
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
    private func editTagsSheet(video: MemoryVideo) -> some View {
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