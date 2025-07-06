import SwiftUI
import Foundation
import PhotosUI

enum ListTab: Int {
    case chara, anime, birthday
}

// Temporary copy of UserProfile structures until UserProfileScreen.swift is added to project
struct UserProfile: Codable {
    var id: String = UUID().uuidString
    var username: String = ""
    var iconImagePath: String?
    var favoriteAnimes: [String] = []
    var favoriteCharacters: [String] = []
    var hashtags: [String] = []
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
}

class UserProfileManager: ObservableObject {
    @Published var currentUser: UserProfile
    private let userDefaultsKey = "currentUserProfile"
    
    init() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let user = try? JSONDecoder().decode(UserProfile.self, from: data) {
            self.currentUser = user
        } else {
            self.currentUser = UserProfile()
        }
    }
    
    func saveProfile() {
        currentUser.updatedAt = Date()
        if let data = try? JSONEncoder().encode(currentUser) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
    }
}

struct HomeScreen: View {
    @EnvironmentObject var mainTab: MainTabSelection
    @State private var showListPage = false
    @State private var initialTab: ListTab = .chara
    @StateObject private var characterManager = CharacterManager()
    @StateObject private var animeManager = AnimeManager()
    @StateObject private var profileManager = UserProfileManager()
    @State private var showingProfile = false
    
    // キャラクター名を30文字以内で表示する関数
    private func getCharacterNamesText() -> String {
        let names = characterManager.characters.map { $0.name }
        let joinedNames = names.joined(separator: ", ")
        if joinedNames.count <= 30 {
            return joinedNames.isEmpty ? "キャラクターが登録されていません" : joinedNames
        } else {
            let truncated = String(joinedNames.prefix(30))
            return truncated + "..."
        }
    }
    
    // アニメ名を30文字以内で表示する関数
    private func getAnimeNamesText() -> String {
        let names = animeManager.animes.map { $0.title }
        let joinedNames = names.joined(separator: ", ")
        if joinedNames.count <= 30 {
            return joinedNames.isEmpty ? "アニメが登録されていません" : joinedNames
        } else {
            let truncated = String(joinedNames.prefix(30))
            return truncated + "..."
        }
    }
    
    // バースデーリマインダー用のキャラクターを取得する関数
    private func getBirthdayReminderCharacters() -> [Character] {
        let calendar = Calendar.current
        let today = Date()
        
        // 5日前から3日後までの範囲を計算
        let fiveDaysAgo = calendar.date(byAdding: .day, value: -5, to: today) ?? today
        let threeDaysLater = calendar.date(byAdding: .day, value: 3, to: today) ?? today
        
        return characterManager.characters.filter { character in
            // 誕生日の月日を取得
            let birthdayMonth = calendar.component(.month, from: character.birthday)
            let birthdayDay = calendar.component(.day, from: character.birthday)
            
            // 今日の月日を取得（未使用のため削除）
            _ = calendar.component(.month, from: today)
            _ = calendar.component(.day, from: today)
            
            // 5日前の月日を取得
            let fiveDaysAgoMonth = calendar.component(.month, from: fiveDaysAgo)
            let fiveDaysAgoDay = calendar.component(.day, from: fiveDaysAgo)
            
            // 3日後の月日を取得
            let threeDaysLaterMonth = calendar.component(.month, from: threeDaysLater)
            let threeDaysLaterDay = calendar.component(.day, from: threeDaysLater)
            
            // 誕生日が範囲内かチェック（年を考慮せず月日のみで比較）
            let birthdayDate = calendar.date(from: DateComponents(year: 2000, month: birthdayMonth, day: birthdayDay)) ?? Date()
            let rangeStart = calendar.date(from: DateComponents(year: 2000, month: fiveDaysAgoMonth, day: fiveDaysAgoDay)) ?? Date()
            let rangeEnd = calendar.date(from: DateComponents(year: 2000, month: threeDaysLaterMonth, day: threeDaysLaterDay)) ?? Date()
            
            return birthdayDate >= rangeStart && birthdayDate <= rangeEnd
        }
    }
    
