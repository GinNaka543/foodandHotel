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
    @State private var showUploadMethodSelection = true
    @State private var selectedUploadMethod: UploadMethod?
    
    enum UploadMethod {
        case pixiv
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
                // Pixiv URLから追加
                Button(action: {
                    selectedUploadMethod = .pixiv
                    showUploadMethodSelection = false
                    showPixivInput = true
                }) {
                    VStack(spacing: 12) {
                        Image(systemName: "link.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.orange)
                        
                        Text("Pixiv URLから追加")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Pixiv作品のURLを入力して\n自動で情報を取得します")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.orange, lineWidth: 2)
                    )
                }
                
                // 手動アップロード
                Button(action: {
                    selectedUploadMethod = .manual
                    showUploadMethodSelection = false
                }) {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.blue)
                        
                        Text("手動でアップロード")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("デバイスから画像を選択して\n手動で情報を入力します")
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
            
            Spacer()
        }
        .navigationTitle("写真を追加")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("キャンセル") {
                    dismiss()
                }
            }
        }
    }
    
    var uploadContentView: some View {
        VStack(spacing: 20) {
            if selectedUploadMethod == .pixiv {
                // Pixiv URL専用UI
                VStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pixiv URL")
                            .font(.headline)
                        TextField("https://www.pixiv.net/artworks/...", text: $pixivURL)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .foregroundColor(.primary)
                            .accentColor(.gray)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("タイトル")
                            .font(.headline)
                        TextField("作品タイトル", text: $pixivTitle)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("タグ（カンマ区切り）")
                            .font(.headline)
                        TextField("タグ1,タグ2,タグ3", text: $pixivTags)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    Spacer()
                }
            } else {
                // 手動アップロード用UI
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
            }
        }
        .padding()
        .navigationTitle(selectedUploadMethod == .pixiv ? "Pixiv作品を追加" : "写真を追加")
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
                        if selectedUploadMethod == .pixiv {
                            // Pixiv URLの保存処理
                            if let onPixivSave = onPixivSave,
                               !pixivURL.isEmpty,
                               !pixivTitle.isEmpty {
                                onPixivSave(pixivURL, pixivTitle, nil, pixivTags)
                                dismiss()
                            }
                        } else {
                            // 手動アップロードの保存処理
                            onSave()
                        }
                    }
                    .disabled(selectedUploadMethod == .pixiv ? 
                             (pixivURL.isEmpty || pixivTitle.isEmpty) : 
                             (selectedImage == nil))
                }
            }
            .onChange(of: selectedItem) { newValue in
                Task {
                    if let data = try? await newValue?.loadTransferable(type: Data.self),
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