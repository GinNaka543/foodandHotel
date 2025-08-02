import SwiftUI
import Foundation
import PhotosUI

extension DateFormatter {
    static let japaneseDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .none
        formatter.locale = Locale.current
        return formatter
    }()
}

enum ListTab: Int, CaseIterable {
    case chara = 0
    case anime = 1
    case birthday = 2
    
    var debugDescription: String {
        switch self {
        case .chara: return "chara"
        case .anime: return "anime"
        case .birthday: return "birthday"
        }
    }
}

// Temporary copy of UserProfile structures until UserProfileScreen.swift is added to project
struct UserProfile: Codable, Equatable {
    var id: String = UUID().uuidString
    var username: String = ""
    var iconImagePath: String?
    var birthday: Date?
    var animeQuote: String = ""
    var createdAt: Date = Date()
    var updatedAt: Date = Date()
    var favoriteVoiceActors: [String] = []
}

class UserProfileManager: ObservableObject {
    @Published var currentUser: UserProfile
    private let userDefaultsKey = "currentUserProfile"
    
    init() {
        // まずローカルから読み込み
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let user = try? JSONDecoder().decode(UserProfile.self, from: data) {
            self.currentUser = user
        } else {
            self.currentUser = UserProfile()
        }
        
        // ログイン済みの場合はFirebaseから最新データを取得
        if let userId = UserDefaults.standard.string(forKey: "userId"), !userId.isEmpty {
            loadFromFirebase(userId: userId)
        }
    }
    
    func loadFromFirebase(userId: String) {
        FirebaseManager.shared.loadUserProfile(userId: userId) { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let profile):
                    // 既存の画像パスを保持
                    let existingIconPath = self.currentUser.iconImagePath
                    self.currentUser = profile
                    // Firebaseから取得したプロファイルに画像パスがない場合は、既存のパスを復元
                    if profile.iconImagePath == nil && existingIconPath != nil {
                        self.currentUser.iconImagePath = existingIconPath
                    }
                    self.saveProfile()
                case .failure(_):
                    break
                }
            }
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
    @EnvironmentObject var authManager: AuthenticationManager
    @EnvironmentObject var characterManager: CharacterManager
    @EnvironmentObject var animeManager: AnimeManager
    @State private var showListPage = false
    @State private var selectedListTab: ListTab = .chara
    @State private var showCharacterList = false
    @State private var showAnimeList = false
    @State private var showBirthdayList = false
    @StateObject private var profileManager = UserProfileManager()
    @State private var showingProfile = false
    @State private var showingPoints = false
    @State private var hasLoadedData = false
    
    // リストページを表示する関数（現在未使用）
    /*
    private func showListPageWithTab(_ tab: ListTab) {
        
        selectedListTab = tab
        
        
        // 確実に値が設定されるように、メインスレッドで実行
        DispatchQueue.main.async { [self] in
            self.showListPage = true
        }
        
    }
    */
    
    // キャラクター名を30文字以内で表示する関数
    private func getCharacterNamesText() -> String {
        let names = characterManager.characters.filter { !$0.name.isEmpty }.map { $0.name }
        let joinedNames = names.joined(separator: ", ")
        if joinedNames.count <= 30 {
            return joinedNames.isEmpty ? NSLocalizedString("no_characters_registered", comment: "No characters registered") : joinedNames
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
            return joinedNames.isEmpty ? NSLocalizedString("no_anime_registered", comment: "No anime registered") : joinedNames
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
            // 名前が空の場合は除外
            guard !character.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                return false
            }
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
                            HStack(spacing: 8) {
                                Text(profileManager.currentUser.username.isEmpty ? "中島 銀星" : profileManager.currentUser.username)
                                    .font(.system(size: 25, weight: .bold)) // 28 * 0.9 ≒ 25
                                    .foregroundColor(.primary)
                                
                                // Premium user special icon
                                if UserDefaults.standard.bool(forKey: "isPremiumUser") {
                                    Image(systemName: "crown.fill")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundColor(.yellow)
                                        .shadow(color: .orange, radius: 2, x: 1, y: 1)
                                        .overlay(
                                            Image(systemName: "sparkles")
                                                .font(.system(size: 12))
                                                .foregroundColor(.white)
                                                .offset(x: -2, y: -2)
                                        )
                                }
                            }
                            Text(profileManager.currentUser.animeQuote.isEmpty ? NSLocalizedString("set_anime_quote", comment: "Set anime quote") : profileManager.currentUser.animeQuote)
                                .font(.system(size: 14)) // 16 * 0.9 ≒ 14
                                .foregroundColor(.gray)
                                .lineLimit(2)
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                    
                    // ユーザーアイコン
                    Button(action: {
                        showingProfile = true
                    }) {
                        if let imagePath = profileManager.currentUser.iconImagePath,
                           let uiImage = loadImageFromPath(imagePath) {
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
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal, 20)
                .padding(.top, 9)
                // ステータスボタン
                HStack {
                    Button(action: {
                        showingProfile = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "person.circle")
                                .foregroundColor(.blue)
                            Text(NSLocalizedString("profile_edit", comment: "Profile edit"))
                                .font(.system(size: 14))
                                .foregroundColor(.blue)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(.systemGray6))
                        .cornerRadius(16)
                    }
                    
                    Button(action: {
                        showingPoints = true
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "star.circle")
                                .foregroundColor(.purple)
                            Text(NSLocalizedString("points", comment: "Points"))
                                .font(.system(size: 14))
                                .foregroundColor(.purple)
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
                    TextField(NSLocalizedString("search", comment: "Search"), text: .constant(""))
                        .font(.system(size: 16))
                }
                .padding(10)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal, 20)
                .padding(.top, 12)
                // リスト
                VStack(alignment: .leading, spacing: 0) {
                    Text(NSLocalizedString("favorite_lists", comment: "Favorite lists"))
                        .font(.system(size: 19, weight: .bold))
                        .padding(.top, 16)
                        .padding(.bottom, 4)
                    
                    // バースデーリマインダー（該当するキャラクターがいる場合のみ表示）
                    if !getBirthdayReminderCharacters().isEmpty {
                        HStack {
                            FriendListIconView(
                                images: getBirthdayReminderCharacters().prefix(4).compactMap { char in
                                    if let path = char.imageIdentifier {
                                        return loadImageFromPath(path)
                                    }
                                    return nil
                                },
                                fallbackSystemName: "person",
                                color: Color.gray.opacity(0.3)
                            )
                            VStack(alignment: .leading, spacing: 2) {
                                Text(NSLocalizedString("birthday_reminders", comment: "Birthday reminders"))
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
                            showBirthdayList = true
                        }
                    }
                    
                    // Characters
                    HStack {
                        FriendListIconView(
                            images: characterManager.characters.filter { !$0.name.isEmpty }.prefix(4).compactMap { char in
                                if let path = char.imageIdentifier {
                                    return loadImageFromPath(path)
                                }
                                return nil
                            },
                            fallbackSystemName: "person",
                            color: Color.gray.opacity(0.3)
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(NSLocalizedString("characters", comment: "Characters"))
                                .font(.system(size: 16, weight: .semibold))
                            Text(getCharacterNamesText())
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Text("\(characterManager.characters.filter { !$0.name.isEmpty }.count)")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        showCharacterList = true
                    }
                    
                    // Animes
                    HStack {
                        FriendListIconView(
                            images: animeManager.animes.prefix(4).compactMap { anime in
                                if let path = anime.imageIdentifier {
                                    return loadImageFromPath(path)
                                }
                                return nil
                            },
                            fallbackSystemName: "film",
                            color: Color.gray.opacity(0.3)
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(NSLocalizedString("animes", comment: "Animes"))
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
                        showAnimeList = true
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                
                // スケジュールタイトル
                HStack {
                    Text(NSLocalizedString("schedule", comment: "Schedule"))
                        .font(.system(size: 19, weight: .bold))
                    Spacer()
                    Button(action: {
                        // ScheduleViewの中でshowingAddScheduleをトリガーする必要があるため、
                        // ScheduleViewに渡すための状態を追加
                        NotificationCenter.default.post(name: NSNotification.Name("ShowAddSchedule"), object: nil)
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.purple)
                    }
                }
                .padding(.horizontal, 20)

                // スケジュールビュー
                ScheduleView()
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 20)
                
                // 今日見るアニメセクション
                TodayAnimeScrollView()
                    .padding(.top, 1)
                    .padding(.bottom, 20)
                
            }
        }
        .background(Color.white)
        .fullScreenCover(isPresented: $showCharacterList) {
            ListPageScreen(
                selectedTab: .chara,
                characters: characterManager.characters.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
                animes: animeManager.animes,
                birthdays: getBirthdayReminderCharacters()
            )
            .environmentObject(characterManager)
            .environmentObject(animeManager)
        }
        .fullScreenCover(isPresented: $showAnimeList) {
            ListPageScreen(
                selectedTab: .anime,
                characters: characterManager.characters.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
                animes: animeManager.animes,
                birthdays: getBirthdayReminderCharacters()
            )
            .environmentObject(characterManager)
            .environmentObject(animeManager)
        }
        .fullScreenCover(isPresented: $showBirthdayList) {
            ListPageScreen(
                selectedTab: .birthday,
                characters: characterManager.characters.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty },
                animes: animeManager.animes,
                birthdays: getBirthdayReminderCharacters()
            )
            .environmentObject(characterManager)
            .environmentObject(animeManager)
        }
        .sheet(isPresented: $showingProfile) {
            // Temporary inline UserProfileScreen until file is added to project
            UserProfileScreenTemp()
                .environmentObject(profileManager)
        }
        .sheet(isPresented: $showingPoints) {
            PointsView()
        }
        .onAppear {
            if !hasLoadedData {
                characterManager.loadCharacters()
                animeManager.loadAnimes()
                hasLoadedData = true
                
                // DISABLED: Media cleanup causing video deletion issues
                // Run media cleanup after initial data load
                // DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                //     print("🧹 [HomeScreen] Triggering media cleanup...")
                //     MediaCleanupManager.shared.cleanupOrphanedMediaFiles()
                // }
            }
        }
    }
}

