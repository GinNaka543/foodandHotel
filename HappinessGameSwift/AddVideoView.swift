import SwiftUI
import PhotosUI
import AVKit

struct AddVideoView: View {
    @Binding var selectedVideoURL: URL?
    @Binding var videoTitle: String
    @Binding var videoTags: String
    let onSave: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingVideoPicker = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var player: AVPlayer?
    
    var body: some View {
        NavigationView {
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
                
                Spacer()
            }
            .padding()
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
                        onSave()
                    }
                    .disabled(selectedVideoURL == nil)
                }
            }
        }
        .onChange(of: selectedItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mov")
                    do {
                        try data.write(to: tempURL)
                        selectedVideoURL = tempURL
                        player = AVPlayer(url: tempURL)
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
}

#Preview {
    AddVideoView(
        selectedVideoURL: .constant(nil),
        videoTitle: .constant(""),
        videoTags: .constant(""),
        onSave: {}
    )
} 