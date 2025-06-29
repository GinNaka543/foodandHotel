import SwiftUI
import AVKit
import PhotosUI

struct MemoryVideo: Identifiable, Codable {
    let id: UUID
    let characterId: UUID
    let videoData: Data
    let thumbnailData: Data?
    let title: String
    let tags: [String]
    let date: Date
}

struct VideoGalleryScreen: View {
    let character: Character
    @Environment(\.presentationMode) var presentationMode
    @State private var videos: [MemoryVideo] = []
    @State private var showAddSheet = false
    @State private var selectedVideoURL: URL? = nil
    @State private var videoTitle: String = ""
    @State private var videoTags: String = ""
    @State private var showAlbum = false
    @State private var showTagInput = false
    @State private var newTag: String = ""
    @State private var filteredTags: [String] = []
    @State private var selectedVideo: MemoryVideo? = nil
    @State private var showEditTitle = false
    @State private var showEditTags = false
    @State private var editText = ""
    @State private var showDeleteAlert = false
    @State private var deletingVideoID: UUID? = nil
    @State private var selectedThumbnailData: Data? = nil

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                HStack(alignment: .center, spacing: 0) {
                    // 戻るボタン
                    Button(action: { presentationMode.wrappedValue.dismiss() }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.black)
                            .font(.system(size: 24, weight: .bold))
                            .padding(.leading, 8)
                            .offset(x: -19)
                    }
                    Spacer()
                    // キャラ名
                    HStack {
                        Spacer().frame(width: 0)
                        Text(character.name)
                            .font(.system(size: 25, weight: .bold))
                            .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 2)
                            .offset(x: -15)
                        Spacer()
                    }
                    // Uploadボタン（右端に揃える）
                    Button(action: { showAddSheet = true }) {
                        Text("Upload")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 6)
                            .background(Color.black)
                            .cornerRadius(8)
                    }
                    .padding(.trailing, 16)
                }
                .frame(height: 56)
                .padding(.top, 8)
                .padding(.leading, 30)

                // タブバー
                HStack(spacing: 0) {
                    Spacer(minLength: 70)
                    Button(action: { showAlbum = false }) {
                        VStack(spacing: 2) {
                            Text("Video")
                                .font(.headline)
                                .foregroundColor(.black)
                            Rectangle()
                                .frame(height: 2)
                                .foregroundColor(showAlbum == false ? .black : .clear)
                        }
                    }
                    Spacer()
                    Button(action: { showAlbum = true }) {
                        VStack(spacing: 2) {
                            Text("Album")
                                .font(.headline)
                                .foregroundColor(.black)
                            Rectangle()
                                .frame(height: 2)
                                .foregroundColor(showAlbum == true ? .black : .clear)
                        }
                    }
                    Spacer(minLength: 80)
                }
                .frame(height: 40)
                // 動画リスト or Album
                ZStack {
                    if showAlbum {
                        ScrollView {
                            VideoAlbumGridView(videos: videos, highlightFirstRow: false, filteredTags: filteredTags.isEmpty ? nil : filteredTags, onVideoTap: { video in
                                selectedVideo = video
                            })
                        }
                    } else {
                        ScrollView {
                            VStack(spacing: 32) {
                                ForEach(videos) { video in
                                    VStack(alignment: .leading, spacing: 8) {
                                        VideoThumbnailPlayer(video: video)
                                            .frame(width: 403, height: 242)
                                            .cornerRadius(20)
                                            .onTapGesture {
                                                selectedVideo = video
                                            }
                                        HStack(alignment: .center, spacing: 12) {
                                            if let icon = character.image {
                                                Image(uiImage: icon)
                                                    .resizable()
                                                    .aspectRatio(contentMode: .fill)
                                                    .frame(width: 40, height: 40)
                                                    .clipShape(Circle())
                                            } else {
                                                Circle()
                                                    .fill(Color.gray.opacity(0.3))
                                                    .frame(width: 40, height: 40)
                                                    .overlay(
                                                        Image(systemName: "person")
                                                            .font(.system(size: 20))
                                                            .foregroundColor(.gray)
                                                    )
                                            }
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(video.title)
                                                    .font(.headline)
                                                if !video.tags.isEmpty {
                                                    Text("#" + video.tags.joined(separator: " #"))
                                                        .font(.caption)
                                                        .foregroundColor(.gray)
                                                }
                                            }
                                        }
                                        .padding(.top, 4)
                                    }
                                    .padding(.horizontal, 24)
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                }
            }
            // Albumタブ時のみ右下に＋ボタン
            if showAlbum {
                Button(action: { showTagInput = true }) {
                    Image(systemName: "number")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 56, height: 56)
                        .background(Color.black)
                        .clipShape(Circle())
                        .shadow(radius: 6)
                        .padding(.bottom, 32)
                        .padding(.trailing, 24)
                }
                .sheet(isPresented: $showTagInput) {
                    VStack(spacing: 24) {
                        Text("表示したいタグを入力")
                            .font(.headline)
                        TextField("#タグ名", text: $newTag)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .padding(.horizontal, 24)
                        Button("追加") {
                            let tag = newTag.trimmingCharacters(in: .whitespacesAndNewlines)
                            if !tag.isEmpty && !filteredTags.contains(tag) {
                                filteredTags.append(tag)
                            }
                            newTag = ""
                            showTagInput = false
                        }
                        .font(.headline)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 10)
                        .background(Color.black)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                        Button("キャンセル") {
                            showTagInput = false
                        }
                        .foregroundColor(.red)
                    }
                    .padding(32)
                }
            }
        }
        .onAppear {
            loadVideos()
        }
        .sheet(isPresented: $showAddSheet) {
            AddVideoView(selectedVideoURL: $selectedVideoURL, videoTitle: $videoTitle, videoTags: $videoTags, selectedThumbnailData: $selectedThumbnailData) {
                if selectedVideoURL != nil && !videoTitle.trimmingCharacters(in: .whitespaces).isEmpty && !videoTags.trimmingCharacters(in: .whitespaces).isEmpty {
                    saveVideo()
                }
            }
        }
        .sheet(item: $selectedVideo) { video in
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 24) {
                    Spacer()
                    VideoThumbnailPlayer(video: video)
                        .frame(maxWidth: .infinity, maxHeight: 400)
                        .cornerRadius(24)
                    VStack(spacing: 16) {
                        HStack(spacing: 8) {
                            Text("タイトル: \(video.title)")
                                .font(.headline)
                            Button(action: {
                                editText = video.title
                                showEditTitle = true
                            }) {
                                Image(systemName: "pencil")
                                    .foregroundColor(.blue)
                            }
                        }
                        HStack(spacing: 8) {
                            Text("タグ: \(video.tags.joined(separator: ", "))")
                                .font(.subheadline)
                            Button(action: {
                                editText = video.tags.joined(separator: ",")
                                showEditTags = true
                            }) {
                                Image(systemName: "pencil")
                                    .foregroundColor(.blue)
                            }
                        }
                        Text("ID: \(video.id.uuidString.prefix(8))")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
                // 右下に閉じるボタンとゴミ箱ボタンを横並びで配置
                HStack(spacing: 24) {
                    Spacer()
                    Button(action: {
                        selectedVideo = nil
                    }) {
                        Text("閉じる")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 10)
                            .background(Color.black)
                            .cornerRadius(10)
                    }
                    .padding(.trailing, 79)
                    Button(action: {
                        deletingVideoID = selectedVideo?.id
                        showDeleteAlert = true
                    }) {
                        Image(systemName: "trash")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.black)
                    }
                }
                .padding([.bottom, .trailing], 24)
                // --- カスタムダイアログ ---
                if showEditTitle {
                    Color.black.opacity(0.25)
                        .edgesIgnoringSafeArea(.all)
                    VStack(spacing: 20) {
                        Text("タイトル名を編集")
                            .font(.headline)
                            .padding(.top, 12)
                        TextField("タイトル", text: $editText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .font(.system(size: 18))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                        HStack(spacing: 24) {
                            Button(action: { showEditTitle = false }) {
                                Text("キャンセル")
                                    .foregroundColor(.blue)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            }
                            Button(action: {
                                if let idx = videos.firstIndex(where: { $0.id == video.id }) {
                                    videos[idx] = MemoryVideo(id: videos[idx].id, characterId: videos[idx].characterId, videoData: videos[idx].videoData, thumbnailData: videos[idx].thumbnailData, title: editText, tags: videos[idx].tags, date: videos[idx].date)
                                    saveVideosToUserDefaults()
                                }
                                showEditTitle = false
                            }) {
                                Text("保存")
                                    .foregroundColor(.blue)
                                    .fontWeight(.bold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                    }
                    .background(Color.white)
                    .cornerRadius(18)
                    .shadow(radius: 16)
                    .frame(maxWidth: 340)
                    .padding(.horizontal, 32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
                if showDeleteAlert {
                    Color.black.opacity(0.25)
                        .edgesIgnoringSafeArea(.all)
                    VStack(spacing: 20) {
                        Text("本当に削除しますか？")
                            .font(.headline)
                            .padding(.top, 12)
                        HStack(spacing: 24) {
                            Button(action: {
                                showDeleteAlert = false
                                deletingVideoID = nil
                            }) {
                                Text("キャンセル")
                                    .foregroundColor(.blue)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            }
                            Button(action: {
                                if let delID = deletingVideoID,
                                   let idx = videos.firstIndex(where: { $0.id == delID }) {
                                    videos.remove(at: idx)
                                    saveVideosToUserDefaults()
                                }
                                showDeleteAlert = false
                                deletingVideoID = nil
                                selectedVideo = nil
                            }) {
                                Text("削除")
                                    .foregroundColor(.red)
                                    .fontWeight(.bold)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                    }
                    .background(Color.white)
                    .cornerRadius(18)
                    .shadow(radius: 16)
                    .frame(maxWidth: 340)
                    .padding(.horizontal, 32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
                // --- END カスタムダイアログ ---
            }
        }
    }
    
    private func saveVideo() {
        guard let videoURL = selectedVideoURL, let videoData = try? Data(contentsOf: videoURL) else { return }
        let tags = videoTags.isEmpty ? [] : videoTags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        
        // 選択されたサムネイルを使用、なければ1秒目のフレームを生成
        var thumbnailData: Data? = selectedThumbnailData
        if thumbnailData == nil {
            let asset = AVAsset(url: videoURL)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            imageGenerator.maximumSize = CGSize(width: 300, height: 300)
            
            do {
                let cgImage = try imageGenerator.copyCGImage(at: CMTime(seconds: 1.0, preferredTimescale: 1), actualTime: nil)
                let uiImage = UIImage(cgImage: cgImage)
                thumbnailData = uiImage.jpegData(compressionQuality: 0.8)
            } catch {
                print("サムネイル生成に失敗: \(error)")
            }
        }
        
        let newVideo = MemoryVideo(id: UUID(), characterId: character.id, videoData: videoData, thumbnailData: thumbnailData, title: videoTitle, tags: tags, date: Date())
        videos.insert(newVideo, at: 0)
        saveVideosToUserDefaults()
        selectedVideoURL = nil
        videoTitle = ""
        videoTags = ""
        selectedThumbnailData = nil
        showAddSheet = false
    }
    
    private func loadVideos() {
        let key = "videos_\(character.id.uuidString)"
        if let data = UserDefaults.standard.data(forKey: key),
           let decodedVideos = try? JSONDecoder().decode([MemoryVideo].self, from: data) {
            videos = decodedVideos
        }
    }
    
    private func saveVideosToUserDefaults() {
        let key = "videos_\(character.id.uuidString)"
        if let encodedData = try? JSONEncoder().encode(videos) {
            UserDefaults.standard.set(encodedData, forKey: key)
        }
    }
}

struct VideoThumbnailPlayer: View {
    let video: MemoryVideo
    @State private var player: AVPlayer? = nil
    @State private var tempURL: URL? = nil
    @State private var isPlaying = false
    
    var body: some View {
        ZStack {
            if let player = player, isPlaying {
                VideoPlayer(player: player)
                    .onTapGesture {
                        player.pause()
                        isPlaying = false
                    }
            } else {
                // サムネイル表示
                if let thumbnailData = video.thumbnailData,
                   let uiImage = UIImage(data: thumbnailData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                        .overlay(
                            Image(systemName: "play.circle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.white)
                                .shadow(radius: 4)
                        )
                        .onTapGesture {
                            playVideo()
                        }
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black)
                        .overlay(
                            Image(systemName: "play.circle.fill")
                                .font(.largeTitle)
                                .foregroundColor(.white)
                        )
                        .onTapGesture {
                            playVideo()
                        }
                }
            }
        }
        .onAppear {
            if player == nil {
                // Dataから一時ファイルを作成し、そのURLでAVPlayerを生成
                let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
                do {
                    try video.videoData.write(to: url)
                    tempURL = url
                    player = AVPlayer(url: url)
                } catch {
                    print("動画の一時ファイル作成に失敗: \(error)")
                }
            }
        }
        .onDisappear {
            player?.pause()
            isPlaying = false
            // 一時ファイル削除
            if let url = tempURL {
                try? FileManager.default.removeItem(at: url)
                tempURL = nil
            }
        }
    }
    
    private func playVideo() {
        guard let player = player else { return }
        player.seek(to: .zero)
        player.play()
        isPlaying = true
    }
}

struct VideoAlbumGridView: View {
    let videos: [MemoryVideo]
    let highlightFirstRow: Bool
    let filteredTags: [String]?
    var onVideoTap: ((MemoryVideo) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            // 1行目: 全動画
            if !videos.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 24) {
                            ForEach(videos) { video in
                                VideoThumbnailPlayer(video: video)
                                    .frame(width: 234, height: 140)
                                    .cornerRadius(20)
                                    .onTapGesture {
                                        onVideoTap?(video)
                                    }
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.top, 24)
            }
            // 2行目以降: タグごとのグループ
            if let tags = filteredTags {
                ForEach(tags, id: \.self) { tag in
                    let tagVideos = videos.filter { $0.tags.contains(tag) }
                    if !tagVideos.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("#" + tag)
                                .font(.headline)
                                .padding(.leading, 16)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 24) {
                                    ForEach(tagVideos) { video in
                                        VideoThumbnailPlayer(video: video)
                                            .frame(width: 187, height: 112)
                                            .cornerRadius(20)
                                            .onTapGesture {
                                                onVideoTap?(video)
                                            }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    VideoGalleryScreen(character: Character(id: UUID(), image: nil, name: "キャラクター名", tag: "タグ", birthday: Date()))
} 