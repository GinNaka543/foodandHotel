import SwiftUI
import Foundation
import HappinessGameSwift

enum ListTab: Int {
    case chara, anime, birthday
}

struct HomeScreen: View {
    @EnvironmentObject var mainTab: MainTabSelection
    @State private var showListPage = false
    @State private var initialTab: ListTab = .chara
    @StateObject private var characterManager = CharacterManager()
    @StateObject private var animeManager = AnimeManager()
    
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
            
            // 今日の月日を取得
            let todayMonth = calendar.component(.month, from: today)
            let todayDay = calendar.component(.day, from: today)
            
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
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // ヘッダー
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("中島 銀星")
                            .font(.system(size: 28, weight: .bold))
                        Text("Enter a status message")
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Image("sample") // 仮のアイコン画像
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 60, height: 60)
                        .clipShape(Circle())
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
                        Text("Services")
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
                Spacer(minLength: 0)
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