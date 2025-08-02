import SwiftUI
import Foundation
import PhotosUI

// iPad専用のホームスクリーン
struct HomeScreen_iPad: View {
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
    
    private func getBirthdayReminderCharacters() -> [Character] {
        let today = Date()
        let calendar = Calendar.current
        
        // 今日から5日前と3日後の日付を計算
        let fiveDaysAgo = calendar.date(byAdding: .day, value: -5, to: today) ?? today
        let threeDaysLater = calendar.date(byAdding: .day, value: 3, to: today) ?? today
        
        return characterManager.characters.filter { character in
            let birthday = character.birthday
            
            // 誕生日の月日を取得
            let birthdayMonth = calendar.component(.month, from: birthday)
            let birthdayDay = calendar.component(.day, from: birthday)
            
            // 比較用の日付を同じ年に統一
            let birthdayDate = calendar.date(from: DateComponents(year: 2000, month: birthdayMonth, day: birthdayDay)) ?? Date()
            let rangeStart = calendar.date(from: DateComponents(year: 2000, month: calendar.component(.month, from: fiveDaysAgo), day: calendar.component(.day, from: fiveDaysAgo))) ?? Date()
            let rangeEnd = calendar.date(from: DateComponents(year: 2000, month: calendar.component(.month, from: threeDaysLater), day: calendar.component(.day, from: threeDaysLater))) ?? Date()
            
            // 年をまたぐ場合の処理
            if rangeStart > rangeEnd {
                return birthdayDate >= rangeStart || birthdayDate <= rangeEnd
            } else {
                return birthdayDate >= rangeStart && birthdayDate <= rangeEnd
            }
        }
    }
    
    private func getBirthdayReminderText() -> String {
        let names = getBirthdayReminderCharacters().map { $0.name }
        let joinedNames = names.joined(separator: ", ")
        return joinedNames
    }
    
