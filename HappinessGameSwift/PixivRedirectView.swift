import SwiftUI
import PhotosUI

struct PixivRedirectView: View {
    let pixivURL: String
    var artwork: Artwork? = nil
    var onEdit: ((String, [String]) -> Void)? = nil
    var onDelete: (() -> Void)? = nil
    var onThumbnailUpdate: ((Data?) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var showEditMenu = false
    @State private var showEditTitle = false
    @State private var showEditTags = false
    @State private var showThumbnailPicker = false
    @State private var editText = ""
    @State private var showDeleteAlert = false
    
    var body: some View {
        let _ = print("[DEBUG] PixivRedirectView body実行")
        let _ = print("[DEBUG] pixivURL: \(pixivURL)")
        let _ = print("[DEBUG] artwork: \(artwork?.title ?? "nil")")
        let _ = print("[DEBUG] artwork ID: \(artwork?.id.uuidString ?? "nil")")
        let _ = print("[DEBUG] onEdit: \(onEdit != nil)")
        let _ = print("[DEBUG] onDelete: \(onDelete != nil)")
        let _ = print("[DEBUG] onThumbnailUpdate: \(onThumbnailUpdate != nil)")
        
        ZStack {
            Color(.systemBackground).edgesIgnoringSafeArea(.all)
                
                VStack {
                    // Navigation bar with edit button
                    HStack {
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 20))
                                .foregroundColor(.primary)
                        }
                        .padding(.leading, 20)
                        
                        Spacer()
                        
                        if artwork != nil {
                            let _ = print("[DEBUG] 編集ボタンを表示")
                            Button(action: {
                                print("[DEBUG] 編集ボタンがクリックされました")
                                showEditMenu = true
                            }) {
                                Text("編集")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundColor(.blue)
                            }
                            .padding(.trailing, 20)
                        }
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 10)
                    
                    ScrollView {
                        VStack(spacing: 20) {
                            // Pixiv thumbnail display
                            if let customThumbnailData = artwork?.customThumbnailData,
                               let uiImage = UIImage(data: customThumbnailData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 300)
                                    .cornerRadius(12)
                                    .padding(.horizontal)
                            } else {
                                PixivThumbnailView(pixivURL: pixivURL)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 300)
                                    .cornerRadius(12)
                                    .padding(.horizontal)
                            }
                            
                            // Title
                            if let title = artwork?.title {
                                Text(title)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            
                            // Tags
                            if let tags = artwork?.tags, !tags.isEmpty {
                                Text(tags.map { "#\($0)" }.joined(separator: " "))
                                    .font(.subheadline)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                            
                            // Open in Pixiv button
                            Button(action: {
                                openPixivURL()
                            }) {
                                HStack {
                                    Image(systemName: "link.circle.fill")
                                        .font(.title2)
                                    Text("Pixivで開く")
                                        .font(.headline)
                                }
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }
                            
                            Text("この画像はPixivから取得されています")
                                .font(.caption)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            Spacer(minLength: 50)
                        }
                    }
                }
                
