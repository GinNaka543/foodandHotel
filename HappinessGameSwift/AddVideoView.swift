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
    @State private var showUploadMethodSelection = true
    @State private var selectedUploadMethod: UploadMethod?
    @State private var thumbnailPickerItem: PhotosPickerItem?
    @State private var customYouTubeThumbnail: UIImage?
    
    enum UploadMethod {
        case youtube
        case manual
    }
    
    var body: some View {
        NavigationView {
            if showUploadMethodSelection && selectedUploadMethod == nil {
                // アップロード方法選択画面
                uploadMethodSelectionView
            } else {
                // 従来のアップロード画面
                uploadContentView
            }
        }
    }
    
    var uploadMethodSelectionView: some View {
        VStack(spacing: 30) {
            Text("アップロード方法を選択")
                .font(.title2)
                .fontWeight(.bold)
                .padding(.top, 50)
            
            VStack(spacing: 20) {
                // YouTube URLから追加
                Button(action: {
                    selectedUploadMethod = .youtube
                    showUploadMethodSelection = false
                }) {
                    VStack(spacing: 12) {
                        Image(systemName: "play.rectangle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.red)
                        
                        Text("YouTube URLから追加")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("YouTube動画のURLを入力して\n動画情報を取得します")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.red, lineWidth: 2)
                    )
                }
                
                // 手動アップロード
                Button(action: {
                    selectedUploadMethod = .manual
                    showUploadMethodSelection = false
                }) {
                    VStack(spacing: 12) {
                        Image(systemName: "video.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        
                        Text("手動でアップロード")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("デバイスから動画を選択して\n手動で情報を入力します")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.blue, lineWidth: 2)
                    )
                }
            }
            .padding(.horizontal, 20)
            
            // YouTubeダウンロードボタン
            Button(action: {
                if let url = URL(string: "https://y2down.cc/ja4O") {
                    UIApplication.shared.open(url)
                }
            }) {
                HStack {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.green)
                    Text("YouTubeから動画をダウンロードする")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "arrow.up.forward.square")
                        .foregroundColor(.gray)
                        .font(.system(size: 14))
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green, lineWidth: 1)
                )
            }
            .padding(.horizontal, 20)
            
            Spacer()
        }
        .navigationTitle("動画を追加")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("キャンセル") {
                    dismiss()
                }
            }
        }
    }
    
    @ViewBuilder
    private var youtubeUploadContent: some View {
        VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("YouTube URL")
                                .font(.headline)
                            TextField("URLを入力してください", text: $youtubeURL)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .foregroundColor(.primary)
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("タイトル")
                                .font(.headline)
                            TextField("動画タイトル", text: $youtubeTitle)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("タグ（カンマ区切り）")
                                .font(.headline)
                            TextField("タグ1,タグ2,タグ3", text: $videoTags)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        
                        // サムネイルアップロードセクション
                        VStack(alignment: .leading, spacing: 12) {
                            Text("サムネイル画像")
                                .font(.headline)
                            
                            if let thumbnail = customYouTubeThumbnail {
                                Image(uiImage: thumbnail)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxHeight: 200)
                                    .cornerRadius(12)
                            }
                            
                            PhotosPicker(selection: $thumbnailPickerItem, matching: .images) {
                                HStack {
                                    Image(systemName: "photo")
                                    Text(customYouTubeThumbnail == nil ? "サムネイルを選択" : "サムネイルを変更")
                                }
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.gray)
                                .cornerRadius(8)
                            }
                            
                            Text("※ YouTubeのサムネイルが取得できない場合は、こちらからアップロードしてください")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                        
                        if isLoadingYouTube {
                            HStack {
                                ProgressView()
                                Text("YouTube情報を取得中...")
                                    .foregroundColor(.gray)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                        }
        }
    }
    
    @ViewBuilder
    private var manualUploadContent: some View {
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
        }
    }
    
    var uploadContentView: some View {
        ScrollView {
            VStack(spacing: 20) {
                if selectedUploadMethod == .youtube {
                    youtubeUploadContent
                } else {
                    manualUploadContent
                }
                
                Spacer(minLength: 100)
            }
            .padding()
        }
        .navigationTitle(selectedUploadMethod == .youtube ? "YouTube動画を追加" : "動画を追加")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("戻る") {
                        if selectedUploadMethod != nil {
                            selectedUploadMethod = nil
                            showUploadMethodSelection = true
                        } else {
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        if selectedUploadMethod == .youtube {
                            // YouTube動画の保存処理
                            Task {
                                await fetchYouTubeInfo()
                            }
                        } else {
                            // 手動アップロードの保存処理
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
                    }
                    .disabled(selectedUploadMethod == .youtube ? 
                             (youtubeURL.isEmpty || youtubeTitle.isEmpty) : 
                             (selectedVideoURL == nil || isExporting))
                }
            }
        .alert("エラー", isPresented: Binding<Bool>(
                get: { exportError != nil },
                set: { _ in exportError = nil }
            )) {
                Button("OK") {
                    exportError = nil
                }
            } message: {
                Text(exportError ?? "")
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
        .onChange(of: thumbnailPickerItem) { newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        customYouTubeThumbnail = image
                        selectedThumbnailData = data
                    }
                }
            }
        .onChange(of: selectedItem) { newValue in
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
        
        // Use custom thumbnail if provided, otherwise use YouTube thumbnail
        if customYouTubeThumbnail != nil {
            // Custom thumbnail is already set in selectedThumbnailData
            youtubeThumbnailURL = "custom"
        } else {
            // Get YouTube thumbnail URL
            youtubeThumbnailURL = "https://img.youtube.com/vi/\(videoId)/maxresdefault.jpg"
        }
        
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