    var body: some View {
        NavigationView {
            // サイドバー
            VStack(alignment: .leading, spacing: 0) {
                // プロフィール部分
                HStack(spacing: 16) {
                    // ユーザーアイコン
                    Button(action: {
                        showingProfile = true
                    }) {
                        if let imagePath = profileManager.currentUser.iconImagePath,
                           let uiImage = loadImageFromPath(imagePath) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 80, height: 80)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                )
                        } else {
                            Circle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Image(systemName: "person.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.gray.opacity(0.5))
                                )
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(profileManager.currentUser.username.isEmpty ? "中島 銀星" : profileManager.currentUser.username)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(profileManager.currentUser.animeQuote.isEmpty ? NSLocalizedString("set_anime_quote", comment: "Set anime quote") : profileManager.currentUser.animeQuote)
                            .font(.caption)
                            .foregroundColor(.gray)
                            .lineLimit(2)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                
                // ステータスボタン
                HStack(spacing: 12) {
                    Button(action: {
                        showingProfile = true
                    }) {
                        Label("Profile", systemImage: "person.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: {
                        showingPoints = true
                    }) {
                        Label("Points", systemImage: "star.circle")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }
                .padding(.horizontal)
                .padding(.bottom)
                
                Divider()
                
                // リスト
                List {
                    Section("Favorite lists") {
                        // バースデーリマインダー
                        if !getBirthdayReminderCharacters().isEmpty {
                            Button(action: {
                                showBirthdayList = true
                            }) {
                                HStack {
                                    Image(systemName: "birthday.cake")
                                        .foregroundColor(.orange)
                                        .font(.title3)
                                    VStack(alignment: .leading) {
                                        Text("Birthday reminders")
                                            .font(.headline)
                                        Text(getBirthdayReminderText())
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    }
                                    Spacer()
                                    Text("\(getBirthdayReminderCharacters().count)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                        
                        // キャラクターリスト
                        Button(action: {
                            showCharacterList = true
                        }) {
                            HStack {
                                Image(systemName: "person.3")
                                    .foregroundColor(.blue)
                                    .font(.title3)
                                VStack(alignment: .leading) {
                                    Text("Characters")
                                        .font(.headline)
                                    Text(getCharacterNamesText())
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Text("\(characterManager.characters.count)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // アニメリスト
                        Button(action: {
                            showAnimeList = true
                        }) {
                            HStack {
                                Image(systemName: "tv")
                                    .foregroundColor(.purple)
                                    .font(.title3)
                                VStack(alignment: .leading) {
                                    Text("Anime")
                                        .font(.headline)
                                    Text(getAnimeNamesText())
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                Text("\(animeManager.animes.count)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .listStyle(SidebarListStyle())
            }
            .frame(minWidth: 320, idealWidth: 350)
            .navigationTitle("ホーム")
            
            // メインコンテンツ - スケジュール
            VStack(spacing: 0) {
                // ヘッダー
                HStack {
                    Text("Schedule")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Spacer()
                    
                    Button(action: {
                        NotificationCenter.default.post(name: NSNotification.Name("ShowAddSchedule"), object: nil)
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.purple)
                    }
                }
                .padding()
                
                // 今日見るアニメセクション
                TodayAnimeScrollView_iPad()
                    .environmentObject(animeManager)
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                
                // カレンダービュー
                GeometryReader { geometry in
                    ScrollView {
                        ScheduleView_iPad()
                            .environmentObject(animeManager)
                            .frame(maxWidth: min(geometry.size.width - 40, 800))
                            .padding()
                    }
                }
            }
            .background(Color(.systemGray6))
        }
        .navigationViewStyle(DoubleColumnNavigationViewStyle())
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
            UserProfileScreenTemp()
                .environmentObject(profileManager)
        }
        .sheet(isPresented: $showingPoints) {
            PointsView()
        }
        .onAppear {
            if !hasLoadedData {
                hasLoadedData = true
                characterManager.loadCharacters()
                animeManager.loadAnimes()
            }
        }
    }
}

// iPad専用のスケジュールビュー
struct ScheduleView_iPad: View {
    @EnvironmentObject var animeManager: AnimeManager
    @State private var scheduleItems: [ScheduleItem] = []
    @State private var showingAddSchedule = false
    @State private var selectedDate = Date()
    @State private var selectedAnimeId: String = ""
    @State private var episode: String = ""
    @State private var note: String = ""
    
    private let userDefaultsKey = "scheduleItems"
    
    var body: some View {
        VStack(spacing: 20) {
            if scheduleItems.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "calendar")
                        .font(.system(size: 60))
                        .foregroundColor(.purple.opacity(0.6))
                    
                    Text(NSLocalizedString("schedule_empty", comment: "No schedules registered"))
                        .font(.title3)
                        .foregroundColor(.gray)
                    
                    Button(action: {
                        showingAddSchedule = true
                    }) {
                        Label(NSLocalizedString("schedule_add", comment: "Add schedule"), systemImage: "plus.circle.fill")
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.purple, Color.purple.opacity(0.8)]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(25)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // カレンダーを大きく表示
                ScheduleCalendarView_iPad(
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
            AddScheduleSheet(
                animeManager: animeManager,
                selectedDate: $selectedDate,
                selectedAnimeId: $selectedAnimeId,
                episode: $episode,
                note: $note,
                showingAddSchedule: $showingAddSchedule,
                addAction: addScheduleItem,
                resetAction: resetForm,
                getSelectedAnimeTitle: getSelectedAnimeTitle
            )
        }
    }
    
    private func addScheduleItem() {
        guard !selectedAnimeId.isEmpty,
              let anime = animeManager.animes.first(where: { $0.id.uuidString == selectedAnimeId }) else { return }
        
        let newItem = ScheduleItem(
            date: selectedDate,
            animeId: selectedAnimeId,
            animeTitle: anime.title,
            episode: episode.isEmpty ? nil : Int(episode),
            note: note
        )
        
        scheduleItems.append(newItem)
        saveScheduleItems()
        resetForm()
    }
    
    private func deleteScheduleItem(_ item: ScheduleItem) {
        scheduleItems.removeAll(where: { $0.id == item.id })
        saveScheduleItems()
    }
    
    private func resetForm() {
        selectedDate = Date()
        selectedAnimeId = ""
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
    
    private func getSelectedAnimeTitle() -> String {
        if let anime = animeManager.animes.first(where: { $0.id.uuidString == selectedAnimeId }) {
            return anime.title
        }
        return NSLocalizedString("select_anime", comment: "Select anime")
    }
}

// iPad専用のカレンダービュー
struct ScheduleCalendarView_iPad: View {
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
        formatter.dateFormat = "yyyy年M月"
        formatter.locale = Locale(identifier: "ja_JP")
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
        VStack(spacing: 20) {
            // 月の切り替えヘッダー
            HStack {
                Button(action: {
                    withAnimation {
                        selectedMonth = calendar.date(byAdding: .month, value: -1, to: selectedMonth) ?? selectedMonth
                    }
                }) {
                    Image(systemName: "chevron.left")
                        .font(.title3)
                        .foregroundColor(.purple)
                }
                
                Spacer()
                
                Text(dateFormatter.string(from: selectedMonth))
                    .font(.title)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button(action: {
                    withAnimation {
                        selectedMonth = calendar.date(byAdding: .month, value: 1, to: selectedMonth) ?? selectedMonth
                    }
                }) {
                    Image(systemName: "chevron.right")
                        .font(.title3)
                        .foregroundColor(.purple)
                }
            }
            
            // 曜日ヘッダー
            HStack(spacing: 0) {
                ForEach(["日", "月", "火", "水", "木", "金", "土"], id: \.self) { weekday in
                    Text(weekday)
                        .font(.headline)
                        .foregroundColor(weekday == "日" ? .red : weekday == "土" ? .blue : .primary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // カレンダーグリッド
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(minimum: 80), spacing: 8), count: 7), spacing: 8) {
                ForEach(calendarDays) { day in
                    CalendarDayCell_iPad(
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
                                selectedDateForAdd = day.date
                                showingAddScheduleForDate = true
                            }
                        }
                    }
                }
            }
        }
        .padding()
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
            AddScheduleSheetForDate_iPad(
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

// iPad専用のカレンダー日付セル
struct CalendarDayCell_iPad: View {
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
        VStack(spacing: 4) {
            Text("\(day.dayNumber)")
                .font(.title3)
                .fontWeight(isToday ? .bold : .medium)
                .foregroundColor(dayNumberColor)
            
            // スケジュールインジケーター
            if !day.scheduleItems.isEmpty {
                VStack(spacing: 4) {
                    ForEach(day.scheduleItems.prefix(3)) { item in
                        ScheduleIndicator_iPad(item: item, animeManager: animeManager)
                    }
                }
                
                if day.scheduleItems.count > 3 {
                    Text("+\(day.scheduleItems.count - 3)")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.purple)
                }
            }
        }
        .frame(height: 100)
        .frame(maxWidth: .infinity)
        .background(
            backgroundFill
                .clipShape(RoundedRectangle(cornerRadius: 12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.purple : Color.clear, lineWidth: 2)
        )
        .scaleEffect(!day.scheduleItems.isEmpty && day.isCurrentMonth ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
    }
}

// iPad専用のスケジュールインジケーター
struct ScheduleIndicator_iPad: View {
    let item: ScheduleItem
    let animeManager: AnimeManager
    
    var body: some View {
        if let anime = animeManager.animes.first(where: { $0.id.uuidString == item.animeId }),
           let imagePath = anime.imageIdentifier,
           let uiImage = loadImageFromPath(imagePath) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 20, height: 20)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 1)
                )
        } else {
            Circle()
                .fill(Color.purple)
                .frame(width: 16, height: 16)
        }
    }
}

// iPad用の今日見るアニメセクション
struct TodayAnimeScrollView_iPad: View {
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
        VStack(alignment: .leading, spacing: 16) {
            // タイトル
            Text(NSLocalizedString("today_anime_title", comment: "Today's Anime"))
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.purple)
            
            if todayScheduleItems.isEmpty {
                // 今日のスケジュールがない場合
                HStack {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.system(size: 40))
                            .foregroundColor(.gray.opacity(0.5))
                        Text(NSLocalizedString("no_anime_today", comment: "No anime scheduled for today"))
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 40)
                    Spacer()
                }
            } else {
                // アニメサムネイルの横スクロール
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 20) {
                        ForEach(todayScheduleItems, id: \.id) { item in
                            TodayAnimeCard_iPad(item: item)
                                .environmentObject(animeManager)
                        }
                    }
                }
            }
        }
        .onAppear {
            loadScheduleItems()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ScheduleUpdated"))) { _ in
            loadScheduleItems()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AddScheduleItem"))) { notification in
            if let userInfo = notification.userInfo,
               let item = userInfo["item"] as? ScheduleItem {
                scheduleItems.append(item)
                saveScheduleItems()
            }
        }
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

// iPad用の今日のアニメカード
struct TodayAnimeCard_iPad: View {
    let item: ScheduleItem
    @EnvironmentObject var animeManager: AnimeManager
    
    var body: some View {
        VStack(spacing: 12) {
            // アニメサムネイル
            if let anime = animeManager.animes.first(where: { $0.id.uuidString == item.animeId }),
               let imagePath = anime.imageIdentifier,
               let uiImage = loadImageFromPath(imagePath) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 140, height: 200)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.purple.opacity(0.3), lineWidth: 2)
                    )
                    .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)
            } else {
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(
                        gradient: Gradient(colors: [Color.purple.opacity(0.2), Color.purple.opacity(0.1)]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 140, height: 200)
                    .overlay(
                        Image(systemName: "tv")
                            .font(.system(size: 40))
                            .foregroundColor(.purple.opacity(0.5))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.purple.opacity(0.3), lineWidth: 2)
                    )
            }
            
            // アニメタイトル
            Text(item.animeTitle)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 140)
            
            // エピソード番号（もしあれば）
            if let episode = item.episode {
                Text("第\(episode)話")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
            }
        }
    }
}

// iPad用の複数選択対応スケジュール追加シート
struct AddScheduleSheetForDate_iPad: View {
    let animeManager: AnimeManager
    let selectedDate: Date
    let onAdd: (Anime, Int?, String?) -> Void
    
