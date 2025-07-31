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
    @State private var editText = ""
    @State private var showDeleteAlert = false
    
    var body: some View {
        
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
                            Button(action: {
                                showEditMenu = true
                            }) {
                                Text(NSLocalizedString("edit", comment: "Edit"))
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
                            if let thumbnailData = artwork?.customThumbnailData,
                               let uiImage = UIImage(data: thumbnailData) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 200)
                                    .cornerRadius(12)
                                    .padding(.horizontal)
                            } else {
                                PixivThumbnailView(pixivURL: pixivURL)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 200)
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
                                    Text(NSLocalizedString("open_in_pixiv", comment: "Open in Pixiv"))
                                        .font(.headline)
                                }
                                .foregroundColor(.white)
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(Color.blue)
                                .cornerRadius(12)
                                .padding(.horizontal)
                            }
                            
                            Text(NSLocalizedString("pixiv_image_source", comment: "This image is from Pixiv"))
                                .font(.caption)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal)
                            
                            Spacer(minLength: 50)
                        }
                        .frame(maxWidth: 600) // Limit width on iPad
                        .frame(maxWidth: .infinity)
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
                    Text(NSLocalizedString("select_edit_item", comment: "Select item to edit"))
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
                                Text(NSLocalizedString("edit_title", comment: "Edit title"))
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
                                Text(NSLocalizedString("edit_tags", comment: "Edit tags"))
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
                                Text(NSLocalizedString("delete_image", comment: "Delete image"))
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
                        Text(NSLocalizedString("cancel", comment: "Cancel"))
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
            Text(NSLocalizedString("edit_title_name", comment: "Edit title name"))
                .font(.headline)
                .padding(.top, 12)
            TextField(NSLocalizedString("title", comment: "Title"), text: $editText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.system(size: 18))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            HStack(spacing: 24) {
                Button(action: { showDialog = false }) {
                    Text(NSLocalizedString("cancel", comment: "Cancel"))
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                Button(action: {
                    onSave()
                    showDialog = false
                }) {
                    Text(NSLocalizedString("save", comment: "Save"))
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
            Text(NSLocalizedString("edit_tags", comment: "Edit tags"))
                .font(.headline)
                .padding(.top, 12)
            TextField(NSLocalizedString("tags_comma_separated", comment: "Tags (comma separated)"), text: $editText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.system(size: 18))
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            HStack(spacing: 24) {
                Button(action: { showDialog = false }) {
                    Text(NSLocalizedString("cancel", comment: "Cancel"))
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                Button(action: {
                    onSave()
                    showDialog = false
                }) {
                    Text(NSLocalizedString("save", comment: "Save"))
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
            Text(NSLocalizedString("confirm_delete", comment: "Are you sure you want to delete?"))
                .font(.headline)
                .padding(.top, 12)
            HStack(spacing: 24) {
                Button(action: {
                    showDialog = false
                }) {
                    Text(NSLocalizedString("cancel", comment: "Cancel"))
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                Button(action: {
                    onDelete()
                    showDialog = false
                }) {
                    Text(NSLocalizedString("delete", comment: "Delete"))
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

