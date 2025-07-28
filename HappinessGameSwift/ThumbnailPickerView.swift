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
    
    // サムネイル調整用のState
    @State private var thumbnailScale: CGFloat = 1.0
    @State private var thumbnailOffsetX: CGFloat = 0.0
    @State private var thumbnailOffsetY: CGFloat = 0.0
    @State private var showAdjustmentControls = true  // デフォルトでtrueに変更
    @State private var originalImage: UIImage?
    
    // サムネイルの推奨サイズ (16:9のアスペクト比)
    private let thumbnailWidth: CGFloat = 480
    private let thumbnailHeight: CGFloat = 270
    
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
                                Text(NSLocalizedString("current_thumbnail", comment: "Current Thumbnail"))
                                    .font(.headline)
                                
                                // サムネイルプレビュー
                                GeometryReader { geometry in
                                    let previewWidth = geometry.size.width
                                    let previewHeight = previewWidth * 9 / 16
                                    
                                    ZStack {
                                        Rectangle()
                                            .fill(Color.black)
                                            .frame(width: previewWidth, height: previewHeight)
                                            .cornerRadius(12)
                                        
                                        if let image = originalImage {
                                            Image(uiImage: image)
                                                .resizable()
                                                .aspectRatio(contentMode: .fill)
                                                .frame(width: previewWidth * thumbnailScale, height: previewHeight * thumbnailScale)
                                                .offset(x: thumbnailOffsetX * previewWidth / thumbnailWidth, y: thumbnailOffsetY * previewHeight / thumbnailHeight)
                                                .clipped()
                                                .frame(width: previewWidth, height: previewHeight)
                                                .cornerRadius(12)
                                        }
                                    }
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.blue, lineWidth: 3)
                                    )
                                }
                                .frame(height: UIScreen.main.bounds.width * 9 / 16)
                            }
                            
                            // カスタム画像をアップロード（調整バーの上に配置）
                            VStack(alignment: .leading, spacing: 12) {
                                Text(NSLocalizedString("upload_image", comment: "Upload Image"))
                                    .font(.headline)
                                
                                // 推奨サイズの説明を追加
                                Text(NSLocalizedString("recommended_image_size", comment: "Recommended image size: 1920×1080 (16:9)"))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .padding(.bottom, 4)
                                
                                PhotosPicker(selection: $selectedImageItem,
                                           matching: .images,
                                           photoLibrary: .shared()) {
                                    HStack {
                                        Image(systemName: "photo.on.rectangle")
                                            .font(.title2)
                                        Text(NSLocalizedString("select_from_photo_library", comment: "Select from Photo Library"))
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
                                                originalImage = uiImage
                                                customThumbnailImage = uiImage
                                                thumbnailScale = 1.0
                                                thumbnailOffsetX = 0
                                                thumbnailOffsetY = 0
                                                updateThumbnailData()
                                            }
                                        }
                                    }
                                }
                            }
                            
                            // 調整コントロール（画像アップロードの下に配置）
                            if showAdjustmentControls && originalImage != nil {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(NSLocalizedString("thumbnail_adjustment", comment: "Thumbnail Adjustment"))
                                        .font(.headline)
                                    VStack(spacing: 16) {
                                        // スケール調整
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack {
                                                Text(NSLocalizedString("thumbnail_size", comment: "Size"))
                                                    .font(.subheadline)
                                                Spacer()
                                                Text(String(format: "%.0f%%", thumbnailScale * 100))
                                                    .font(.caption)
                                                    .foregroundColor(.gray)
                                            }
                                            Slider(value: $thumbnailScale, in: 0.5...2.0)
                                                .accentColor(.blue)
                                                .onChange(of: thumbnailScale) { _ in
                                                    updateThumbnailData()
                                                }
                                        }
                                        
                                        // 水平位置調整
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack {
                                                Text(NSLocalizedString("horizontal_position", comment: "Horizontal Position"))
                                                    .font(.subheadline)
                                                Spacer()
                                                Button(NSLocalizedString("reset", comment: "Reset")) {
                                                    thumbnailOffsetX = 0
                                                }
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                            }
                                            Slider(value: $thumbnailOffsetX, in: -thumbnailWidth/2...thumbnailWidth/2)
                                                .accentColor(.blue)
                                                .onChange(of: thumbnailOffsetX) { _ in
                                                    updateThumbnailData()
                                                }
                                        }
                                        
                                        // 垂直位置調整
                                        VStack(alignment: .leading, spacing: 8) {
                                            HStack {
                                                Text(NSLocalizedString("vertical_position", comment: "Vertical Position"))
                                                    .font(.subheadline)
                                                Spacer()
                                                Button(NSLocalizedString("reset", comment: "Reset")) {
                                                    thumbnailOffsetY = 0
                                                }
                                                .font(.caption)
                                                .foregroundColor(.blue)
                                            }
                                            Slider(value: $thumbnailOffsetY, in: -thumbnailHeight/2...thumbnailHeight/2)
                                                .accentColor(.blue)
                                                .onChange(of: thumbnailOffsetY) { _ in
                                                    updateThumbnailData()
                                                }
                                        }
                                        
                                        // 全てリセットボタン
                                        Button(action: {
                                            thumbnailScale = 1.0
                                            thumbnailOffsetX = 0
                                            thumbnailOffsetY = 0
                                            updateThumbnailData()
                                        }) {
                                            Text(NSLocalizedString("reset_all", comment: "Reset All"))
                                                .font(.system(size: 14))
                                                .foregroundColor(.red)
                                        }
                                        .padding(.top, 8)
                                    }
                                    .padding()
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(10)
                                }
                            }
                            
                            // 動画から生成したサムネイル
                            if !thumbnailImages.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text(NSLocalizedString("select_from_video", comment: "Select from Video"))
                                        .font(.headline)
                                    
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 12) {
                                            ForEach(thumbnailImages.indices, id: \.self) { index in
                                                Button(action: {
                                                    selectedThumbnailIndex = index
                                                    customThumbnailImage = nil
                                                    originalImage = thumbnailImages[index]
                                                    thumbnailScale = 1.0
                                                    thumbnailOffsetX = 0
                                                    thumbnailOffsetY = 0
                                                    updateThumbnailData()
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
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle(NSLocalizedString("change_thumbnail_title", comment: "Change Thumbnail"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("cancel", comment: "Cancel")) {
                        onCancel()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("save", comment: "Save")) {
                        // 保存前に最新の調整値を適用
                        if originalImage != nil {
                            updateThumbnailData()
                        }
                        print("💾 [ThumbnailPicker] Saving thumbnail with data size: \(selectedThumbnailData?.count ?? 0) bytes")
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
            }
        }
        
        // 現在のサムネイルと一致するものを探す
        if let currentThumbnailData = video.thumbnailData,
           let currentImage = UIImage(data: currentThumbnailData) {
            // 既存のサムネイルがある場合は、それをカスタム画像として設定
            customThumbnailImage = currentImage
            originalImage = currentImage
            selectedThumbnailData = currentThumbnailData
        } else if !thumbnailImages.isEmpty {
            // 既存のサムネイルがない場合は、最初の画像を選択
            selectedThumbnailIndex = 0
            originalImage = thumbnailImages[0]
            updateThumbnailData()
        }
        
        isGeneratingThumbnails = false
    }
    
    private func loadYouTubeThumbnail() async {
        isGeneratingThumbnails = true
        
        // カスタムサムネイルがある場合はそれを優先
        if let currentThumbnailData = video.thumbnailData,
           let image = UIImage(data: currentThumbnailData) {
            customThumbnailImage = image
            originalImage = image
            selectedThumbnailData = currentThumbnailData
        } else if let youtubeThumbnailURL = video.youtubeThumbnailURL,
                  let url = URL(string: youtubeThumbnailURL) {
            // YouTube URLからサムネイルを取得
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                if let image = UIImage(data: data) {
                    customThumbnailImage = image
                    originalImage = image
                    selectedThumbnailData = data
                }
            } catch {
            }
        }
        
        isGeneratingThumbnails = false
    }
    
    // 調整値変更時にサムネイルデータを更新
    private func updateThumbnailData() {
        guard let image = originalImage else { return }
        let adjustedImage = resizeImageWithAdjustments(image)
        selectedThumbnailData = adjustedImage.jpegData(compressionQuality: 0.8)
    }
    
    // 調整値を適用して画像をリサイズ
    private func resizeImageWithAdjustments(_ image: UIImage) -> UIImage {
        let targetSize = CGSize(width: thumbnailWidth, height: thumbnailHeight)
        
        // デバッグログ
        print("🎨 [ThumbnailPicker] Applying adjustments - Scale: \(thumbnailScale), OffsetX: \(thumbnailOffsetX), OffsetY: \(thumbnailOffsetY)")
        
        // リサイズ実行
        UIGraphicsBeginImageContextWithOptions(targetSize, true, 0.0)
        
        // 背景を黒で塗りつぶす
        UIColor.black.setFill()
        UIRectFill(CGRect(origin: .zero, size: targetSize))
        
        // 元画像のアスペクト比を保持しながら、ターゲットサイズに収まる最大サイズを計算
        let imageAspectRatio = image.size.width / image.size.height
        let targetAspectRatio = targetSize.width / targetSize.height
        
        var drawWidth: CGFloat
        var drawHeight: CGFloat
        
        if imageAspectRatio > targetAspectRatio {
            // 画像の方が横長
            drawWidth = targetSize.width
            drawHeight = targetSize.width / imageAspectRatio
        } else {
            // 画像の方が縦長
            drawHeight = targetSize.height
            drawWidth = targetSize.height * imageAspectRatio
        }
        
        // スケールを適用
        drawWidth *= thumbnailScale
        drawHeight *= thumbnailScale
        
        // 中央配置のための基本オフセット
        let baseX = (targetSize.width - drawWidth) / 2.0
        let baseY = (targetSize.height - drawHeight) / 2.0
        
        // ユーザー調整を追加（調整値のスケールを補正）
        let x = baseX + thumbnailOffsetX
        let y = baseY + thumbnailOffsetY
        
        image.draw(in: CGRect(
            x: x,
            y: y,
            width: drawWidth,
            height: drawHeight
        ))
        
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        print("🎨 [ThumbnailPicker] Final draw rect - X: \(x), Y: \(y), Width: \(drawWidth), Height: \(drawHeight)")
        
        return resizedImage ?? image
    }
    
    // アスペクト比を保持して画像をリサイズ（旧メソッド、互換性のため残す）
    private func resizeImageWithAspectRatio(_ image: UIImage) -> UIImage {
        let originalSize = image.size
        let targetSize = CGSize(width: thumbnailWidth, height: thumbnailHeight)
        
        // アスペクト比を計算
        let widthRatio = targetSize.width / originalSize.width
        let heightRatio = targetSize.height / originalSize.height
        
        // アスペクトフィット: 画像全体が表示されるようにリサイズ
        let scaleFactor = min(widthRatio, heightRatio)
        let scaledSize = CGSize(
            width: originalSize.width * scaleFactor,
            height: originalSize.height * scaleFactor
        )
        
        // 中央に配置するためのオフセットを計算
        let xOffset = (targetSize.width - scaledSize.width) / 2.0
        let yOffset = (targetSize.height - scaledSize.height) / 2.0
        
        // リサイズ実行
        UIGraphicsBeginImageContextWithOptions(targetSize, true, 0.0)
        
        // 背景を黒で塗りつぶす
        UIColor.black.setFill()
        UIRectFill(CGRect(origin: .zero, size: targetSize))
        
        // 画像を中央に描画
        image.draw(in: CGRect(
            x: xOffset,
            y: yOffset,
            width: scaledSize.width,
            height: scaledSize.height
        ))
        
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return resizedImage ?? image
    }
}