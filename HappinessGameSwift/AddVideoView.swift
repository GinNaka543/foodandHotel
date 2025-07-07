import SwiftUI
import PhotosUI
import AVKit
import AVFoundation

struct AddVideoView: View {
    @Binding var selectedVideoURL: URL?
    @Binding var videoTitle: String
    @Binding var videoTags: String
    @Binding var selectedThumbnailData: Data?
    let onSave: () -> Void
    var onYouTubeSave: ((String, String, String, String) -> Void)? = nil
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingVideoPicker = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var player: AVPlayer?
    @State private var thumbnailImages: [UIImage] = []
    @State private var selectedThumbnailIndex: Int = 0
    @State private var isExporting = false
    @State private var exportError: String? = nil
    @State private var youtubeURL: String = ""
    @State private var isLoadingYouTube = false
    @State private var youtubeTitle: String = ""
    @State private var youtubeThumbnailURL: String = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 動画プレビュー
                    if let player = player {
                        VideoPlayer(player: player)
                            .frame(height: 300)
                            .cornerRadius(12)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.2))
                            .frame(height: 200)
                            .overlay(
                                VStack {
                                    Image(systemName: "video")
                                        .font(.largeTitle)
                                        .foregroundColor(.gray)
                                    Text("動画を選択")
                                        .foregroundColor(.gray)
                                }
                            )
                    }
                    
                    // 動画選択ボタン
                    PhotosPicker(selection: $selectedItem, matching: .videos) {
                        HStack {
                            Image(systemName: "video.on.rectangle")
                            Text("動画を選択")
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    
                    // サムネイル選択セクション
                    if !thumbnailImages.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("サムネイルを選択")
                                .font(.headline)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 12) {
                                    ForEach(0..<thumbnailImages.count, id: \.self) { index in
                                        Image(uiImage: thumbnailImages[index])
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 80, height: 80)
                                            .clipped()
                                            .cornerRadius(8)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 8)
                                                    .stroke(selectedThumbnailIndex == index ? Color.blue : Color.clear, lineWidth: 3)
                                            )
                                            .onTapGesture {
                                                selectedThumbnailIndex = index
                                                selectedThumbnailData = thumbnailImages[index].jpegData(compressionQuality: 0.8)
                                            }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    
                    // タイトル入力
                    VStack(alignment: .leading, spacing: 8) {
                        Text("タイトル")
                            .font(.headline)
                        
                        TextField("タイトルを入力", text: $videoTitle)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // タグ入力
                    VStack(alignment: .leading, spacing: 8) {
                        Text("タグ（カンマ区切り）")
                            .font(.headline)
                        
                        TextField("タグを入力", text: $videoTags)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    Divider().padding(.vertical, 8)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("YouTube動画のURLから追加")
                            .font(.headline)
                        TextField("https://www.youtube.com/watch?v=...", text: $youtubeURL)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .autocapitalization(.none)
                            .disableAutocorrection(true)
                        
                        if isLoadingYouTube {
                            HStack {
                                ProgressView()
                                Text("YouTube情報を取得中...")
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
                        
                        Button("YouTube動画を追加") {
                            Task {
                                await fetchYouTubeInfo()
                            }
                        }
                        .disabled(youtubeURL.isEmpty || isLoadingYouTube)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(youtubeURL.isEmpty || isLoadingYouTube ? Color.gray : Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                    }
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle("動画を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        if let url = selectedVideoURL {
                            isExporting = true
                            exportVideoTo1980x1080(inputURL: url) { exportedURL in
                                DispatchQueue.main.async {
                                    isExporting = false
                                    if let exportedURL = exportedURL {
                                        selectedVideoURL = exportedURL
                                        onSave()
                                    } else {
                                        exportError = "動画のリサイズ保存に失敗しました"
                                    }
                                }
                            }
                        }
                    }
                    .disabled(selectedVideoURL == nil || isExporting)
                }
            }
            .alert(isPresented: Binding<Bool>(get: { exportError != nil }, set: { _ in exportError = nil })) {
                Alert(title: Text("エラー"), message: Text(exportError ?? ""), dismissButton: .default(Text("OK")))
            }
            .overlay(
                Group {
                    if isExporting {
                        ZStack {
                            Color.black.opacity(0.3).ignoresSafeArea()
                            ProgressView("動画を変換中...")
                                .padding()
                                .background(Color.white)
                                .cornerRadius(12)
                        }
                    }
                }
            )
        }
        .onChange(of: selectedItem) { oldValue, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self) {
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
                    do {
                        try data.write(to: tempURL)
                        selectedVideoURL = tempURL
                        player = AVPlayer(url: tempURL)
                        
                        await generateThumbnails(from: tempURL)
                    } catch {
                        print("動画の保存に失敗しました")
                    }
                }
            }
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
    
    private func generateThumbnails(from url: URL) async {
        let asset = AVURLAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = CGSize(width: 300, height: 300)
        
        thumbnailImages.removeAll()
        
        let timePoints = [0.0, 1.0, 2.0, 3.0, 4.0]
        
        for timePoint in timePoints {
            do {
                let cgImage = try await imageGenerator.image(at: CMTime(seconds: timePoint, preferredTimescale: 1))
                let uiImage = UIImage(cgImage: cgImage.image)
                thumbnailImages.append(uiImage)
            } catch {
                print("サムネイル生成に失敗: \(error)")
            }
        }
        
        if !thumbnailImages.isEmpty {
            selectedThumbnailIndex = 1
            selectedThumbnailData = thumbnailImages[1].jpegData(compressionQuality: 0.8)
        }
    }
    
    // 1980x1080へリサイズしてエクスポート
    func exportVideoTo1980x1080(inputURL: URL, completion: @escaping (URL?) -> Void) {
        let asset = AVAsset(url: inputURL)
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPreset1920x1080) else {
            completion(nil)
            return
        }
        let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        exportSession.exportAsynchronously {
            if exportSession.status == .completed {
                completion(outputURL)
            } else {
                completion(nil)
            }
        }
    }
    
    func fetchYouTubeInfo() async {
        guard !youtubeURL.isEmpty else { return }
        
        isLoadingYouTube = true
        
        // Extract video ID from URL
        let videoId = extractYouTubeVideoId(from: youtubeURL)
        guard !videoId.isEmpty else {
            isLoadingYouTube = false
            return
        }
        
        // Get thumbnail URL
        youtubeThumbnailURL = "https://img.youtube.com/vi/\(videoId)/maxresdefault.jpg"
        
        // For title, we'll use a simple approach
        // In a real app, you might want to use YouTube Data API
        youtubeTitle = videoTitle.isEmpty ? "YouTube動画" : videoTitle
        
        // Save YouTube video info
        if let onYouTubeSave = onYouTubeSave {
            onYouTubeSave(youtubeURL, youtubeTitle, youtubeThumbnailURL, videoTags)
            dismiss()
        }
        
        isLoadingYouTube = false
    }
    
    func extractYouTubeVideoId(from url: String) -> String {
        // Handle different YouTube URL formats
        let patterns = [
            "(?:youtube\\.com/watch\\?v=|youtu\\.be/)([^&\\n?#]+)",
            "youtube\\.com/embed/([^&\\n?#]+)",
            "youtube\\.com/v/([^&\\n?#]+)"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: url, options: [], range: NSRange(location: 0, length: url.utf16.count)),
               let range = Range(match.range(at: 1), in: url) {
                return String(url[range])
            }
        }
        
        return ""
    }
}

#Preview {
    AddVideoView(
        selectedVideoURL: .constant(nil),
        videoTitle: .constant(""),
        videoTags: .constant(""),
        selectedThumbnailData: .constant(nil),
        onSave: {}
    )
} 