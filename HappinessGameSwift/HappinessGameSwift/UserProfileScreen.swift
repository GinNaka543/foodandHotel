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
                        // お気に入りアニメ
                        VStack(alignment: .leading, spacing: 8) {
                            Label("お気に入りアニメ", systemImage: "tv")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            if profileManager.currentUser.favoriteAnimes.isEmpty {
                                Text("まだ登録されていません")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                    .padding(.leading, 28)
                            } else {
                                ForEach(profileManager.currentUser.favoriteAnimes, id: \.self) { anime in
                                    HStack {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12))
                                            .foregroundColor(.gray)
                                        Text(anime)
                                            .font(.system(size: 16))
                                    }
                                    .padding(.leading, 28)
                                }
                            }
                        }
                        
                        // お気に入りキャラクター
                        VStack(alignment: .leading, spacing: 8) {
                            Label("お気に入りキャラクター", systemImage: "person.3")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            if profileManager.currentUser.favoriteCharacters.isEmpty {
                                Text("まだ登録されていません")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                    .padding(.leading, 28)
                            } else {
                                ForEach(profileManager.currentUser.favoriteCharacters, id: \.self) { character in
                                    HStack {
                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 12))
                                            .foregroundColor(.gray)
                                        Text(character)
                                            .font(.system(size: 16))
                                    }
                                    .padding(.leading, 28)
                                }
                            }
                        }
                        
                        // ハッシュタグ
                        VStack(alignment: .leading, spacing: 8) {
                            Label("ハッシュタグ", systemImage: "number")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.primary)
                            
                            if profileManager.currentUser.hashtags.isEmpty {
                                Text("まだ登録されていません")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                                    .padding(.leading, 28)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        ForEach(profileManager.currentUser.hashtags, id: \.self) { tag in
                                            Text("#\(tag)")
                                                .font(.system(size: 14))
                                                .padding(.horizontal, 12)
                                                .padding(.vertical, 6)
                                                .background(Color.blue.opacity(0.1))
                                                .foregroundColor(.blue)
                                                .cornerRadius(15)
                                        }
                                    }
                                    .padding(.leading, 28)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    // 統計情報
                    VStack(spacing: 16) {
                        Text("統計")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                        
                        HStack(spacing: 20) {
                            StatBox(title: "アニメ", count: profileManager.currentUser.favoriteAnimes.count, icon: "tv")
                            StatBox(title: "キャラ", count: profileManager.currentUser.favoriteCharacters.count, icon: "person.3")
                            StatBox(title: "タグ", count: profileManager.currentUser.hashtags.count, icon: "number")
                        }
                        .padding(.horizontal)
                    }
                    .padding(.top, 20)
                    
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