    // バースデーリマインダーの説明文を生成する関数
    private func getBirthdayReminderText() -> String {
        let reminderCharacters = getBirthdayReminderCharacters()
        if reminderCharacters.isEmpty {
            return ""
        }
        
        let names = reminderCharacters.map { $0.name }
        let joinedNames = names.joined(separator: ", ")
        if joinedNames.count <= 30 {
            return joinedNames
        } else {
            let truncated = String(joinedNames.prefix(30))
            return truncated + "..."
        }
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // ヘッダー
                HStack(alignment: .center) {
                    Button(action: {
                        showingProfile = true
                    }) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(profileManager.currentUser.username.isEmpty ? "中島 銀星" : profileManager.currentUser.username)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.primary)
                            Text("Enter a status message")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                    
                    // ユーザーアイコン
                    if let imagePath = profileManager.currentUser.iconImagePath,
                       let uiImage = UIImage(contentsOfFile: imagePath) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: "person.fill")
                                    .font(.system(size: 30))
                                    .foregroundColor(.gray.opacity(0.5))
                            )
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                // ステータスボタン
                HStack {
                    Button(action: {}) {
                        HStack(spacing: 6) {
                            Image(systemName: "music.note")
                                .foregroundColor(.green)
                            Text("Select music")
                                .font(.system(size: 14))
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                // 検索バー
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search", text: .constant(""))
                        .font(.system(size: 16))
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                // リスト
                VStack(alignment: .leading, spacing: 0) {
                    Text("Friend lists")
                        .font(.system(size: 18, weight: .bold))
                        .padding(.top, 16)
                        .padding(.bottom, 4)
                    
                    // バースデーリマインダー（該当するキャラクターがいる場合のみ表示）
                    if !getBirthdayReminderCharacters().isEmpty {
                        HStack {
                            FriendListIconView(
                                images: getBirthdayReminderCharacters().prefix(4).map { char in
                                    if let path = char.imageIdentifier, let img = UIImage(contentsOfFile: path) { return img } else { return nil }
                                },
                                fallbackSystemName: "person",
                                color: Color.gray.opacity(0.3)
                            )
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Birthday reminders")
                                    .font(.system(size: 16, weight: .semibold))
                                Text(getBirthdayReminderText())
                                    .font(.system(size: 13))
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Text("\(getBirthdayReminderCharacters().count)")
                                .font(.system(size: 14))
                                .foregroundColor(.gray)
                        }
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            initialTab = .birthday
                            showListPage = true
                        }
                    }
                    
                    // Characters
                    HStack {
                        FriendListIconView(
                            images: characterManager.characters.prefix(4).map { char in
                                if let path = char.imageIdentifier, let img = UIImage(contentsOfFile: path) { return img } else { return nil }
                            },
                            fallbackSystemName: "person",
                            color: Color.gray.opacity(0.3)
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Characters")
                                .font(.system(size: 16, weight: .semibold))
                            Text(getCharacterNamesText())
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Text("\(characterManager.characters.count)")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        initialTab = .chara
                        showListPage = true
                    }
                    
                    // Animes
                    HStack {
                        FriendListIconView(
                            images: animeManager.animes.prefix(4).map { anime in
                                if let path = anime.imageIdentifier, let img = UIImage(contentsOfFile: path) { return img } else { return nil }
                            },
                            fallbackSystemName: "film",
                            color: Color.gray.opacity(0.3)
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Animes")
                                .font(.system(size: 16, weight: .semibold))
                            Text(getAnimeNamesText())
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Text("\(animeManager.animes.count)")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        initialTab = .anime
                        showListPage = true
                    }
                }
                .padding(.horizontal, 20)
                // サービス
                VStack(alignment: .leading, spacing: 0) {
                    HStack {
                        Text("Recommend")
                            .font(.system(size: 18, weight: .bold))
                        Spacer()
                        Text("See all")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 4)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 24) {
                            ForEach(["LINE AI", "Stickers", "Themes", "LINE GIFT", "LINE POINT C", "LINE GAME"], id: \.self) { service in
                                VStack(spacing: 6) {
                                    Circle().stroke(Color.gray, lineWidth: 2).frame(width: 36, height: 36)
                                    Text(service)
                                        .font(.system(size: 12))
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                    }
                }
                .padding(.horizontal, 20)
                // インフォメーションタイトル
                HStack {
                    Text("Information")
                        .font(.system(size: 18, weight: .bold))
                    Spacer()
                }
                .padding(.top, 16)
                .padding(.horizontal, 20)

                // 広告バナー
                VStack(spacing: 0) {
                    if let bannerImage = UIImage(named: "青豚") {
                        Image(uiImage: bannerImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 360, height: 189)
                            .cornerRadius(10)
                            .clipped()
                            .padding(.top, 20)
                    }
                    if let kagImage = UIImage(named: "かぐや") {
                        Image(uiImage: kagImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 360, height: 189)
                            .cornerRadius(10)
                            .clipped()
                            .padding(.top, 16)
                    }
                }
                // ここに空行を追加しておくことで、Xcodeのキャッシュ対策になる場合があります。
            }
        }
        .background(Color.white)
        .fullScreenCover(isPresented: $showListPage) {
            ListPageScreen(
                selectedTab: initialTab,
                characters: characterManager.characters,
                animes: animeManager.animes,
                birthdays: getBirthdayReminderCharacters()
            )
        }
        .sheet(isPresented: $showingProfile) {
            // Temporary inline UserProfileScreen until file is added to project
            UserProfileScreenTemp()
                .environmentObject(profileManager)
        }
        .onAppear {
            characterManager.loadCharacters()
            animeManager.loadAnimes()
        }
    }
}

// フレンドリスト用アイコン分割View
struct FriendListIconView: View {
    let images: [UIImage?] // 最大4つまで
    let fallbackSystemName: String
    let color: Color
    var body: some View {
        ZStack {
            if images.count == 1 {
                iconImage(images[0], fallback: fallbackSystemName, color: color)
                    .frame(width: 40, height: 40)
                    .clipShape(Circle())
            } else if images.count == 2 {
                iconImage(images[0], fallback: fallbackSystemName, color: color)
                    .frame(width: 40, height: 40)
                    .clipShape(HalfCircleShape(left: true))
                iconImage(images[1], fallback: fallbackSystemName, color: color)
                    .frame(width: 40, height: 40)
                    .clipShape(HalfCircleShape(left: false))
                // 中央に白線
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 2, height: 40)
            } else if images.count == 3 {
                iconImage(images[0], fallback: fallbackSystemName, color: color)
                    .frame(width: 40, height: 40)
                    .clipShape(HalfCircleShape(left: true))
                iconImage(images[1], fallback: fallbackSystemName, color: color)
                    .frame(width: 40, height: 40)
                    .clipShape(QuarterCircleShape(position: .topRight))
                iconImage(images[2], fallback: fallbackSystemName, color: color)
                    .frame(width: 40, height: 40)
                    .clipShape(QuarterCircleShape(position: .bottomRight))
                // 中央に白線
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 2, height: 40)
                // 右半分の中央に水平白線
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 20, height: 2)
                    .position(x: 30, y: 20)
            } else if images.count >= 4 {
                iconImage(images[0], fallback: fallbackSystemName, color: color)
                    .frame(width: 40, height: 40)
                    .clipShape(QuarterCircleShape(position: .topLeft))
                iconImage(images[1], fallback: fallbackSystemName, color: color)
                    .frame(width: 40, height: 40)
                    .clipShape(QuarterCircleShape(position: .topRight))
                iconImage(images[2], fallback: fallbackSystemName, color: color)
                    .frame(width: 40, height: 40)
                    .clipShape(QuarterCircleShape(position: .bottomLeft))
                iconImage(images[3], fallback: fallbackSystemName, color: color)
                    .frame(width: 40, height: 40)
                    .clipShape(QuarterCircleShape(position: .bottomRight))
                // 十字に白線
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 2, height: 40)
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 40, height: 2)
            } else {
                Circle().fill(color)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Image(systemName: fallbackSystemName)
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                    )
            }
        }
        .frame(width: 40, height: 40)
    }
    func iconImage(_ image: UIImage?, fallback: String, color: Color) -> some View {
        Group {
            if let img = image {
                Image(uiImage: img)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                Circle().fill(color)
                    .overlay(
                        Image(systemName: fallback)
                            .font(.system(size: 20))
                            .foregroundColor(.gray)
                    )
            }
        }
    }
}