                // Edit menu
                if showEditMenu {
                Color.black.opacity(0.25)
                    .edgesIgnoringSafeArea(.all)
                    .onTapGesture {
                        showEditMenu = false
                    }
                
                VStack(spacing: 20) {
                    Text("編集する項目を選択")
                        .font(.headline)
                        .padding(.top, 20)
                    
                    VStack(spacing: 16) {
                        Button(action: {
                            editText = artwork?.title ?? ""
                            showEditMenu = false
                            showEditTitle = true
                        }) {
                            HStack {
                                Image(systemName: "pencil")
                                Text("タイトルを編集")
                                Spacer()
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                        }
                        .foregroundColor(.primary)
                        
                        Button(action: {
                            editText = artwork?.tags.joined(separator: ",") ?? ""
                            showEditMenu = false
                            showEditTags = true
                        }) {
                            HStack {
                                Image(systemName: "tag")
                                Text("タグを編集")
                                Spacer()
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                        }
                        .foregroundColor(.primary)
                        
                        Button(action: {
                            showEditMenu = false
                            showThumbnailPicker = true
                        }) {
                            HStack {
                                Image(systemName: "photo")
                                Text("サムネイルを変更")
                                Spacer()
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(10)
                        }
                        .foregroundColor(.primary)
                        
                        Button(action: {
                            showEditMenu = false
                            showDeleteAlert = true
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("画像を削除")
                                Spacer()
                            }
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(10)
                        }
                        .foregroundColor(.red)
                    }
                    .padding(.horizontal, 20)
                    
                    Button(action: {
                        showEditMenu = false
                    }) {
                        Text("キャンセル")
                            .foregroundColor(.blue)
                            .padding(.vertical, 10)
                    }
                    .padding(.bottom, 20)
                }
                .background(Color.white)
                .cornerRadius(18)
                .shadow(radius: 16)
                .frame(maxWidth: 340)
                .padding(.horizontal, 32)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            
            // Edit title dialog
            if showEditTitle {
                EditTitleDialog(
                    editText: $editText,
                    showDialog: $showEditTitle,
                    onSave: {
                        onEdit?(editText, artwork?.tags ?? [])
                    }
                )
            }
            
            // Edit tags dialog
            if showEditTags {
                EditTagsDialog(
                    editText: $editText,
                    showDialog: $showEditTags,
                    onSave: {
                        let tags = editText.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                        onEdit?(artwork?.title ?? "", tags)
                    }
                )
            }
            
            // Delete alert
            if showDeleteAlert {
                DeleteAlertDialog(
                    showDialog: $showDeleteAlert,
                    onDelete: {
                        onDelete?()
                        dismiss()
                    }
                )
            }
        }
        .sheet(isPresented: $showThumbnailPicker) {
            if let artwork = artwork {
                ArtworkThumbnailPickerView(
                    artwork: artwork,
                    onSave: { newThumbnailData in
                        onThumbnailUpdate?(newThumbnailData)
                        showThumbnailPicker = false
                    },
                    onCancel: {
                        showThumbnailPicker = false
                    }
                )
            }
        }
    }
    
    private func openPixivURL() {
        // Force open the URL even if it's the same as another artwork
        guard let url = URL(string: pixivURL) else { return }
        
        // Use openURL with options to ensure it always opens
        UIApplication.shared.open(url, options: [:]) { success in
            if success {
                // Dismissを削除 - ユーザーが手動で閉じるまで画面を保持
                // これにより、Pixivから戻ってきた時も画面が正しく表示される
            }
        }
    }
}

// Dialog components
struct EditTitleDialog: View {
    @Binding var editText: String
    @Binding var showDialog: Bool
    let onSave: () -> Void
    
    var body: some View {
        Color.black.opacity(0.25)
            .edgesIgnoringSafeArea(.all)
        VStack(spacing: 20) {
            Text("タイトル名を編集")
                .font(.headline)
                .padding(.top, 12)
            TextField("タイトル", text: $editText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.system(size: 18))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            HStack(spacing: 24) {
                Button(action: { showDialog = false }) {
                    Text("キャンセル")
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                Button(action: {
                    onSave()
                    showDialog = false
                }) {
                    Text("保存")
                        .foregroundColor(.blue)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background(Color.white)
        .cornerRadius(18)
        .shadow(radius: 16)
        .frame(maxWidth: 340)
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

struct EditTagsDialog: View {
    @Binding var editText: String
    @Binding var showDialog: Bool
    let onSave: () -> Void
    
    var body: some View {
        Color.black.opacity(0.25)
            .edgesIgnoringSafeArea(.all)
        VStack(spacing: 20) {
            Text("タグを編集")
                .font(.headline)
                .padding(.top, 12)
            TextField("タグ（カンマ区切り）", text: $editText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.system(size: 18))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            HStack(spacing: 24) {
                Button(action: { showDialog = false }) {
                    Text("キャンセル")
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                Button(action: {
                    onSave()
                    showDialog = false
                }) {
                    Text("保存")
                        .foregroundColor(.blue)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background(Color.white)
        .cornerRadius(18)
        .shadow(radius: 16)
        .frame(maxWidth: 340)
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

struct DeleteAlertDialog: View {
    @Binding var showDialog: Bool
    let onDelete: () -> Void
    
    var body: some View {
        Color.black.opacity(0.25)
            .edgesIgnoringSafeArea(.all)
        VStack(spacing: 20) {
            Text("本当に削除しますか？")
                .font(.headline)
                .padding(.top, 12)
            HStack(spacing: 24) {
                Button(action: {
                    showDialog = false
                }) {
                    Text("キャンセル")
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                Button(action: {
                    onDelete()
                    showDialog = false
                }) {
                    Text("削除")
                        .foregroundColor(.red)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
        .background(Color.white)
        .cornerRadius(18)
        .shadow(radius: 16)
        .frame(maxWidth: 340)
        .padding(.horizontal, 32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}

struct ArtworkThumbnailPickerView: View {
    let artwork: Artwork
    let onSave: (Data?) -> Void
    let onCancel: () -> Void
    
    @State private var selectedImageItem: PhotosPickerItem?
    @State private var customThumbnailImage: UIImage?
    
    var body: some View {
        VStack(spacing: 20) {
                Text("サムネイルを選択")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                
                // 現在のサムネイル表示
                VStack {
                    Text("現在のサムネイル")
                        .font(.headline)
                    
                    if let customThumbnailImage = customThumbnailImage {
                        Image(uiImage: customThumbnailImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 200)
                            .cornerRadius(8)
                    } else if let existingThumbnailData = artwork.customThumbnailData,
                              let uiImage = UIImage(data: existingThumbnailData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 200)
                            .cornerRadius(8)
                    } else if let pixivURL = artwork.pixivURL {
                        PixivThumbnailView(pixivURL: pixivURL)
                            .frame(height: 200)
                            .cornerRadius(8)
                    } else if let imagePath = artwork.imagePath, let uiImage = loadImageFromPath(imagePath) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(height: 200)
                            .cornerRadius(8)
                    } else {
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: 200)
                            .cornerRadius(8)
                            .overlay(
                                Text("サムネイルなし")
                                    .foregroundColor(.gray)
                            )
                    }
                }
                .padding(.horizontal)
                
                // フォトライブラリから選択
                PhotosPicker(
                    selection: $selectedImageItem,
                    matching: .images
                ) {
                    HStack {
                        Image(systemName: "photo.on.rectangle")
                        Text("フォトライブラリから選択")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.blue)
                    .cornerRadius(10)
                }
                .padding(.horizontal)
                .onChange(of: selectedImageItem) { newItem in
                    Task {
                        if let item = newItem,
                           let data = try? await item.loadTransferable(type: Data.self),
                           let image = UIImage(data: data) {
                            customThumbnailImage = image
                        }
                    }
                }
                
                Spacer()
                
                // ボタンエリア
                HStack(spacing: 20) {
                    Button("キャンセル") {
                        onCancel()
                    }
                    .font(.headline)
                    .foregroundColor(.red)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(10)
                    
                    Button("保存") {
                        let thumbnailData = customThumbnailImage?.jpegData(compressionQuality: 0.8)
                        onSave(thumbnailData)
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(customThumbnailImage != nil ? Color.green : Color.gray)
                    .cornerRadius(10)
                    .disabled(customThumbnailImage == nil)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
    }
}