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
    
    init(onSave: @escaping (Soundtrack) -> Void) {
        self.onSave = onSave
    }
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(NSLocalizedString("basic_info", comment: ""))) {
                    TextField(NSLocalizedString("title", comment: ""), text: $title)
                    TextField(NSLocalizedString("artist_optional", comment: ""), text: $artist)
                }
                
                Section(header: Text(NSLocalizedString("music_file", comment: ""))) {
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
                            Text(selectedAudioURL == nil ? NSLocalizedString("select_mp3_file", comment: "") : NSLocalizedString("select_another_file", comment: ""))
                        }
                    }
                }
                
                Section(header: Text(NSLocalizedString("thumbnail_image", comment: ""))) {
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
                            Text(selectedImage == nil ? NSLocalizedString("select_image", comment: "") : NSLocalizedString("change_image", comment: ""))
                        }
                    }
                }
                
            }
            .navigationTitle(NSLocalizedString("add_soundtrack", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("cancel", comment: "")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("save", comment: "")) {
                        saveSoundtrack()
                    }
                    .disabled(title.isEmpty || selectedAudioURL == nil)
                }
            }
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker(fileURL: $selectedAudioURL)
        }
        .photosPicker(isPresented: $showingImagePicker, selection: $imagePickerItem, matching: .images)
        .onChange(of: imagePickerItem) { newValue in
            if let newValue = newValue {
                Task {
                    if let data = try? await newValue.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        selectedImage = image
                        showingImagePicker = false
                    }
                }
            }
        }
        .onAppear {
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
                }
            }
        }
    }
}