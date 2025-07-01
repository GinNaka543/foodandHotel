import SwiftUI
import PhotosUI

struct AddPhotoView: View {
    @Binding var selectedImage: UIImage?
    @Binding var photoTitle: String
    @Binding var photoTags: String
    let onSave: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    @State private var showingImagePicker = false
    @State private var selectedItem: PhotosPickerItem?
    
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
        .onChange(of: selectedItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
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