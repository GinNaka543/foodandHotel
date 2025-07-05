import SwiftUI
import PhotosUI

struct AddPhotoView: View {
    @Binding var selectedImage: UIImage?
    @Binding var photoTitle: String
    @Binding var photoTags: String
    let onSave: () -> Void
    var onPixivSave: ((String, String, String?, String) -> Void)? = nil
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingImagePicker = false
    @State private var selectedItem: PhotosPickerItem?
    @State private var showPixivInput = false
    @State private var pixivURL = ""
    @State private var pixivTitle = ""
    @State private var pixivTags = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 画像プレビュー
                if let image = selectedImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                        .cornerRadius(12)
                } else {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 200)
                        .overlay(
                            VStack {
                                Image(systemName: "photo")
                                    .font(.largeTitle)
                                    .foregroundColor(.gray)
                                Text("画像を選択")
                                    .foregroundColor(.gray)
                            }
                        )
                }
                
                // 画像選択ボタン
                PhotosPicker(selection: $selectedItem, matching: .images) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                        Text("画像を選択")
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
                    
                    TextField("タイトルを入力", text: $photoTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                // タグ入力
                VStack(alignment: .leading, spacing: 8) {
                    Text("タグ（カンマ区切り）")
                        .font(.headline)
                    
                    TextField("タグを入力", text: $photoTags)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                // Pixiv URL入力ボタン
                Button(action: { showPixivInput = true }) {
                    HStack {
                        Image(systemName: "link")
                        Text("Pixiv URLから追加")
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.orange)
                    .cornerRadius(12)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("写真を追加")
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
                    .disabled(selectedImage == nil)
                }
            }
        }
        .onChange(of: selectedItem) { oldValue, newValue in
            Task {
                if let data = try? await newValue?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                }
            }
        }
        .sheet(isPresented: $showPixivInput) {
            NavigationView {
                VStack(spacing: 20) {
                    Text("Pixiv作品を追加")
                        .font(.headline)
                        .padding(.top)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pixiv URL")
                            .font(.caption)
                            .foregroundColor(.gray)
                        TextField("https://www.pixiv.net/artworks/...", text: $pixivURL)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("タイトル")
                            .font(.caption)
                            .foregroundColor(.gray)
                        TextField("作品タイトル", text: $pixivTitle)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("タグ（カンマ区切り）")
                            .font(.caption)
                            .foregroundColor(.gray)
                        TextField("タグ1,タグ2,タグ3", text: $pixivTags)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    Spacer()
                }
                .padding()
                .navigationTitle("Pixiv作品")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("キャンセル") {
                            showPixivInput = false
                            pixivURL = ""
                            pixivTitle = ""
                            pixivTags = ""
                        }
                    }
                    
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("保存") {
                            if let onPixivSave = onPixivSave,
                               !pixivURL.isEmpty,
                               !pixivTitle.isEmpty {
                                onPixivSave(pixivURL, pixivTitle, nil, pixivTags)
                                dismiss()
                            }
                        }
                        .disabled(pixivURL.isEmpty || pixivTitle.isEmpty)
                    }
                }
            }
        }
    }
}

#Preview {
    AddPhotoView(
        selectedImage: .constant(nil),
        photoTitle: .constant(""),
        photoTags: .constant(""),
        onSave: {}
    )
} 