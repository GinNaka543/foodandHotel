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
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingVideoPicker = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var player: AVPlayer?
    @State private var thumbnailImages: [UIImage] = []
    @State private var selectedThumbnailIndex: Int = 0
    @State private var isExporting = false
    @State private var exportError: String? = nil
    
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