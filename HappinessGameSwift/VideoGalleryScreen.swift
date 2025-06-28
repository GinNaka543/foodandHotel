import SwiftUI
import AVKit
import PhotosUI

struct MemoryVideo: Identifiable, Codable {
    let id = UUID()
    let title: String
    let tags: [String]
    let videoData: Data
    let date: Date
    let filePath: String
}

struct VideoGalleryScreen: View {
    @State private var videos: [MemoryVideo] = []
    @State private var showingVideoPicker = false
    @State private var showingAddVideo = false
    @State private var selectedVideoURL: URL?
    @State private var videoTitle = ""
    @State private var videoTags = ""
    
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(videos) { video in
                        NavigationLink(destination: VideoDetailView(video: video)) {
                            VideoThumbnailView(video: video)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("ビデオ")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showingAddVideo = true
                    }) {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddVideo) {
            AddVideoView(
                selectedVideoURL: $selectedVideoURL,
                videoTitle: $videoTitle,
                videoTags: $videoTags,
                onSave: saveVideo
            )
        }
        .onAppear {
            loadVideos()
        }
    }
    
    private func saveVideo() {
        guard let videoURL = selectedVideoURL else { return }
        
        do {
            let videoData = try Data(contentsOf: videoURL)
            let video = MemoryVideo(
                title: videoTitle.isEmpty ? "無題" : videoTitle,
                tags: videoTags.isEmpty ? [] : videoTags.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) },
                videoData: videoData,
                date: Date(),
                filePath: videoURL.path
            )
            
            videos.append(video)
            saveVideosToStorage()
            
            // リセット
            selectedVideoURL = nil
            videoTitle = ""
            videoTags = ""
            showingAddVideo = false
        } catch {
            print("Video save error: \(error)")
        }
    }
    
    private func loadVideos() {
        // ローカルストレージから動画を読み込み
        // 実際の実装ではUserDefaultsやCore Dataを使用
    }
    
    private func saveVideosToStorage() {
        // ローカルストレージに動画を保存
        // 実際の実装ではUserDefaultsやCore Dataを使用
    }
}

struct VideoThumbnailView: View {
    let video: MemoryVideo
    
    var body: some View {
        VStack {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black)
                    .frame(width: 150, height: 150)
                
                Image(systemName: "play.circle.fill")
                    .font(.largeTitle)
                    .foregroundColor(.white)
            }
            
            Text(video.title)
                .font(.caption)
                .lineLimit(1)
        }
    }
}

struct VideoDetailView: View {
    let video: MemoryVideo
    @State private var player: AVPlayer?
    
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if let player = player {
                    VideoPlayer(player: player)
                        .frame(height: 300)
                        .cornerRadius(12)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black)
                        .frame(height: 300)
                        .overlay(
                            VStack {
                                Image(systemName: "play.circle.fill")
                                    .font(.largeTitle)
                                    .foregroundColor(.white)
                                Text("動画を読み込み中...")
                                    .foregroundColor(.white)
                            }
                        )
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text(video.title)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("撮影日: \(video.date, style: .date)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !video.tags.isEmpty {
                        Text("タグ: \(video.tags.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color.white)
                .cornerRadius(12)
                .shadow(radius: 2)
            }
            .padding()
        }
        .navigationTitle("動画詳細")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
    
    private func setupPlayer() {
        // 動画プレイヤーの設定
        // 実際の実装ではAVPlayerを使用
    }
}

#Preview {
    VideoGalleryScreen()
} 