// フレンドリスト用アイコン分割View
struct FriendListIconView: View {
    let images: [UIImage?] // 最大4つまで
    let fallbackSystemName: String
    let color: Color
    var body: some View {
        #if DEBUG
        let _ = print("[FriendListIconView] 画像数: \(images.count), nilでない画像数: \(images.compactMap { $0 }.count)")
        #endif
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
// スケジュール管理用の構造体
struct ScheduleItem: Identifiable, Codable {
    var id: String = UUID().uuidString
    var date: Date
    var animeId: String
    var animeTitle: String
    var episode: Int?
    var note: String?
}

// スケジュールアイテムの行ビュー
struct ScheduleItemRow: View {
    let item: ScheduleItem
    let deleteAction: () -> Void
    @EnvironmentObject var animeManager: AnimeManager
    
    var body: some View {
        HStack(spacing: 12) {
            // アニメサムネイル
            if let anime = animeManager.animes.first(where: { $0.id.uuidString == item.animeId }),
               let imagePath = anime.imageIdentifier,
               let uiImage = loadImageFromPath(imagePath) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 60, height: 60)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.purple.opacity(0.3), lineWidth: 1)
                    )
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.purple.opacity(0.1))
                    .frame(width: 60, height: 60)
                    .overlay(
                        Image(systemName: "tv")
                            .font(.system(size: 24))
                            .foregroundColor(.purple.opacity(0.5))
                    )
            }
            
            // 日付
            VStack(spacing: 2) {
                Text(getMonthDay(from: item.date))
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray)
                Text(getDay(from: item.date))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.purple)
                Text(getWeekday(from: item.date))
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
            .frame(width: 50)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(item.animeTitle)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                
                if let episode = item.episode {
                    Text("第\(episode)話")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                }
                
                if let note = item.note, !note.isEmpty {
                    Text(note)
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            Button(action: deleteAction) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.gray.opacity(0.5))
            }
        }
        .padding(12)
    }
    
    private func getMonthDay(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "MMM", options: 0, locale: Locale.current)
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }
    
    private func getDay(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    private func getWeekday(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "E"
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }
}

// 空のスケジュールビュー
struct EmptyScheduleView: View {
    let showingAddSchedule: Binding<Bool>
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 40))
                .foregroundColor(.purple.opacity(0.6))
            
            Text(NSLocalizedString("schedule_empty", comment: "No schedules registered"))
                .font(.system(size: 16))
                .foregroundColor(.gray)
            
            Button(action: {
                showingAddSchedule.wrappedValue = true
            }) {
                Label(NSLocalizedString("schedule_add", comment: "Add schedule"), systemImage: "plus.circle.fill")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.purple)
                    .cornerRadius(20)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// スケジュールビュー
