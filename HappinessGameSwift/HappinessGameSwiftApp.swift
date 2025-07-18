import SwiftUI
import FirebaseCore
import StripePaymentSheet

class MainTabSelection: ObservableObject {
    @Published var selectedTab: MainContainerView.Tab = .chara {
        didSet {
            print("🔄 [MainTabSelection] タブ変更: \(oldValue.title) → \(selectedTab.title)")
        }
    }
}

class AuthenticationManager: ObservableObject {
    @Published var isLoggedIn: Bool = UserDefaults.standard.bool(forKey: "isLoggedIn")
    
    func login() {
        isLoggedIn = true
    }
    
    func logout() {
        UserDefaults.standard.removeObject(forKey: "userId")
        UserDefaults.standard.removeObject(forKey: "username")
        UserDefaults.standard.removeObject(forKey: "isLoggedIn")
        isLoggedIn = false
    }
}

@main
struct HappinessGameSwiftApp: App {
    @StateObject private var mainTab = MainTabSelection()
    @StateObject private var characterManager = CharacterManager()
    @StateObject private var animeManager = AnimeManager()
    @StateObject private var productManager = ProductManager()
    @StateObject private var authManager = AuthenticationManager()
    
    init() {
        FirebaseApp.configure()
        
        // Stripe SDKを初期化
        StripeAPI.defaultPublishableKey = "pk_live_51RjjWjD7PsaPGu6xz0RGH0Gnw36ORTqI9pjec4ycPMlxAQ8biO4igeEMwoKZxdwhB8EJGeW947jmgaCWNKZi3ZTR005t6UHTLA"
        
        cleanupLargeUserDefaultsEntries()
        // 画像パスの移行処理を実行
        ImageMigrationHelper.shared.migrateAllImagePaths()
    }
    
    var body: some Scene {
        WindowGroup {
            if authManager.isLoggedIn {
                MainContainerView()
                    .environmentObject(mainTab)
                    .environmentObject(characterManager)
                    .environmentObject(animeManager)
                    .environmentObject(productManager)
                    .environmentObject(authManager)
                    .onAppear {
                        // 開発用: サンプル画像を自動生成
                        createSampleImagesIfNeeded()
                        // ユーザーIDを確認
                        if let userId = UserDefaults.standard.string(forKey: "userId") {
                            print("✅ ログイン済み: userId=\(userId)")
                        }
                    }
            } else {
                AuthSelectionView(authManager: authManager)
            }
        }
    }
    
    func cleanupLargeUserDefaultsEntries() {
        let userDefaults = UserDefaults.standard
        let keys = userDefaults.dictionaryRepresentation().keys
        for key in keys {
            if key.hasPrefix("artworks_") || key.hasPrefix("videos_") {
                if let data = userDefaults.data(forKey: key), data.count >= 4_000_000 {
                    userDefaults.removeObject(forKey: key)
                    print("[CLEANUP] Removed large UserDefaults entry: \(key), size: \(data.count)")
                }
            }
        }
    }
}

// メインコンテナビュー - ナビゲーションバーを固定し、上部コンテンツのみを切り替え
struct MainContainerView: View {
    @EnvironmentObject var mainTab: MainTabSelection
    @EnvironmentObject var characterManager: CharacterManager
    @EnvironmentObject var animeManager: AnimeManager
    @EnvironmentObject var authManager: AuthenticationManager
    @State private var showingTermsOfService = false
    
    enum Tab: Int, CaseIterable {
        case home = 0
        case chara = 1
        case anime = 2
        case visit = 3
        case card = 4
        
        var icon: String {
            switch self {
            case .home: return "house"
            case .chara: return "person.2"
            case .anime: return "tv"
            case .visit: return "link"
            case .card: return "shippingbox"
            }
        }
        
        var title: String {
            switch self {
            case .home: return "ホーム"
            case .chara: return "キャラ"
            case .anime: return "アニメ"
            case .visit: return "聖地旅"
            case .card: return "プロダクト"
            }
        }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // 上部コンテンツエリア
            VStack(spacing: 0) {
                // 選択されたタブに応じてコンテンツを表示
                VStack {
                    Group {
                        if mainTab.selectedTab == .home {
                            HomeScreen()
                                .environmentObject(mainTab)
                                .environmentObject(authManager)
                                .environmentObject(characterManager)
                                .environmentObject(animeManager)
                        } else if mainTab.selectedTab == .chara {
                            CharaScreen()
                                .environmentObject(mainTab)
                                .environmentObject(characterManager)
                        } else if mainTab.selectedTab == .anime {
                            AnimeScreen()
                                .environmentObject(mainTab)
                                .environmentObject(animeManager)
                        } else if mainTab.selectedTab == .visit {
                            VisitScreen()
                        } else if mainTab.selectedTab == .card {
                            ProductScreen()
                        }
                    }
                    .animation(nil, value: mainTab.selectedTab)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // ナビゲーションバーの高さ分のスペース
                Spacer().frame(height: 75)
            }
            
            // 固定の下部ナビゲーションバー
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 0) {
                    ForEach(Tab.allCases, id: \.rawValue) { tab in
                        NavigationBarItem(
                            icon: tab.icon,
                            title: tab.title,
                            isSelected: mainTab.selectedTab == tab,
                            onTap: {
                                print("🔄 [Tab] \(mainTab.selectedTab.title) → \(tab.title)")
                                // 即座にタブを切り替える（アニメーション削除）
                                mainTab.selectedTab = tab
                            }
                        )
                    }
                }
                .frame(height: 75)
                .background(Color.white)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(Color(.systemGray4)),
                    alignment: .top
                )
            }
            .edgesIgnoringSafeArea(.bottom)
        }
        .background(Color.white)
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("ShowTermsOfService"))) { _ in
            showingTermsOfService = true
        }
        .fullScreenCover(isPresented: $showingTermsOfService) {
            TermsOfServiceView()
        }
    }
}

