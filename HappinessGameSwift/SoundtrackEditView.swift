import SwiftUI
import AVFoundation
import UniformTypeIdentifiers
import PhotosUI

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
    @State private var imagePickerItem: PhotosPickerItem? = nil
    
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
            PhotosPicker(selection: $imagePickerItem, matching: .images) {
                VStack(spacing: 20) {
                    Text("画像を選択")
                        .font(.headline)
                    
                    if let selectedImage = selectedImage {
                        Image(uiImage: selectedImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 150, height: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    Button("画像を選択") {
                        // PhotosPickerが自動で処理
                    }
                    .padding()
                    .background(Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    
                    Button("キャンセル") {
                        showingImagePicker = false
                        imagePickerItem = nil
                    }
                    .foregroundColor(.red)
                }
                .padding()
            }
            .onChange(of: imagePickerItem) { newValue in
                if let newValue = newValue {
                    Task {
                        if let data = try? await newValue.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            selectedImage = image
                        }
                    }
                }
            }
        }
        .onDisappear {
            audioPlayer?.stop()
        }
        .onChange(of: selectedAudioURL) { newValue in
            if let url = newValue {
                do {
                    let data = try Data(contentsOf: url)
                    audioPlayer = try AVAudioPlayer(data: data)
                    audioPlayer?.prepareToPlay()
                } catch {
                    print("オーディオプレイヤーの作成に失敗: \(error)")
                }
            }
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
                } catch {
                    print("ファイルのコピーに失敗: \(error)")
                }
            }
        }
    }
}