struct ScheduleView: View {
    @EnvironmentObject var animeManager: AnimeManager
    @State private var scheduleItems: [ScheduleItem] = []
    @State private var showingAddSchedule = false
    @State private var selectedDate = Date()
    @State private var selectedAnimeId: String = ""
    @State private var selectedAnimeIds: Set<String> = []
    @State private var episode: String = ""
    @State private var note: String = ""
    
    private let userDefaultsKey = "scheduleItems"
    
    var body: some View {
        VStack(spacing: 16) {
            if scheduleItems.isEmpty {
                EmptyScheduleView(showingAddSchedule: $showingAddSchedule)
            } else {
                ScheduleCalendarView(
                    scheduleItems: scheduleItems,
                    showingAddSchedule: $showingAddSchedule,
                    deleteAction: deleteScheduleItem,
                    animeManager: animeManager
                )
            }
        }
        .onAppear {
            loadScheduleItems()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowAddSchedule"))) { _ in
            showingAddSchedule = true
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AddScheduleItem"))) { notification in
            if let userInfo = notification.userInfo,
               let item = userInfo["item"] as? ScheduleItem {
                scheduleItems.append(item)
                saveScheduleItems()
            }
        }
        .sheet(isPresented: $showingAddSchedule) {
            MultiAddScheduleSheet(
                animeManager: animeManager,
                selectedDate: $selectedDate,
                selectedAnimeIds: $selectedAnimeIds,
                showingAddSchedule: $showingAddSchedule,
                addAction: addMultipleScheduleItems,
                resetAction: resetForm
            )
        }
    }
    
    private func getSelectedAnimeTitle() -> String {
        if selectedAnimeId.isEmpty {
            return NSLocalizedString("anime_select", comment: "Select anime")
        }
        return animeManager.animes.first(where: { $0.id.uuidString == selectedAnimeId })?.title ?? NSLocalizedString("anime_select", comment: "Select anime")
    }
    
    private func addScheduleItem() {
        guard !selectedAnimeId.isEmpty,
              let anime = animeManager.animes.first(where: { $0.id.uuidString == selectedAnimeId }) else { return }
        
        let newItem = ScheduleItem(
            date: selectedDate,
            animeId: selectedAnimeId,
            animeTitle: anime.title,
            episode: Int(episode),
            note: note.isEmpty ? nil : note
        )
        
        scheduleItems.append(newItem)
        saveScheduleItems()
        resetForm()
    }
    
    private func addMultipleScheduleItems() {
        for animeId in selectedAnimeIds {
            if let anime = animeManager.animes.first(where: { $0.id.uuidString == animeId }) {
                let newItem = ScheduleItem(
                    date: selectedDate,
                    animeId: animeId,
                    animeTitle: anime.title,
                    episode: nil,
                    note: nil
                )
                scheduleItems.append(newItem)
            }
        }
        saveScheduleItems()
        
        // スケジュール更新の通知を送信
        NotificationCenter.default.post(name: NSNotification.Name("ScheduleUpdated"), object: nil)
        
        resetForm()
    }
    
    private func deleteScheduleItem(_ item: ScheduleItem) {
        scheduleItems.removeAll(where: { $0.id == item.id })
        saveScheduleItems()
    }
    
    private func resetForm() {
        selectedDate = Date()
        selectedAnimeId = ""
        selectedAnimeIds = []
        episode = ""
        note = ""
    }
    
    private func loadScheduleItems() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let items = try? JSONDecoder().decode([ScheduleItem].self, from: data) {
            scheduleItems = items
        }
    }
    
    private func saveScheduleItems() {
        if let data = try? JSONEncoder().encode(scheduleItems) {
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        }
        
        // スケジュール更新の通知を送信
        NotificationCenter.default.post(name: NSNotification.Name("ScheduleUpdated"), object: nil)
    }
}

// カレンダー表示用の構造体
struct CalendarDay: Identifiable {
    let id = UUID()
    let date: Date
    let dayNumber: Int
    let isCurrentMonth: Bool
    let scheduleItems: [ScheduleItem]
}

// スケジュールカレンダービュー
struct ScheduleCalendarView: View {
    let scheduleItems: [ScheduleItem]
    let showingAddSchedule: Binding<Bool>
    let deleteAction: (ScheduleItem) -> Void
    let animeManager: AnimeManager
    
    @State private var selectedMonth = Date()
    @State private var selectedDate: Date?
    @State private var showingDayDetail = false
    @State private var showingAddScheduleForDate = false
    @State private var selectedDateForAdd: Date = Date()
    