    @State private var selectedAnimeIds: Set<String> = []
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 日付表示
                VStack(alignment: .leading, spacing: 8) {
                    Text(NSLocalizedString("watch_schedule_date", comment: "Watch schedule date"))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                    Text(formatDate(selectedDate))
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.purple)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal)
                
                // アニメ選択（複数選択可能）
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(NSLocalizedString("anime", comment: "Anime"))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.gray)
                        Spacer()
                        Text("\(selectedAnimeIds.count) " + NSLocalizedString("items_selected", comment: "items selected"))
                            .font(.system(size: 14))
                            .foregroundColor(.purple)
                    }
                    .padding(.horizontal)
                    
                    let validAnimes = animeManager.animes.filter { !$0.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
                    if validAnimes.isEmpty {
                        Text(NSLocalizedString("no_anime_registered", comment: "No anime registered"))
                            .font(.system(size: 16))
                            .foregroundColor(.gray)
                            .padding()
                            .frame(maxWidth: .infinity)
                    } else {
                        ScrollView {
                            VStack(spacing: 0) {
                                ForEach(validAnimes) { anime in
                                    HStack(spacing: 12) {
                                        // アニメサムネイル
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
                                            .lineLimit(2)
                                        
                                        Spacer()
                                        
                                        Image(systemName: selectedAnimeIds.contains(anime.id.uuidString) ? "checkmark.circle.fill" : "circle")
                                            .foregroundColor(selectedAnimeIds.contains(anime.id.uuidString) ? .purple : .gray)
                                            .font(.system(size: 24))
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
                                            .padding(.leading, 82)
                                    }
                                }
                            }
                            .background(Color.gray.opacity(0.05))
                            .cornerRadius(12)
                        }
                    }
                }
                
                Spacer()
            }
            .navigationTitle(NSLocalizedString("schedule_add_title", comment: "Add Schedule"))
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
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.locale = Locale.current
        return formatter.string(from: date)
    }
}