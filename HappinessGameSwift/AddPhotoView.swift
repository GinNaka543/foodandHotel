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
            Text(NSLocalizedString("upload_method_select", comment: "Select upload method"))
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
                        
                        Text(NSLocalizedString("add_from_pixiv_url", comment: "Add from Pixiv URL"))
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(NSLocalizedString("pixiv_url_description", comment: "Enter Pixiv artwork URL to automatically retrieve information"))
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
                        
                        Text(NSLocalizedString("manual_upload", comment: "Manual upload"))
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(NSLocalizedString("manual_upload_description", comment: "Select image from device and manually enter information"))
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
        .navigationTitle(NSLocalizedString("add_photo", comment: "Add Photo"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button(NSLocalizedString("cancel", comment: "Cancel")) {
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
                        TextField(NSLocalizedString("enter_url", comment: "Enter URL"), text: $pixivURL)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .foregroundColor(.primary)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("title", comment: "Title"))
                            .font(.headline)
                        TextField(NSLocalizedString("artwork_title", comment: "Artwork title"), text: $pixivTitle)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("tags_comma_separated", comment: "Tags (comma separated)"))
                            .font(.headline)
                        TextField(NSLocalizedString("tags_placeholder", comment: "tag1,tag2,tag3"), text: $pixivTags)
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
                                    Text(NSLocalizedString("select_image", comment: "Select Image"))
                                        .foregroundColor(.gray)
                                }
                            )
                    }
                    
                    // 画像選択ボタン
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                            Text(NSLocalizedString("select_image", comment: "Select Image"))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    
                    // タイトル入力
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("title", comment: "Title"))
                            .font(.headline)
                        
                        TextField(NSLocalizedString("enter_title", comment: "Enter title"), text: $photoTitle)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    // タグ入力
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("tags_comma_separated", comment: "Tags (comma separated)"))
                            .font(.headline)
                        
                        TextField(NSLocalizedString("enter_tags", comment: "Enter tags"), text: $photoTags)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                    
                    Spacer()
                }
            }
        }
        .padding()
        .navigationTitle(selectedUploadMethod == .pixiv ? NSLocalizedString("add_pixiv_artwork", comment: "Add Pixiv Artwork") : NSLocalizedString("add_photo", comment: "Add Photo"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("back", comment: "Back")) {
                        if selectedUploadMethod != nil {
                            selectedUploadMethod = nil
                            showUploadMethodSelection = true
                        } else {
                            dismiss()
                        }
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("save", comment: "Save")) {
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