    private let calendar = Calendar.current
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = DateFormatter.dateFormat(fromTemplate: "yyyyMMMM", options: 0, locale: Locale.current)
        formatter.locale = Locale.current
        return formatter
    }()
    
    private var calendarDays: [CalendarDay] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: selectedMonth) else {
            return []
        }
        
        var days: [CalendarDay] = []
        
        // 月の最初の日の曜日を取得
        let firstWeekday = calendar.component(.weekday, from: monthInterval.start) - 1
        
        // 前月の日付を追加
        if firstWeekday > 0 {
            let previousMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonth)!
            let previousMonthDays = calendar.range(of: .day, in: .month, for: previousMonth)!.count
            
            for i in (previousMonthDays - firstWeekday + 1)...previousMonthDays {
                if let date = calendar.date(byAdding: .day, value: i - previousMonthDays - 1, to: monthInterval.start) {
                    let items = scheduleItems.filter { calendar.isDate($0.date, inSameDayAs: date) }
                    days.append(CalendarDay(date: date, dayNumber: i, isCurrentMonth: false, scheduleItems: items))
                }
            }
        }
        
        // 当月の日付を追加
        let numberOfDays = calendar.range(of: .day, in: .month, for: selectedMonth)!.count
        for i in 1...numberOfDays {
            if let date = calendar.date(byAdding: .day, value: i - 1, to: monthInterval.start) {
                let items = scheduleItems.filter { calendar.isDate($0.date, inSameDayAs: date) }
                days.append(CalendarDay(date: date, dayNumber: i, isCurrentMonth: true, scheduleItems: items))
            }
        }
        
        // 次月の日付を追加（6週分になるように）
        let remainingDays = 42 - days.count
        for i in 1...remainingDays {
            if let nextMonth = calendar.date(byAdding: .month, value: 1, to: selectedMonth),
               let date = calendar.date(byAdding: .day, value: i - 1, to: calendar.dateInterval(of: .month, for: nextMonth)!.start) {
                let items = scheduleItems.filter { calendar.isDate($0.date, inSameDayAs: date) }
                days.append(CalendarDay(date: date, dayNumber: i, isCurrentMonth: false, scheduleItems: items))
            }
        }
        
        return days
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // 月の切り替えヘッダー
            HStack {
                Button(action: {
                    withAnimation {
                        selectedMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.purple)
                }
                
                Spacer()
                
                Text(dateFormatter.string(from: selectedMonth))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        selectedMonth = calendar.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.purple)
                }
            }
            .padding(.horizontal, 16)
            
            // 曜日ヘッダー
            HStack(spacing: 0) {
                ForEach(["日", "月", "火", "水", "木", "金", "土"], id: \.self) { weekday in
                    Text(weekday)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(weekday == "日" ? .red : weekday == "土" ? .blue : .gray)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 8)
            
            // カレンダーグリッド
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 4) {
                ForEach(calendarDays) { day in
                    CalendarDayCell(
                        day: day,
                        isToday: calendar.isDateInToday(day.date),
                        isSelected: selectedDate != nil && calendar.isDate(day.date, inSameDayAs: selectedDate!),
                        animeManager: animeManager
                    )
                    .onTapGesture {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            if !day.scheduleItems.isEmpty {
                                selectedDate = day.date
                                showingDayDetail = true
                            } else if day.isCurrentMonth {
                                // 空の日付をタップした場合、その日にスケジュールを追加
                                selectedDateForAdd = day.date
                                showingAddScheduleForDate = true
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 8)
        }
        .padding(.vertical, 8)
        .sheet(isPresented: $showingDayDetail) {
            if let date = selectedDate {
                DayScheduleDetailView(
                    date: date,
                    scheduleItems: scheduleItems.filter { calendar.isDate($0.date, inSameDayAs: date) },
                    animeManager: animeManager,
                    deleteAction: deleteAction
                )
            }
        }
        .sheet(isPresented: $showingAddScheduleForDate) {
            AddScheduleSheetForDate(
                animeManager: animeManager,
                selectedDate: selectedDateForAdd,
                onAdd: { anime, episode, note in
                    let newItem = ScheduleItem(
                        date: selectedDateForAdd,
                        animeId: anime.id.uuidString,
                        animeTitle: anime.title,
                        episode: episode,
                        note: note
                    )
                    // 親のScheduleViewにアイテムを追加する必要があるため、
                    // NotificationCenterを使用して通知
                    NotificationCenter.default.post(
                        name: NSNotification.Name("AddScheduleItem"),
                        object: nil,
                        userInfo: ["item": newItem]
                    )
                }
            )
        }
    }
}

// カレンダーの日付セル
struct CalendarDayCell: View {
    let day: CalendarDay
    let isToday: Bool
    let isSelected: Bool
    let animeManager: AnimeManager
    
    @ViewBuilder
    private var backgroundFill: some View {
        if isToday {
            LinearGradient(
                gradient: Gradient(colors: [Color.purple, Color.purple.opacity(0.8)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if isSelected {
            Color.purple.opacity(0.1)
        } else if !day.scheduleItems.isEmpty && day.isCurrentMonth {
            Color.purple.opacity(0.05)
        } else {
            Color.clear
        }
    }
    
    private var dayNumberColor: Color {
        if !day.isCurrentMonth {
            return .gray.opacity(0.5)
        } else if isToday {
            return .white
        } else {
            return .primary
        }
    }
    
    var body: some View {
        VStack(spacing: 2) {
            Text("\(day.dayNumber)")
                .font(.system(size: 14, weight: isToday ? .bold : .medium))
                .foregroundColor(dayNumberColor)
            
            // スケジュールインジケーター
            if !day.scheduleItems.isEmpty {
                HStack(spacing: 2) {
                    ForEach(day.scheduleItems.prefix(3)) { item in
                        ScheduleIndicator(item: item, animeManager: animeManager)
                    }
                }
                
                if day.scheduleItems.count > 3 {
                    Text("+\(day.scheduleItems.count - 3)")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(.purple)
                }
            }
        }
        .frame(height: 50)
        .frame(maxWidth: .infinity)
        .background(
            backgroundFill
                .clipShape(RoundedRectangle(cornerRadius: 8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.purple : Color.clear, lineWidth: 2)
        )
        .scaleEffect(!day.scheduleItems.isEmpty && day.isCurrentMonth ? 1.05 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// スケジュールインジケーター
struct ScheduleIndicator: View {
    let item: ScheduleItem
    let animeManager: AnimeManager
    
    var body: some View {
        if let anime = animeManager.animes.first(where: { $0.id.uuidString == item.animeId }),
           let imagePath = anime.imageIdentifier,
           let uiImage = loadImageFromPath(imagePath) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 12, height: 12)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 1)
                )
        } else {
            Circle()
                .fill(Color.purple)
                .frame(width: 8, height: 8)
        }
    }
}

// 日付別スケジュール詳細ビュー
struct DayScheduleDetailView: View {
    let date: Date
    let scheduleItems: [ScheduleItem]
    let animeManager: AnimeManager
    let deleteAction: (ScheduleItem) -> Void
    @Environment(\.dismiss) var dismiss
    @State private var showingAddSchedule = false
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale.current
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Add anime button
                    Button(action: {
                        showingAddSchedule = true
                    }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 20))
                            Text(NSLocalizedString("add_anime", comment: "Add anime"))
                                .font(.system(size: 16, weight: .medium))
                        }
                        .foregroundColor(.purple)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.purple.opacity(0.1))
                        .cornerRadius(10)
                    }
                    
                    ForEach(scheduleItems) { item in
                        ScheduleItemRow(item: item) {
                            deleteAction(item)
                            if scheduleItems.count == 1 {
                                dismiss()
                            }
                        }
                        .environmentObject(animeManager)
                    }
                }
                .padding()
            }
            .navigationTitle(dateFormatter.string(from: date))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("close", comment: "Close")) {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingAddSchedule) {
                AddScheduleSheetForDate(
                    animeManager: animeManager,
                    selectedDate: date
                ) { anime, episode, note in
                    // Create and save new schedule item
                    let newItem = ScheduleItem(
                        date: date,
                        animeId: anime.id.uuidString,
                        animeTitle: anime.title,
                        episode: episode,
                        note: note
                    )
                    
                    // Post notification to add the item
                    NotificationCenter.default.post(
                        name: NSNotification.Name("AddScheduleItem"),
                        object: nil,
                        userInfo: ["item": newItem]
                    )
                    
                    showingAddSchedule = false
                }
            }
        }
    }
}

