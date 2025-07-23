import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

struct SoundtrackEditView: View {
    @Environment(\.dismiss) var dismiss
    @State private var title = ""
    @State private var artist = ""
    @State private var selectedAudioURL: URL?
    @State private var selectedImage: UIImage?
    @State private var showingDocumentPicker = false
    @State private var showingImagePicker = false
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = false
    
    var onSave: (Soundtrack) -> Void
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text("基本情報")) {
                    TextField("タイトル", text: $title)
                    TextField("アーティスト (任意)", text: $artist)
                }
                
                Section(header: Text("音楽ファイル")) {
                    if let url = selectedAudioURL {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(url.lastPathComponent)
                                    .font(.system(size: 14, weight: .medium))
                                if let player = audioPlayer {
                                    Text("\(formatTime(player.duration))")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            Spacer()
                            
                            Button(action: togglePlayback) {
                                Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.purple)
                            }
                        }
                        .padding(.vertical, 8)
                    }
                    
                    Button(action: {
                        showingDocumentPicker = true
                    }) {
                        HStack {
                            Image(systemName: "music.note")
                                .foregroundColor(.purple)
                            Text(selectedAudioURL == nil ? "MP3ファイルを選択" : "別のファイルを選択")
                        }
                    }
                }
                
                Section(header: Text("サムネイル画像")) {
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 200)
                            .cornerRadius(12)
                            .onTapGesture {
                                showingImagePicker = true
                            }
                    }
                    
                    Button(action: {
                        showingImagePicker = true
                    }) {
                        HStack {
                            Image(systemName: "photo")
                                .foregroundColor(.purple)
                            Text(selectedImage == nil ? "画像を選択" : "画像を変更")
                        }
                    }
                }
            }
            .navigationTitle("サントラを編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("保存") {
                        saveSoundtrack()
                    }
                    .disabled(title.isEmpty || selectedAudioURL == nil)
                }
            }
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker(fileURL: $selectedAudioURL)
        }
        .sheet(isPresented: $showingImagePicker) {
            ImagePicker(image: $selectedImage)
        }
        .onDisappear {
            audioPlayer?.stop()
        }
    }
    
    private func togglePlayback() {
        if isPlaying {
            audioPlayer?.pause()
            isPlaying = false
        } else {
            audioPlayer?.play()
            isPlaying = true
        }
    }
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func saveSoundtrack() {
        guard let audioURL = selectedAudioURL,
              let audioData = try? Data(contentsOf: audioURL) else { return }
        
        let soundtrack = Soundtrack(
            title: title,
            audioData: audioData,
            thumbnailData: selectedImage?.jpegData(compressionQuality: 0.8),
            duration: audioPlayer?.duration,
            artist: artist.isEmpty ? nil : artist
        )
        
        onSave(soundtrack)
        dismiss()
    }
}

// ドキュメントピッカー
struct DocumentPicker: UIViewControllerRepresentable {
    @Binding var fileURL: URL?
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.audio])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPicker
        
        init(_ parent: DocumentPicker) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            
            // ファイルへのアクセス権を取得
            if url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                
                // 一時的な場所にコピー
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(url.lastPathComponent)
                try? FileManager.default.removeItem(at: tempURL) // 既存のファイルを削除
                
                do {
                    try FileManager.default.copyItem(at: url, to: tempURL)
                    parent.fileURL = tempURL
                    
                    // オーディオプレイヤーを作成
                    if let viewController = controller.presentingViewController as? UIHostingController<SoundtrackEditView> {
                        // SwiftUIビューにアクセスして音楽プレイヤーを設定
                        DispatchQueue.main.async {
                            // ここでプレイヤーを設定する処理を追加
                        }
                    }
                } catch {
                    print("ファイルのコピーに失敗: \(error)")
                }
            }
        }
    }
}