import SwiftUI
import AVKit
import PhotosUI

struct ThumbnailPickerView: View {
    let video: MemoryVideo
    let onSave: (Data?) -> Void
    let onCancel: () -> Void
    
    @State private var thumbnailImages: [UIImage] = []
    @State private var selectedThumbnailIndex: Int = 0
    @State private var selectedThumbnailData: Data? = nil
    @State private var isGeneratingThumbnails = true
    @State private var showImagePicker = false
    @State private var selectedImageItem: PhotosPickerItem?
    @State private var customThumbnailImage: UIImage?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                if isGeneratingThumbnails {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("サムネイルを生成中...")
                            .font(.headline)
                            .foregroundColor(.secondary)
                            .padding(.top)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(spacing: 24) {
                            // 現在のサムネイル
                            VStack(alignment: .leading, spacing: 12) {
                                Text("現在のサムネイル")
                                    .font(.headline)
                                
                                if let customImage = customThumbnailImage {
                                    Image(uiImage: customImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxHeight: 200)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.blue, lineWidth: 3)
                                        )
                                } else if selectedThumbnailIndex < thumbnailImages.count {
                                    Image(uiImage: thumbnailImages[selectedThumbnailIndex])
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(maxHeight: 200)
                                        .cornerRadius(12)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.blue, lineWidth: 3)
                                        )
                                }
                            }
                            
                            // 動画から生成したサムネイル
                            if !thumbnailImages.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("動画から選択")
                                        .font(.headline)
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 12) {
                                            ForEach(thumbnailImages.indices, id: \.self) { index in
                                                Button(action: {
                                                    selectedThumbnailIndex = index
                                                    customThumbnailImage = nil
                                                    selectedThumbnailData = thumbnailImages[index].jpegData(compressionQuality: 0.8)
                                                }) {
                                                    Image(uiImage: thumbnailImages[index])
                                                        .resizable()
                                                        .aspectRatio(contentMode: .fill)
                                                        .frame(width: 120, height: 68)
                                                        .cornerRadius(8)
                                                        .overlay(
                                                            RoundedRectangle(cornerRadius: 8)
                                                                .stroke(
                                                                    selectedThumbnailIndex == index && customThumbnailImage == nil ? Color.blue : Color.clear,
                                                                    lineWidth: 2
                                                                )
                                                        )
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // カスタム画像をアップロード
                            VStack(alignment: .leading, spacing: 12) {
                                Text("画像をアップロード")
                                    .font(.headline)
                                
                                PhotosPicker(selection: $selectedImageItem,
                                           matching: .images,
                                           photoLibrary: .shared()) {
                                    HStack {
                                        Image(systemName: "photo.on.rectangle")
                                            .font(.title2)
                                        Text("フォトライブラリから選択")
                                            .font(.body)
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.blue)
                                    .cornerRadius(10)
                                }
                                .onChange(of: selectedImageItem) { newItem in
                                    Task {
                                        if let newItem = newItem {
                                            if let data = try? await newItem.loadTransferable(type: Data.self),
                                               let uiImage = UIImage(data: data) {
                                                customThumbnailImage = uiImage
                                                selectedThumbnailData = uiImage.jpegData(compressionQuality: 0.8)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("サムネイルを変更")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        onSave(selectedThumbnailData)
                    }
                    .disabled(isGeneratingThumbnails)
                }
            }
        }
        .onAppear {
            if video.youtubeURL == nil {
                Task {
                    await generateThumbnails()
                }
            } else {
                // YouTube動画の場合
                Task {
                    await loadYouTubeThumbnail()
                }
            }
        }
    }
    
    private func generateThumbnails() async {
        guard video.youtubeURL == nil else { return }
        
        guard let url = loadVideoURLFromPath(video.videoPath) else {
            print("動画ファイルが見つかりません: \(video.videoPath)")
            return
        }
        let asset = AVURLAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = CGSize(width: 600, height: 600)
        
        thumbnailImages.removeAll()
        
        // 動画の長さを取得
        let duration = try? await asset.load(.duration)
        let durationSeconds = duration?.seconds ?? 10.0
        
        // 5つの時点からサムネイルを生成
        let timePoints: [Double]
        if durationSeconds > 5 {
            timePoints = [0.0, durationSeconds * 0.25, durationSeconds * 0.5, durationSeconds * 0.75, durationSeconds * 0.9]
        } else {
            timePoints = [0.0, 0.5, 1.0, 1.5, 2.0].filter { $0 < durationSeconds }
        }
        
        for timePoint in timePoints {
            do {
                let time = CMTime(seconds: timePoint, preferredTimescale: 1)
                let cgImage = try await imageGenerator.image(at: time).image
                let uiImage = UIImage(cgImage: cgImage)
                thumbnailImages.append(uiImage)
            } catch {
                print("サムネイル生成エラー at \(timePoint)s: \(error)")
            }
        }
        
        // 現在のサムネイルと一致するものを探す
        if let currentThumbnailData = video.thumbnailData,
           let currentImage = UIImage(data: currentThumbnailData) {
            // 既存のサムネイルがある場合は、それをカスタム画像として設定
            customThumbnailImage = currentImage
            selectedThumbnailData = currentThumbnailData
        } else if !thumbnailImages.isEmpty {
            // 既存のサムネイルがない場合は、最初の画像を選択
            selectedThumbnailIndex = 0
            selectedThumbnailData = thumbnailImages[0].jpegData(compressionQuality: 0.8)
        }
        
        isGeneratingThumbnails = false
    }
    
    private func loadYouTubeThumbnail() async {
        isGeneratingThumbnails = true
        
        // カスタムサムネイルがある場合はそれを優先
        if let currentThumbnailData = video.thumbnailData,
           let image = UIImage(data: currentThumbnailData) {
            customThumbnailImage = image
            selectedThumbnailData = currentThumbnailData
        } else if let youtubeThumbnailURL = video.youtubeThumbnailURL,
                  let url = URL(string: youtubeThumbnailURL) {
            // YouTube URLからサムネイルを取得
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    customThumbnailImage = image
                    selectedThumbnailData = data
                }
            } catch {
                print("YouTube サムネイル読み込みエラー: \(error)")
            }
        }
        
        isGeneratingThumbnails = false
    }
}