// 特定の日付用スケジュール追加シート（複数選択対応）
struct AddScheduleSheetForDate: View {
    let animeManager: AnimeManager
    let selectedDate: Date
    let onAdd: (Anime, Int?, String?) -> Void
    
    @State private var selectedAnimeIds: Set<String> = []
    @State private var showAnimeSelection = false
    @Environment(\.dismiss) var dismiss
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale.current
        return formatter
    }()
    
    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(NSLocalizedString("date", comment: "Date"))) {
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.purple)
                        Text(dateFormatter.string(from: selectedDate))
                            .font(.system(size: 16, weight: .medium))
                    }
                }
                
                Section {
                    HStack {
                        Text(NSLocalizedString("anime", comment: "Anime"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(selectedAnimeIds.count) " + NSLocalizedString("items_selected", comment: "items selected"))
                            .font(.system(size: 12))
                            .foregroundColor(.purple)
                    }
                    .padding(.bottom, 8)
                    
                    let validAnimes = animeManager.animes.filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                    if validAnimes.isEmpty {
                        Text(NSLocalizedString("no_anime_registered", comment: "No anime registered"))
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        ForEach(validAnimes) { anime in
                            HStack {
                                if let imagePath = anime.imageIdentifier,
                                   let uiImage = loadImageFromPath(imagePath) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 40, height: 40)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                } else {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.purple.opacity(0.1))
                                        .frame(width: 40, height: 40)
                                        .overlay(
                                            Image(systemName: "tv")
                                                .foregroundColor(.purple.opacity(0.5))
                                        )
                                }
                                
                                Text(anime.title)
                                    .font(.system(size: 15))
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                Spacer()
                                
                                Image(systemName: selectedAnimeIds.contains(anime.id.uuidString) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedAnimeIds.contains(anime.id.uuidString) ? .purple : .gray)
                                    .font(.system(size: 20))
                            }
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                if selectedAnimeIds.contains(anime.id.uuidString) {
                                    selectedAnimeIds.remove(anime.id.uuidString)
                                } else {
                                    selectedAnimeIds.insert(anime.id.uuidString)
                                }
                            }
                        }
                    }
                }
                
            }
            .navigationTitle(NSLocalizedString("add_watch_schedule", comment: "Add watch schedule"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("cancel", comment: "Cancel")) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("add", comment: "Add")) {
                        // 複数のアニメを追加
                        for animeId in selectedAnimeIds {
                            if let anime = animeManager.animes.first(where: { $0.id.uuidString == animeId }) {
                                onAdd(anime, nil, nil)
                            }
                        }
                        // スケジュール更新の通知を送信
                        NotificationCenter.default.post(name: NSNotification.Name("ScheduleUpdated"), object: nil)
                        dismiss()
                    }
                    .disabled(selectedAnimeIds.isEmpty)
                }
            }
        }
    }
}

// アニメ選択ビュー
struct AnimeSelectionView: View {
    let animes: [Anime]
    @Binding var selectedAnime: Anime?
    @Environment(\.dismiss) var dismiss
    @State private var searchText = ""
    
    var filteredAnimes: [Anime] {
        if searchText.isEmpty {
            return animes.filter { !$0.title.isEmpty }
        } else {
            return animes.filter { 
                !$0.title.isEmpty && 
                $0.title.localizedCaseInsensitiveContains(searchText) 
            }
        }
    }
    
    var body: some View {
        NavigationView {
            List(filteredAnimes) { anime in
                Button(action: {
                    selectedAnime = anime
                    dismiss()
                }) {
                    HStack {
                        if let imagePath = anime.imageIdentifier,
                           let uiImage = loadImageFromPath(imagePath) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 50, height: 50)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        } else {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.purple.opacity(0.1))
                                .frame(width: 50, height: 50)
                                .overlay(
                                    Image(systemName: "tv")
                                        .foregroundColor(.purple.opacity(0.5))
                                )
                        }
                        
                        Text(anime.title)
                            .font(.system(size: 16))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        if selectedAnime?.id == anime.id {
                            Image(systemName: "checkmark")
                                .foregroundColor(.purple)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: NSLocalizedString("search_anime", comment: "Search anime"))
            .navigationTitle(NSLocalizedString("select_anime", comment: "Select anime"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("close", comment: "Close")) {
                        dismiss()
                    }
                }
            }
        }
    }
}

// 複数アニメ選択対応のスケジュール追加シート
struct MultiAddScheduleSheet: View {
    let animeManager: AnimeManager
    @Binding var selectedDate: Date
    @Binding var selectedAnimeIds: Set<String>
    @Binding var showingAddSchedule: Bool
    let addAction: () -> Void
    let resetAction: () -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 日付選択
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("watch_schedule_date", comment: "Watch schedule date"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                    DatePicker("", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(GraphicalDatePickerStyle())
                        .frame(height: 320)
                }
                .padding(.horizontal)
                
                // アニメ選択（複数選択可能）
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(NSLocalizedString("anime", comment: "Anime"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(selectedAnimeIds.count) " + NSLocalizedString("items_selected", comment: "items selected"))
                            .font(.system(size: 12))
                            .foregroundColor(.purple)
                    }
                    
                    let validAnimes = animeManager.animes.filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                    if validAnimes.isEmpty {
                        Text(NSLocalizedString("no_anime_registered", comment: "No anime registered"))
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(validAnimes) { anime in
                                    HStack {
                                        Text(anime.title)
                                            .font(.system(size: 15))
                                            .foregroundColor(.primary)
                                        Spacer()
                                        Image(systemName: selectedAnimeIds.contains(anime.id.uuidString) ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(selectedAnimeIds.contains(anime.id.uuidString) ? .purple : .gray)
                                            .font(.system(size: 20))
                                    }
                                    .padding()
                                    .background(selectedAnimeIds.contains(anime.id.uuidString) ? Color.purple.opacity(0.1) : Color.clear)
                                    .onTapGesture {
                                        if selectedAnimeIds.contains(anime.id.uuidString) {
                                            selectedAnimeIds.remove(anime.id.uuidString)
                                        } else {
                                            selectedAnimeIds.insert(anime.id.uuidString)
                                        }
                                    }
                                    
                                    if anime.id != validAnimes.last?.id {
                                        Divider()
                                    }
                                }
                            }
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .frame(maxHeight: 300)
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle(NSLocalizedString("schedule_add_title", comment: "Add Schedule"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("cancel", comment: "Cancel")) {
                        showingAddSchedule = false
                        resetAction()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("add", comment: "Add")) {
                        addAction()
                        showingAddSchedule = false
                    }
                    .disabled(selectedAnimeIds.isEmpty)
                }
            }
        }
    }
}