// 半円ClipShape
struct HalfCircleShape: Shape {
    let left: Bool
    func path(in rect: CGRect) -> Path {
        var path = Path()
        if left {
            path.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: rect.width/2, startAngle: .degrees(90), endAngle: .degrees(270), clockwise: false)
            path.addLine(to: CGPoint(x: rect.midX, y: rect.midY))
            path.closeSubpath()
        } else {
            path.addArc(center: CGPoint(x: rect.midX, y: rect.midY), radius: rect.width/2, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
            path.addLine(to: CGPoint(x: rect.midX, y: rect.midY))
            path.closeSubpath()
        }
        return path
    }
}

// 1/4円ClipShape
struct QuarterCircleShape: Shape {
    enum Position { case topLeft, topRight, bottomLeft, bottomRight }
    let position: Position
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let r = rect.width/2
        let center = CGPoint(x: rect.midX, y: rect.midY)
        switch position {
        case .topLeft:
            path.move(to: center)
            path.addArc(center: center, radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
            path.addLine(to: center)
        case .topRight:
            path.move(to: center)
            path.addArc(center: center, radius: r, startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false)
            path.addLine(to: center)
        case .bottomLeft:
            path.move(to: center)
            path.addArc(center: center, radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
            path.addLine(to: center)
        case .bottomRight:
            path.move(to: center)
            path.addArc(center: center, radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
            path.addLine(to: center)
        }
        path.closeSubpath()
        return path
    }
}

// プレビュー用
struct HomeScreen_Previews: PreviewProvider {
    static var previews: some View {
        HomeScreen()
    }
}

// Temporary UserProfileScreen implementation until UserProfileScreen.swift is added to project
struct UserProfileScreenTemp: View {
    @EnvironmentObject var profileManager: UserProfileManager
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
    }
}

 