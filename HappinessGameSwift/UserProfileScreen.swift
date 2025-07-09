import SwiftUI
import PhotosUI


struct UserProfileScreen: View {
    @StateObject private var profileManager = UserProfileManager()
    @State private var username: String = ""
    @State private var selectedIconItem: PhotosPickerItem?
    @State private var iconImage: UIImage?
    @State private var showingSaveAlert = false
    @State private var isEditing = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // プロファイルヘッダー
                    VStack(spacing: 16) {
                        // アイコン画像
                        PhotosPicker(selection: $selectedIconItem, matching: .images) {
                            ZStack {
                                if let iconImage = iconImage {
                                    Image(uiImage: iconImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 120, height: 120)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(Color.blue, lineWidth: 3)
                                        )
                                } else if let imagePath = profileManager.currentUser.iconImagePath,
                                          let uiImage = UIImage(contentsOfFile: imagePath) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 120, height: 120)
                                        .clipShape(Circle())
                                        .overlay(
                                            Circle()
                                                .stroke(Color.blue, lineWidth: 3)
                                        )
                                } else {
                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 120, height: 120)
                                        .overlay(
                                            Image(systemName: "person.fill")
                                                .font(.system(size: 50))
                                                .foregroundColor(.gray)
                                        )
                                        .overlay(
                                            Circle()
                                                .stroke(Color.blue, lineWidth: 3)
                                        )
                                }
                                
                                // 編集アイコン
                                if isEditing {
                                    Circle()
                                        .fill(Color.black.opacity(0.5))
                                        .frame(width: 120, height: 120)
                                        .overlay(
                                            Image(systemName: "camera.fill")
                                                .font(.system(size: 30))
                                                .foregroundColor(.white)
                                        )
                                }
                            }
                        }
                        .disabled(!isEditing)
                        .onChange(of: selectedIconItem) { _ in
                            Task {
                                if let data = try? await selectedIconItem?.loadTransferable(type: Data.self),
                                   let uiImage = UIImage(data: data) {
                                    iconImage = uiImage
                                }
                            }
                        }
                        
                        // ユーザー名
                        if isEditing {
                            TextField("ユーザー名を入力", text: $username)
                                .font(.system(size: 24, weight: .semibold))
                                .multilineTextAlignment(.center)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .frame(maxWidth: 250)
                        } else {
                            Text(profileManager.currentUser.username.isEmpty ? "ユーザー名未設定" : profileManager.currentUser.username)
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundColor(profileManager.currentUser.username.isEmpty ? .gray : .primary)
                        }
                        
                        // ユーザーID
                        Text("ID: \(profileManager.currentUser.id.prefix(8))...")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 20)
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // お気に入り情報
                    VStack(alignment: .leading, spacing: 20) {
                        // 誕生日
                        VStack(alignment: .leading, spacing: 8) {
                            Label("誕生日", systemImage: "calendar")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            if let birthday = profileManager.currentUser.birthday {
                                Text(DateFormatter.japaneseDate.string(from: birthday))
                                    .font(.system(size: 16))
                                    .padding(.leading, 28)
                            } else {
                                Text("まだ登録されていません")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                    .padding(.leading, 28)
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    
                    Spacer(minLength: 20)
                }
            }
            .navigationTitle("プロファイル")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(isEditing ? "保存" : "編集") {
                        if isEditing {
                            saveProfile()
                        } else {
                            username = profileManager.currentUser.username
                            isEditing = true
                        }
                    }
                }
            }
        }
        .alert("保存しました", isPresented: $showingSaveAlert) {
            Button("OK") { }
        }
        .onAppear {
            username = profileManager.currentUser.username
        }
    }
    
    private func saveProfile() {
        profileManager.currentUser.username = username
        
        // アイコン画像を保存
        if let iconImage = iconImage {
            let fileName = "user_icon_\(profileManager.currentUser.id).png"
            if let imagePath = saveImageToDocuments(iconImage, fileName: fileName) {
                profileManager.currentUser.iconImagePath = imagePath
            }
        }
        
        profileManager.saveProfile()
        isEditing = false
        showingSaveAlert = true
        
        // Firebaseに同期（後で実装）
        // syncToFirebase()
    }
}

struct StatBox: View {
    let title: String
    let count: Int
    let icon: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(.blue)
            Text("\(count)")
                .font(.system(size: 20, weight: .semibold))
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}