// スケジュール追加シート（旧版、互換性のため残す）
struct AddScheduleSheet: View {
    let animeManager: AnimeManager
    @Binding var selectedDate: Date
    @Binding var selectedAnimeId: String
    @Binding var episode: String
    @Binding var note: String
    @Binding var showingAddSchedule: Bool
    let addAction: () -> Void
    let resetAction: () -> Void
    let getSelectedAnimeTitle: () -> String
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 日付選択
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("watch_schedule_date", comment: "Watch schedule date"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                    DatePicker("", selection: $selectedDate, displayedComponents: .date)
                        .datePickerStyle(GraphicalDatePickerStyle())
                        .frame(height: 320)
                }
                .padding(.horizontal)
                
                // アニメ選択
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("anime", comment: "Anime"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                    
                    let validAnimes = animeManager.animes.filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                    if validAnimes.isEmpty {
                        Text(NSLocalizedString("no_anime_registered", comment: "No anime registered"))
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .padding()
                    } else {
                        Menu {
                            ForEach(validAnimes) { anime in
                                Button(action: {
                                    selectedAnimeId = anime.id.uuidString
                                }) {
                                    Text(anime.title)
                                }
                            }
                        } label: {
                            HStack {
                                Text(getSelectedAnimeTitle())
                                    .foregroundColor(selectedAnimeId.isEmpty ? .gray : .primary)
                                Spacer()
                                Image(systemName: "chevron.down")
                                    .foregroundColor(.gray)
                            }
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.horizontal)
                
                // エピソード番号（オプション）
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("episode_number_optional", comment: "Episode number (optional)"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                    TextField(NSLocalizedString("example_12", comment: "e.g. 12"), text: $episode)
                        .keyboardType(.numberPad)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                .padding(.horizontal)
                
                // メモ（オプション）
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("memo_optional", comment: "Memo (optional)"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.gray)
                    TextField(NSLocalizedString("example_watch_with_friends", comment: "e.g. Watch with friends"), text: $note)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle(NSLocalizedString("schedule_add_title", comment: "Add Schedule"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("cancel", comment: "Cancel")) {
                        showingAddSchedule = false
                        resetAction()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(NSLocalizedString("add", comment: "Add")) {
                        addAction()
                        showingAddSchedule = false
                    }
                    .disabled(selectedAnimeId.isEmpty)
                }
            }
        }
    }
}

// 今日見るアニメセクション
struct TodayAnimeScrollView: View {
    @EnvironmentObject var animeManager: AnimeManager
    private let userDefaultsKey = "scheduleItems"
    @State private var scheduleItems: [ScheduleItem] = []
    
    var todayScheduleItems: [ScheduleItem] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        return scheduleItems.filter { item in
            calendar.isDate(item.date, inSameDayAs: today)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // タイトル
            Text(NSLocalizedString("today_anime_title", comment: "Today's Anime"))
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.purple)
                .padding(.horizontal, 20)
            
            if todayScheduleItems.isEmpty {
                // 今日のスケジュールがない場合
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 30))
                        .foregroundColor(.gray.opacity(0.5))
                    Text(NSLocalizedString("no_anime_today", comment: "No anime scheduled for today"))
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 100)
                .padding(.horizontal, 20)
            } else {
                // アニメサムネイルの横スクロール
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 15) {
                        ForEach(todayScheduleItems, id: \.id) { item in
                            TodayAnimeCard(item: item)
                                .environmentObject(animeManager)
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
        .onAppear {
            loadScheduleItems()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ScheduleUpdated"))) { _ in
            loadScheduleItems()
        }
    }
    
    private func loadScheduleItems() {
        if let data = UserDefaults.standard.data(forKey: userDefaultsKey),
           let items = try? JSONDecoder().decode([ScheduleItem].self, from: data) {
            scheduleItems = items
        }
    }
}

struct TodayAnimeCard: View {
    let item: ScheduleItem
    @EnvironmentObject var animeManager: AnimeManager
    
    var body: some View {
        VStack(spacing: 8) {
            // アニメサムネイル
            if let anime = animeManager.animes.first(where: { $0.id.uuidString == item.animeId }),
               let imagePath = anime.imageIdentifier,
               let uiImage = loadImageFromPath(imagePath) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 140)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.purple.opacity(0.3), lineWidth: 1.5)
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 4, x: 0, y: 2)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color.purple.opacity(0.2), Color.purple.opacity(0.1)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 100, height: 140)
                    .overlay(
                        Image(systemName: "tv")
                            .font(.system(size: 30))
                            .foregroundColor(.purple.opacity(0.5))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.purple.opacity(0.3), lineWidth: 1.5)
                    )
            }
            
            // アニメタイトル
            Text(item.animeTitle)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(1)
                .frame(width: 100)
            
            // エピソード番号（もしあれば）
            if let episode = item.episode {
                Text("第\(episode)話")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
        }
    }
}

struct HomeScreen_Previews: PreviewProvider {
    static var previews: some View {
        HomeScreen()
    }
}

// Temporary UserProfileScreen implementation until UserProfileScreen.swift is added to project
struct UserProfileScreenTemp: View {
    @EnvironmentObject var profileManager: UserProfileManager
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var username: String = ""
    @State private var selectedIconItem: PhotosPickerItem?
    @State private var iconImage: UIImage?
    @State private var birthday = Date()
    @State private var showBirthdayPicker = false
    @State private var animeQuote: String = ""
    @State private var showingLogoutConfirmation = false
    @State private var showingPurchaseHistory = false
    @State private var showCopiedFeedback = false
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景色
                Color.white.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // ヘッダー
                    HStack {
                        Button(action: { dismiss() }) {
                            Image(systemName: "xmark")
                                .font(.system(size: 24, weight: .medium))
                                .foregroundColor(.black)
                        }
                        
                        Spacer()
                        
                        Text(NSLocalizedString("profile_edit", comment: "Profile edit"))
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.black)
                        
