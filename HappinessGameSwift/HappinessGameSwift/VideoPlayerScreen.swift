import SwiftUI
import AVKit
import AVFoundation

struct VideoPlayerScreen: View {
    let video: MemoryVideo
    let character: Character?
    let anime: Anime?
    let allVideos: [MemoryVideo]
    @Environment(\.presentationMode) var presentationMode
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var showControls = true
    @State private var selectedVideo: MemoryVideo?
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // ヘッダー
                    HStack {
                        Button(action: {
                            presentationMode.wrappedValue.dismiss()
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white)
                        }
                        Spacer()
                        Text(video.title)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Spacer()
                        Button(action: {
                            // 共有機能など
                        }) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
                    
                    // 動画プレイヤー
                    ZStack {
                        if let player = player {
                            VideoPlayer(player: player)
                                .aspectRatio(16/9, contentMode: .fit)
                                .onTapGesture {
                                    withAnimation(.easeInOut(duration: 0.3)) {
                                        showControls.toggle()
                                    }
                                }
                        } else {
                            Rectangle()
                                .fill(Color.black)
                                .aspectRatio(16/9, contentMode: .fit)
                                .overlay(
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(1.5)
                                )
                        }
                        
                        // コントロールオーバーレイ
                        if showControls {
                            VStack {
                                Spacer()
                                HStack {
                                    Button(action: {
                                        if isPlaying {
                                            player?.pause()
                                        } else {
                                            player?.play()
                                        }
                                        isPlaying.toggle()
                                    }) {
                                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                                            .font(.system(size: 24))
                                            .foregroundColor(.white)
                                            .frame(width: 50, height: 50)
                                            .background(Color.black.opacity(0.6))
                                            .clipShape(Circle())
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                .padding(.bottom, 20)
                            }
                        }
                    }
                    
                    // 動画情報
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(video.title)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                    .lineLimit(2)
                                
                                Text("#" + (video.tags.isEmpty ? "nakajimaginsei" : video.tags.joined(separator: " #")))
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }
                            Spacer()
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
                                            HStack(spacing: 12) {
                                                // サムネイル
                                                if let thumbnailData = relatedVideo.thumbnailData, let uiImage = UIImage(data: thumbnailData) {
                                                    Image(uiImage: uiImage)
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                        .frame(width: 120, height: 68)
                                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                                } else {
                                                    RoundedRectangle(cornerRadius: 8)
                                                        .fill(Color.gray.opacity(0.3))
                                                        .frame(width: 120, height: 68)
                                                }
                                                
                                                // 動画情報
                                                VStack(alignment: .leading, spacing: 4) {
                                                    Text(relatedVideo.title)
                                                        .font(.system(size: 14, weight: .medium))
                                                        .foregroundColor(.white)
                                                        .lineLimit(2)
                                                        .multilineTextAlignment(.leading)
                                                    
                                                    Text("#" + (relatedVideo.tags.isEmpty ? "nakajimaginsei" : relatedVideo.tags.joined(separator: " #")))
                                                        .font(.system(size: 12))
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
                    .background(Color.black)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            setupPlayer()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
        .fullScreenCover(item: $selectedVideo) { newVideo in
            VideoPlayerScreen(
                video: newVideo,
                character: character,
                anime: anime,
                allVideos: allVideos
            )
        }
    }
    
    private func setupPlayer() {
        let videoURL = URL(fileURLWithPath: video.videoPath)
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
} 