// 各タブのコンテンツビュー
struct HomeContentView: View {
    @Binding var selectedTab: MainContainerView.Tab
    var body: some View {
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
                ForEach(["Birthday reminders", "Friends", "Groups"], id: \.self) { name in
                    HStack {
                        Circle().fill(Color.gray).frame(width: 40, height: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(name)
                                .font(.system(size: 16, weight: .semibold))
                            Text("サンプル説明")
                                .font(.system(size: 13))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Text("2")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 6)
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
}

struct CharaContentView: View {
    @StateObject private var characterManager = CharacterManager()
    @State private var showAddSheet = false
    @State private var searchText = ""
    @State private var selectedCharacter: Character? = nil
    @State private var showMenu = false
    @Binding var selectedTab: MainContainerView.Tab
    
    var filteredCharacters: [Character] {
        if searchText.isEmpty { return characterManager.characters }
        return characterManager.characters.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.tag.localizedCaseInsensitiveContains(searchText) ||
            $0.birthday.formatted(.dateTime.year().month().day()).contains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                // 左上メニューボタン
                Button(action: {
                    showMenu.toggle()
                }) {
                    Image(systemName: "line.horizontal.3")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.black)
                }
                Spacer()
                // 右上＋ボタン
                Button(action: { showAddSheet = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.black)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            // 検索バー
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color(.systemGray3))
                    .font(.system(size: 18))
                TextField("Search", text: $searchText)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .font(.system(size: 16))
                    .foregroundColor(.black)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
            .background(Color.white)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
            .frame(height: 38)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            
            // 広告バナー
            SimpleAdBannerView()
                .padding(.vertical, 2)
            
            // キャラリストのみスクロール
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(filteredCharacters, id: \.id) { character in
                        Button(action: {
                            selectedCharacter = character
                        }) {
                            CharacterRow(character: character, characterManager: characterManager)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .sheet(isPresented: $showAddSheet, onDismiss: {
            characterManager.loadCharacters()
        }) {
            AddCharacterSheet(characters: $characterManager.characters)
                .environmentObject(characterManager)
        }
        .fullScreenCover(item: $selectedCharacter) { character in
            CharacterDetailView(character: Binding(
                get: { character },
                set: { newCharacter in
                    if let idx = characterManager.characters.firstIndex(where: { $0.id == character.id }) {
                        characterManager.characters[idx] = newCharacter
                        characterManager.updateCharacter(newCharacter)
                    }
                    selectedCharacter = newCharacter
                }
            ), characters: $characterManager.characters, onDismiss: { 
                selectedCharacter = nil
                characterManager.refreshUI()
            })
            .environmentObject(characterManager)
        }
    }
}

struct AnimeContentView: View {
    @StateObject private var animeManager = AnimeManager()
    @State private var showAddSheet = false
    @State private var searchText = ""
    @State private var selectedAnime: Anime? = nil
    @State private var showMenu = false
    @Binding var selectedTab: MainContainerView.Tab
    
    var filteredAnimes: [Anime] {
        if searchText.isEmpty { return animeManager.animes }
        return animeManager.animes.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.hashtag.localizedCaseInsensitiveContains(searchText) ||
            $0.releaseDate.formatted(.dateTime.year().month().day()).contains(searchText)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: {
                    showMenu.toggle()
                }) {
                    Image(systemName: "line.horizontal.3")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.black)
                }
                Spacer()
                Button(action: { showAddSheet = true }) {
                    Image(systemName: "plus")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.black)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(Color(.systemGray3))
                    .font(.system(size: 18))
                TextField("Search", text: $searchText)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
                    .font(.system(size: 16))
                    .foregroundColor(.black)
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
            .background(Color.white)
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
            .frame(height: 38)
            .padding(.horizontal, 12)
            .padding(.top, 8)
            
            // 広告バナー
            SimpleAdBannerView()
                .padding(.vertical, 2)
            
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(filteredAnimes, id: \.id) { anime in
                        Button(action: {
                            selectedAnime = anime
                        }) {
                            AnimeRow(anime: anime, animeManager: animeManager)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .sheet(isPresented: $showAddSheet, onDismiss: {
            animeManager.loadAnimes()
        }) {
            AddAnimeSheet(animes: $animeManager.animes)
                .environmentObject(animeManager)
        }
        .fullScreenCover(item: $selectedAnime) { anime in
            AnimeDetailView(anime: Binding(
                get: { anime },
                set: { newAnime in
                    if let idx = animeManager.animes.firstIndex(where: { $0.id == anime.id }) {
                        animeManager.animes[idx] = newAnime
                        animeManager.updateAnime(newAnime)
                    }
                }
            ), animes: $animeManager.animes)
            .environmentObject(animeManager)
        }
    }

}

struct VisitContentView: View {
    @Binding var selectedTab: MainContainerView.Tab
    var body: some View {
        VStack {
            Text("Visit Screen")
                .font(.title)
            Text("Coming Soon...")
                .foregroundColor(.gray)
        }
    }
}

struct CardContentView: View {
    @Binding var selectedTab: MainContainerView.Tab
    var body: some View {
        VStack {
            Text("Card Screen")
                .font(.title)
            Text("Coming Soon...")
                .foregroundColor(.gray)
        }
    }
}

 