                        Spacer()
                        
                        // 空のスペーサーで右側のバランスを保つ
                        Spacer()
                            .frame(width: 44)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color.white)
                    .shadow(color: Color.black.opacity(0.05), radius: 1, x: 0, y: 1)
                    
                    ScrollView {
                        VStack(spacing: 0) {
                            // プロフィール画像セクション
                            VStack(spacing: 16) {
                                PhotosPicker(selection: $selectedIconItem, matching: .images) {
                                    ZStack {
                                        if let iconImage = iconImage {
                                            Image(uiImage: iconImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 100, height: 100)
                                                .clipShape(Circle())
                                        } else if let imagePath = profileManager.currentUser.iconImagePath,
                                                  let uiImage = loadImageFromPath(imagePath) {
                                            Image(uiImage: uiImage)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 100, height: 100)
                                                .clipShape(Circle())
                                        } else {
                                            Circle()
                                                .fill(Color.gray.opacity(0.3))
                                                .frame(width: 100, height: 100)
                                                .overlay(
                                                    Image(systemName: "person.fill")
                                                        .font(.system(size: 40))
                                                        .foregroundColor(.gray)
                                                )
                                        }
                                        
                                        // カメラアイコンオーバーレイ
                                        Circle()
                                            .fill(Color.black.opacity(0.3))
                                            .frame(width: 100, height: 100)
                                            .overlay(
                                                Image(systemName: "camera.fill")
                                                    .font(.system(size: 24))
                                                    .foregroundColor(.white)
                                            )
                                    }
                                }
                                .onChange(of: selectedIconItem) { oldValue, newValue in
                                    Task {
                                        if let data = try? await newValue?.loadTransferable(type: Data.self),
                                           let uiImage = UIImage(data: data) {
                                            iconImage = uiImage
                                            saveProfile()
                                        }
                                    }
                                }
                                
                                Text(NSLocalizedString("change_profile_image", comment: "Change profile image"))
                                    .font(.system(size: 14))
                                    .foregroundColor(.blue)
                            }
                            .padding(.top, 24)
                            .padding(.bottom, 32)
                            
                            // 基本情報セクション
                            VStack(alignment: .leading, spacing: 0) {
                                // ユーザー名
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(NSLocalizedString("username", comment: "Username"))
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.gray)
                                    TextField(NSLocalizedString("enter_name", comment: "Enter name"), text: $username)
                                        .font(.system(size: 16))
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 16)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                        .onChange(of: username) { oldValue, newValue in
                                            saveProfile()
                                        }
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 24)
                                
                                // 誕生日
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(NSLocalizedString("birthday", comment: "Birthday"))
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.gray)
                                    
                                    Button(action: { showBirthdayPicker.toggle() }) {
                                        HStack {
                                            Text(profileManager.currentUser.birthday != nil ? 
                                                DateFormatter.japaneseDate.string(from: birthday) : NSLocalizedString("set_birthday", comment: "Set birthday"))
                                                .font(.system(size: 16))
                                                .foregroundColor(profileManager.currentUser.birthday != nil ? .black : .gray)
                                            Spacer()
                                            Image(systemName: "calendar")
                                                .foregroundColor(.gray)
                                        }
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 16)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 24)
                                
                                // アニメのセリフ
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(NSLocalizedString("favorite_anime_quote", comment: "Favorite anime quote"))
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.gray)
                                    TextField(NSLocalizedString("enter_anime_quote", comment: "Enter anime quote"), text: $animeQuote)
                                        .font(.system(size: 16))
                                        .padding(.vertical, 12)
                                        .padding(.horizontal, 16)
                                        .background(Color(.systemGray6))
                                        .cornerRadius(8)
                                        .onChange(of: animeQuote) { oldValue, newValue in
                                            saveProfile()
                                        }
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 32)
                            }
                            
                            // 購入履歴セクション
                            VStack(spacing: 16) {
                                Divider()
                                    .padding(.horizontal, 16)
                                
                                Button(action: {
                                    showingPurchaseHistory = true
                                }) {
                                    HStack {
                                        Image(systemName: "doc.text")
                                            .foregroundColor(.purple)
                                        Text(NSLocalizedString("purchase_history", comment: "Purchase history"))
                                            .font(.system(size: 16))
                                            .foregroundColor(.purple)
                                        Spacer()
                                        Image(systemName: "chevron.right")
                                            .foregroundColor(.gray)
                                            .font(.system(size: 12))
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                            }
                            
                            // ログアウトボタン
                            VStack(spacing: 16) {
                                Divider()
                                    .padding(.horizontal, 16)
                                
                                Button(action: {
                                    showingLogoutConfirmation = true
                                }) {
                                    HStack {
                                        Image(systemName: "rectangle.portrait.and.arrow.right")
                                            .foregroundColor(.red)
                                        Text(NSLocalizedString("logout", comment: "Logout"))
                                            .font(.system(size: 16))
                                            .foregroundColor(.red)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                                
                                // ユーザーID表示
                                if let userId = UserDefaults.standard.string(forKey: "userId") {
                                    HStack {
                                        Text(NSLocalizedString("user_id", comment: "User ID"))
                                            .font(.system(size: 12))
                                            .foregroundColor(.gray)
                                        Text(userId)
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.gray)
                                        Spacer()
                                        Button(action: {
                                            UIPasteboard.general.string = userId
                                            showCopiedFeedback = true
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                                showCopiedFeedback = false
                                            }
                                        }) {
                                            Image(systemName: showCopiedFeedback ? "checkmark" : "doc.on.doc")
                                                .font(.system(size: 14))
                                                .foregroundColor(.blue)
                                                .padding(8)
                                                .background(Color.gray.opacity(0.1))
                                                .cornerRadius(6)
                                        }
                                        .buttonStyle(PlainButtonStyle())
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.bottom, 16)
                                }
                            }
                        }
                    }
                }
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showBirthdayPicker) {
            NavigationView {
                DatePicker(NSLocalizedString("select_birthday", comment: "Select birthday"), selection: $birthday, displayedComponents: .date)
                    .datePickerStyle(WheelDatePickerStyle())
                    .labelsHidden()
                    .navigationTitle(NSLocalizedString("birthday", comment: "Birthday"))
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button(NSLocalizedString("complete", comment: "Complete")) {
                                showBirthdayPicker = false
                                saveProfile()
                            }
                        }
                    }
            }
            .presentationDetents([.height(300)])
        }
        .onAppear {
            loadCurrentProfile()
        }
        .onChange(of: profileManager.currentUser) { oldValue, newValue in
            loadCurrentProfile()
        }
        .sheet(isPresented: $showingPurchaseHistory) {
            PurchaseHistoryView()
        }
        .fullScreenCover(isPresented: $showingLogoutConfirmation) {
            LogoutConfirmationView(
                isPresented: $showingLogoutConfirmation,
                onLogout: {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        authManager.logout()
                    }
                }
            )
        }
        .overlay(
            // Copied feedback overlay
            VStack {
                if showCopiedFeedback {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.white)
                        Text(NSLocalizedString("copied", comment: "Copied"))
                            .foregroundColor(.white)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.black.opacity(0.8))
                    .cornerRadius(20)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: showCopiedFeedback)
                }
                Spacer()
            }
            .padding(.top, 50)
        )
    }
    
    private func loadCurrentProfile() {
        username = profileManager.currentUser.username
        animeQuote = profileManager.currentUser.animeQuote
        if let bday = profileManager.currentUser.birthday {
            birthday = bday
        }
        
        if let imagePath = profileManager.currentUser.iconImagePath,
           let uiImage = loadImageFromPath(imagePath) {
            iconImage = uiImage
        } else {
        }
        
    }
    
    private func saveProfile() {
        profileManager.currentUser.username = username
        profileManager.currentUser.birthday = birthday
        profileManager.currentUser.animeQuote = animeQuote
        
        // 画像を保存
        if let iconImage = iconImage {
            // 古い画像ファイルを削除
            if let oldImagePath = profileManager.currentUser.iconImagePath,
               let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
                let oldFilePath = documentsURL.appendingPathComponent(oldImagePath)
                try? FileManager.default.removeItem(at: oldFilePath)
            }
            
            guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                return
            }
            let fileName = "profile_\(UUID().uuidString).jpg"
            let filePath = documentsPath.appendingPathComponent(fileName)
            
            if let imageData = iconImage.jpegData(compressionQuality: 0.8) {
                do {
                    try imageData.write(to: filePath)
                    // 相対パスで保存（ファイル名のみ）
                    profileManager.currentUser.iconImagePath = fileName
                } catch {
                }
            }
        }
        
        profileManager.saveProfile()
        
        // Firebaseにも保存
        FirebaseManager.shared.saveUserProfile(profileManager.currentUser) { result in
            DispatchQueue.main.async {
                switch result {
                case .success():
                    break
                case .failure(_):
                    break
                }
            }
        }
    }
}

struct LogoutConfirmationView: View {
    @Binding var isPresented: Bool
    let onLogout: () -> Void
    @EnvironmentObject var profileManager: UserProfileManager
    @State private var copiedUserId = false
    @State private var copiedUsername = false
    
    private var userId: String {
        UserDefaults.standard.string(forKey: "userId") ?? "IDが見つかりません"
    }
    
    private var username: String {
        if let savedUsername = UserDefaults.standard.string(forKey: "username"), !savedUsername.isEmpty {
            return savedUsername
        }
        return profileManager.currentUser.username.isEmpty ? "未設定" : profileManager.currentUser.username
    }
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // ヘッダー
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.orange)
                    
                    Text(NSLocalizedString("important_confirm_before_logout", comment: "Important: Confirm Before Logout"))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.primary)
                }
                .padding(.top, 40)
                .padding(.bottom, 20)
                
                // 警告メッセージ
                VStack(spacing: 16) {
                    Text(NSLocalizedString("save_following_info", comment: "Please save the following information"))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.red)
                    
                    Text(NSLocalizedString("cannot_restore_without_info", comment: "Without this information, you cannot restore your account"))
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
                
                // ユーザー情報
                VStack(spacing: 16) {
                    // ユーザーID
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("user_id_label", comment: "User ID"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                        
                        HStack {
                            Text(userId)
                                .font(.system(size: 16).monospaced())
                                .foregroundColor(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.5)
                            
                            Spacer()
                            
                            Button(action: {
                                UIPasteboard.general.string = userId
                                copiedUserId = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    copiedUserId = false
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: copiedUserId ? "checkmark" : "doc.on.doc")
                                        .font(.system(size: 14))
                                    Text(copiedUserId ? NSLocalizedString("copied", comment: "Copied") : NSLocalizedString("copy", comment: "Copy"))
                                        .font(.system(size: 14))
                                }
                                .foregroundColor(copiedUserId ? .green : .blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    }
                    
                    // ユーザー名
                    VStack(alignment: .leading, spacing: 8) {
                        Text(NSLocalizedString("username", comment: "Username"))
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                        
                        HStack {
                            Text(username)
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Button(action: {
                                UIPasteboard.general.string = username
                                copiedUsername = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    copiedUsername = false
                                }
                            }) {
                                HStack(spacing: 4) {
                                    Image(systemName: copiedUsername ? "checkmark" : "doc.on.doc")
                                        .font(.system(size: 14))
                                    Text(copiedUsername ? NSLocalizedString("copied", comment: "Copied") : NSLocalizedString("copy", comment: "Copy"))
                                        .font(.system(size: 14))
                                }
                                .foregroundColor(copiedUsername ? .green : .blue)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(6)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
                
                // 注意事項
                VStack(spacing: 12) {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.orange)
                        Text(NSLocalizedString("take_screenshot_or_save", comment: "Please take a screenshot or save to memo"))
                            .font(.system(size: 14))
                            .foregroundColor(.primary)
                    }
                    
                    Text(NSLocalizedString("cannot_access_after_logout", comment: "You cannot access your account without this information after logout"))
                        .font(.system(size: 12))
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
                
                // ボタン
                HStack(spacing: 16) {
                    Button(action: {
                        isPresented = false
                    }) {
                        Text("キャンセル")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(25)
                    }
                    
                    Button(action: {
                        isPresented = false
                        onLogout()
                    }) {
                        Text(NSLocalizedString("logout", comment: "Logout"))
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.red)
                            .cornerRadius(25)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
            .frame(maxWidth: 400)
            .background(Color.white)
            .cornerRadius(24)
            .shadow(radius: 30)
            .padding(.horizontal, 20)
        }
    }
}

 