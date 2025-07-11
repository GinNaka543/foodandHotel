import SwiftUI
import PhotosUI
import UIKit
import Foundation
import Photos

// キャラクターデータ管理用のObservableObject
class CharacterManager: ObservableObject {
    @Published var characters: [Character] = []
    
    init() {
        // ★ 一時的なリセット処理は削除しました
        loadCharacters()
    }
    
    func loadCharacters() {
        if let data = UserDefaults.standard.data(forKey: "characters"),
           let decoded = try? JSONDecoder().decode([Character].self, from: data) {
            print("[DEBUG] loadCharacters: 読み込んだキャラ数=\(decoded.count)")
            for c in decoded { print("[DEBUG] キャラID=\(c.id), name=\(c.name), customFields=\(String(describing: c.customFields))") }
            characters = decoded
        } else {
            print("[DEBUG] loadCharacters: データなし or デコード失敗")
        }
    }
    
    func saveCharacters() {
        if let data = try? JSONEncoder().encode(characters) {
            UserDefaults.standard.set(data, forKey: "characters")
            print("[DEBUG] saveCharacters: 保存キャラ数=\(characters.count)")
            for c in characters { print("[DEBUG] 保存キャラID=\(c.id), name=\(c.name), customFields=\(String(describing: c.customFields))") }
            
            // Firebaseにも同期（現在のユーザープロファイルが存在する場合）
            if let profileData = UserDefaults.standard.data(forKey: "currentUserProfile"),
               let userProfile = try? JSONDecoder().decode(UserProfile.self, from: profileData) {
                print("キャラクター変更のFirebase同期開始")
                FirebaseManager.shared.saveUserProfile(userProfile) { result in
                    switch result {
                    case .success():
                        print("✅ キャラクター変更のFirebase同期成功")
                    case .failure(let error):
                        print("❌ キャラクター変更のFirebase同期エラー: \(error)")
                    }
                }
            }
        } else {
            print("[DEBUG] saveCharacters: エンコード失敗")
        }
    }
    
    func updateCharacter(_ updatedCharacter: Character) {
        print("[DEBUG] updateCharacter: 更新キャラID=\(updatedCharacter.id), name=\(updatedCharacter.name), customFields=\(String(describing: updatedCharacter.customFields))")
        if let idx = characters.firstIndex(where: { $0.id == updatedCharacter.id }) {
            characters[idx] = updatedCharacter
            saveCharacters()
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        } else {
            print("[DEBUG] updateCharacter: キャラID見つからず")
        }
    }
    
    func addCharacter(_ character: Character) {
        let exists = characters.contains { $0.id == character.id }
        print("[DEBUG] addCharacter: 追加キャラID=\(character.id), name=\(character.name), customFields=\(String(describing: character.customFields)), exists=\(exists)")
        if !exists {
            characters.append(character)
            saveCharacters()
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }
    
    // UI更新用のメソッド
    func refreshUI() {
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
}

// カスタムフィールド用構造体
struct CustomField: Hashable, Codable {
    var name: String
    var value: String
}

struct Character: Identifiable, Hashable, Equatable, Codable {
    let id: UUID
    var imageIdentifier: String? // PhotoライブラリのassetIdentifier
    var backgroundImagePath: String? // 背景画像のパス
    var name: String
    var tag: String
    var birthday: Date
    var favoriteFood: String
    var age: String // 年齢
    var voiceActor: String // 声優
    var cupSize: String // カップ数
    var seichi: String // 聖地
    var height: String // 身長
    var customFields: [CustomField]? // カスタムフィールド

    static func == (lhs: Character, rhs: Character) -> Bool {
        lhs.id == rhs.id
    }
    // Codable対応
    enum CodingKeys: String, CodingKey {
        case id, imageIdentifier, backgroundImagePath, name, tag, birthday, favoriteFood, age, voiceActor, cupSize, seichi, height, customFields
    }
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(tag, forKey: .tag)
        try container.encode(birthday, forKey: .birthday)
        try container.encode(favoriteFood, forKey: .favoriteFood)
        try container.encode(age, forKey: .age)
        try container.encode(voiceActor, forKey: .voiceActor)
        try container.encode(cupSize, forKey: .cupSize)
        try container.encode(seichi, forKey: .seichi)
        try container.encode(height, forKey: .height)
        try container.encodeIfPresent(imageIdentifier, forKey: .imageIdentifier)
        try container.encodeIfPresent(backgroundImagePath, forKey: .backgroundImagePath)
        try container.encodeIfPresent(customFields, forKey: .customFields)
    }
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        tag = try container.decode(String.self, forKey: .tag)
        birthday = try container.decode(Date.self, forKey: .birthday)
        favoriteFood = (try? container.decode(String.self, forKey: .favoriteFood)) ?? ""
        age = (try? container.decode(String.self, forKey: .age)) ?? ""
        voiceActor = (try? container.decode(String.self, forKey: .voiceActor)) ?? ""
        cupSize = (try? container.decode(String.self, forKey: .cupSize)) ?? ""
        seichi = (try? container.decode(String.self, forKey: .seichi)) ?? ""
        height = (try? container.decode(String.self, forKey: .height)) ?? ""
        imageIdentifier = try? container.decodeIfPresent(String.self, forKey: .imageIdentifier)
        backgroundImagePath = try? container.decodeIfPresent(String.self, forKey: .backgroundImagePath)
        customFields = try? container.decodeIfPresent([CustomField].self, forKey: .customFields)
    }
    init(id: UUID, imageIdentifier: String?, backgroundImagePath: String? = nil, name: String, tag: String, birthday: Date, favoriteFood: String = "", age: String, voiceActor: String, cupSize: String, seichi: String, height: String, customFields: [CustomField]? = nil) {
        self.id = id
        self.imageIdentifier = imageIdentifier
        self.backgroundImagePath = backgroundImagePath
        self.name = name
        self.tag = tag
        self.birthday = birthday
        self.favoriteFood = favoriteFood
        self.age = age
        self.voiceActor = voiceActor
        self.cupSize = cupSize
        self.seichi = seichi
        self.height = height
        self.customFields = customFields
    }
}

struct CharaScreen: View {
    @StateObject private var characterManager = CharacterManager()
    @State private var showAddSheet = false
    @State private var searchText = ""
    @State private var selectedCharacter: Character? = nil
    @State private var showMenu = false
    @EnvironmentObject var mainTab: MainTabSelection
    
    var filteredCharacters: [Character] {
        // Filter out characters without names first
        let charactersWithNames = characterManager.characters.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        
        if searchText.isEmpty { return charactersWithNames }
        return charactersWithNames.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.tag.localizedCaseInsensitiveContains(searchText) ||
            $0.birthday.formatted(.dateTime.year().month().day()).contains(searchText)
        }
    }

    var body: some View {
        ZStack {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    HStack {
                        // 左上メニューボタン
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showMenu.toggle()
                            }
                        }) {
                            Image(systemName: "line.horizontal.3")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.black)
                        }
                        Spacer()
                        // 右上＋ボタン
                        Button(action: { showAddSheet = true }) {
                            Text("キャラを追加")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    LinearGradient(
                                        gradient: Gradient(colors: [Color.purple, Color.purple.opacity(0.7)]),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .cornerRadius(20)
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
                // 広告バナー（検索バーと同じ幅に）
                SimpleAdBannerView()
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
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
                    .padding(.bottom, 75) // ナビゲーションバーの高さ分のパディング
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
                // 詳細画面を閉じた後にUIを更新
                characterManager.refreshUI()
            })
            .environmentObject(characterManager)
        }
        
        // サイドメニューをオーバーレイ
        if showMenu {
            SideMenuView(isShowing: $showMenu)
                .transition(.move(edge: .leading))
                .zIndex(1)
        }
    }
    }
    // UserDefaults保存・読込
    private func saveCharacters() {
        characterManager.saveCharacters()
    }
}

struct HeaderView: View {
    @Binding var showAddSheet: Bool
    @Binding var showSearchBar: Bool
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Text("Chara")
                    .font(.system(size: 32, weight: .bold))
                Spacer()
                HStack(spacing: 20) {
                    Button(action: { showSearchBar.toggle() }) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 17, weight: .medium))
                            .offset(y: 3)
                    }
                    Button(action: { showAddSheet = true }) {
                        Text("+")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.black)
                    }
                }
                .foregroundColor(.black)
                .padding(.trailing, 5)
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 4)
        }
    }
}

struct SearchBar: View {
    @Binding var text: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(Color(.systemGray3))
                .font(.system(size: 18))
            TextField("Search", text: $text)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .font(.system(size: 16))
                .foregroundColor(.black)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 14)
        .background(Color.white)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color(.systemGray4), lineWidth: 1)
        )
        .frame(height: 44)
        .padding(.horizontal, 16)
    }
}

struct CharacterRow: View {
    let character: Character
    @ObservedObject var characterManager: CharacterManager
    
    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            if let imageIdentifier = character.imageIdentifier, let image = UIImage(contentsOfFile: imageIdentifier) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 48, height: 48)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: "person")
                            .font(.system(size: 24))
                            .foregroundColor(.gray)
                    )
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(character.name)
                    .font(.system(size: 17, weight: .semibold))
                Text("#" + character.tag)
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
                    .lineLimit(1)
                    .frame(maxWidth: 200, alignment: .leading)
            }
            Spacer()
            Text(DateFormatter.monthDayEnglish.string(from: character.birthday))
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .padding(.top, 4)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .multilineTextAlignment(.trailing)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 0)
        .background(Color.clear)
        .contentShape(Rectangle())
    }
}

struct AddCharacterSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var characters: [Character]
    @EnvironmentObject private var characterManager: CharacterManager
    @State private var name = ""
    @State private var tag = ""
    @State private var birthday = Date()
    @State private var selectedItem: PhotosPickerItem? = nil
    @State private var image: UIImage? = nil
    // 月日Picker用
    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var selectedDay: Int = Calendar.current.component(.day, from: Date())

    var body: some View {
        NavigationView {
            Form {
                Section {
                    PhotosPicker(selection: $selectedItem, matching: .images) {
                        HStack {
                            if let image = image {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 60, height: 60)
                                    .clipShape(Circle())
                            } else {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 60, height: 60)
                                    .overlay(
                                        Image(systemName: "person")
                                            .font(.system(size: 28))
                                            .foregroundColor(.gray)
                                    )
                            }
                            Text("画像を選択")
                                .foregroundColor(.blue)
                        }
                    }
                    .onChange(of: selectedItem) { newValue in
                        if let newItem = newValue {
                            Task {
                                if let data = try? await newItem.loadTransferable(type: Data.self), let uiImage = UIImage(data: data) {
                                    image = uiImage
                                    // 画像をドキュメントディレクトリに保存
                                    let fileName = "icon_\(UUID().uuidString).png"
                                    _ = saveImageToDocuments(uiImage, fileName: fileName)
                                    // CharacterのimageIdentifierにパスを保存
                                    // 追加時に利用するため、必要ならここで変数にセット
                                }
                            }
                        }
                    }
                    TextField("名前", text: $name)
                    TextField("タグ", text: $tag)
                }
                Section {
                    // --- ここから月日Picker ---
                    HStack {
                        Text("誕生日")
                        Spacer()
                        Picker(selection: $selectedMonth, label: Text("月")) {
                            ForEach(1...12, id: \.self) { month in
                                Text("\(month)月").tag(month)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        Picker(selection: $selectedDay, label: Text("日")) {
                            ForEach(1...daysInMonth(selectedMonth), id: \.self) { day in
                                Text("\(day)日").tag(day)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                    }
                }
            }
            .navigationTitle("キャラ追加")
            .navigationBarItems(
                leading: Button("キャンセル") { dismiss() },
                trailing: Button("追加") {
                    print("[DEBUG] 追加ボタンタップ")
                    // 年は固定値（例：2000年）でDateを生成
                    let components = DateComponents(year: 2000, month: selectedMonth, day: selectedDay)
                    let calendar = Calendar.current
                    let date = calendar.date(from: components) ?? Date()
                    var imageIdentifier: String? = nil
                    if let image = image {
                        let fileName = "icon_\(UUID().uuidString).png"
                        imageIdentifier = saveImageToDocuments(image, fileName: fileName)
                    }
                    let newChar = Character(id: UUID(), imageIdentifier: imageIdentifier, name: name, tag: tag, birthday: date, favoriteFood: "", age: "", voiceActor: "", cupSize: "", seichi: "", height: "", customFields: nil)
                    // CharacterManagerのみを使用して追加（重複を防ぐ）
                    characterManager.addCharacter(newChar)
                    dismiss()
                }.disabled(name.isEmpty || tag.isEmpty)
            )
        }
    }
    // 月ごとの日数を返す
    private func daysInMonth(_ month: Int) -> Int {
        let calendar = Calendar.current
        let dateComponents = DateComponents(year: 2000, month: month)
        let date = calendar.date(from: dateComponents) ?? Date()
        return calendar.range(of: .day, in: .month, for: date)?.count ?? 30
    }
}


struct CharacterDetailView: View {
    @Binding var character: Character
    @Binding var characters: [Character]
    var onDismiss: (() -> Void)? = nil
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var characterManager: CharacterManager
    @State private var showArtwork = false
    @State private var showVideo = false
    @State private var showAbout = false
    @State private var showEditBackgroundModal = false
    @State private var showEditIconModal = false // ← 追加
    @State private var iconPickerItem: PhotosPickerItem? = nil
    @State private var iconImage: UIImage? = nil
    @State private var tempIconImage: UIImage? = nil
    @State private var backgroundPickerItem: PhotosPickerItem? = nil
    @State private var backgroundImage: UIImage? = nil

    var body: some View {
        ZStack {
            // 背景を最初に配置
            let currentCharacter = characterManager.characters.first(where: { $0.id == character.id }) ?? character
            
            // 背景画像 or グラデーション
            if let backgroundPath = currentCharacter.backgroundImagePath,
               let bgImage = UIImage(contentsOfFile: backgroundPath) {
                GeometryReader { geo in
                    Image(uiImage: bgImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
                .ignoresSafeArea()
                .overlay(Color.black.opacity(0.35).ignoresSafeArea())
                .onTapGesture {
                    showEditBackgroundModal = true
                }
            } else {
                LinearGradient(
                    gradient: Gradient(colors: [Color(red: 0.4, green: 0.6, blue: 0.9), Color(red: 0.3, green: 0.5, blue: 0.8)]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
                .onTapGesture {
                    showEditBackgroundModal = true
                }
            }
            
            // コンテンツ
            VStack(alignment: .leading) {
                // 戻るボタン
                HStack {
                    Button(action: {
                        if let onDismiss = onDismiss {
                            onDismiss()
                        } else {
                            presentationMode.wrappedValue.dismiss()
                        }
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .foregroundColor(.white)
                            Text("Back")
                                .foregroundColor(.white)
                                .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 1)
                        }
                    }
                    .padding(.top, 24)
                    .padding(.leading, 16)
                    
                    Spacer()
                }
                
                VStack {
                    Spacer().frame(height: 180)
                    // アイコン
                    ZStack {
                        if let imageIdentifier = currentCharacter.imageIdentifier, let image = UIImage(contentsOfFile: imageIdentifier) {
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                                .shadow(radius: 8)
                        } else {
                            ZStack {
                                Circle()
                                    .fill(Color(.systemGray5))
                                    .frame(width: 120, height: 120)
                                    .shadow(radius: 8)
                                    .overlay(
                                        Circle().stroke(Color.white, lineWidth: 2)
                                    )
                                Image(systemName: "person")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                            }
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture { showEditIconModal = true }
                    // 名前
                    Text(currentCharacter.name)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 1)
                        .padding(.top, 20)
                    // 誕生日
                    Text(DateFormatter.monthDayEnglish.string(from: currentCharacter.birthday).uppercased())
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                        .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 1)
                        .padding(.top, 4)
                    // ボタン群
                    HStack {
                        Spacer()
                        Button(action: { showArtwork = true }) {
                            VStack(spacing: 4) {
                                Image(systemName: "photo.on.rectangle")
                                    .foregroundColor(.white)
                                    .font(.system(size: 24))
                                Text("ArtWork").font(.caption2).foregroundColor(.white)
                            }
                            .frame(width: 80, height: 60)
                        }
                        .buttonStyle(PlainButtonStyle())
                        Spacer()
                        Button(action: { showVideo = true }) {
                            VStack(spacing: 4) {
                                Image(systemName: "video")
                                    .foregroundColor(.white)
                                    .font(.system(size: 24))
                                Text("Video").font(.caption2).foregroundColor(.white)
                            }
                            .frame(width: 80, height: 60)
                        }
                        .buttonStyle(PlainButtonStyle())
                        Spacer()
                        Button(action: { showAbout = true }) {
                            VStack(spacing: 4) {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.white)
                                    .font(.system(size: 24))
                                Text("About").font(.caption2).foregroundColor(.white)
                            }
                            .frame(width: 80, height: 60)
                        }
                        .buttonStyle(PlainButtonStyle())
                        Spacer()
                    }
                    .padding(.top, 40)
                    Spacer()
                }
                .zIndex(1)
            }
            // モーダル・ページ遷移
            .sheet(isPresented: $showEditIconModal) {
                VStack {
                    // ヘッダー部分
                    HStack {
                        Spacer()
                        Button(action: { 
                            showEditIconModal = false
                            tempIconImage = nil
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    
                    VStack(spacing: 24) {
                        Text("アイコンを選択")
                            .font(.system(size: 20, weight: .bold))
                            .padding(.top, 16)
                        
                        PhotosPicker(selection: $iconPickerItem, matching: .images) {
                            ZStack {
                                if let tempIconImage = tempIconImage {
                                    Image(uiImage: tempIconImage)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 150, height: 150)
                                        .clipShape(Circle())
                                } else if let imageIdentifier = currentCharacter.imageIdentifier, let image = UIImage(contentsOfFile: imageIdentifier) {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 150, height: 150)
                                        .clipShape(Circle())
                                } else {
                                    Circle()
                                        .fill(Color.gray.opacity(0.3))
                                        .frame(width: 150, height: 150)
                                        .overlay(
                                            Image(systemName: "photo")
                                                .font(.system(size: 40))
                                                .foregroundColor(.gray)
                                        )
                                }
                            }
                        }
                        .onChange(of: iconPickerItem) { newValue in
                            if let newItem = newValue {
                                Task {
                                    if let data = try? await newItem.loadTransferable(type: Data.self), let uiImage = UIImage(data: data) {
                                        tempIconImage = uiImage
                                        let fileName = "icon_\(UUID().uuidString).png"
                                        let imagePath = saveImageToDocuments(uiImage, fileName: fileName)
                                        
                                        // 古い画像ファイルを削除
                                        if let oldPath = currentCharacter.imageIdentifier {
                                            try? FileManager.default.removeItem(atPath: oldPath)
                                        }
                                        
                                        // 新しいCharacterオブジェクトを作成して更新
                                        var updatedCharacter = character
                                        updatedCharacter.imageIdentifier = imagePath
                                        
                                        // Bindingを通じて更新（これがsetterを呼び出す）
                                        character = updatedCharacter
                                        
                                        // モーダルを自動的に閉じる
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                            showEditIconModal = false
                                        }
                                    }
                                }
                            }
                        }
                        
                        Text("画像をタップして変更")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(.systemBackground))
                .onDisappear {
                    // モーダルが閉じたときにクリーンアップ
                    tempIconImage = nil
                    iconPickerItem = nil
                }
            }
            .sheet(isPresented: $showEditBackgroundModal) {
                EditBackgroundView(character: $character, characterManager: characterManager)
            }
            .fullScreenCover(isPresented: $showArtwork) {
                ArtworkScreen(character: character)
            }
            .fullScreenCover(isPresented: $showVideo) {
                VideoGalleryScreen(character: character)
            }
            .fullScreenCover(isPresented: $showAbout) {
                AboutView(characters: $characters, characterId: character.id, onClose: { showAbout = false })
                    .environmentObject(characterManager)
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            // デバッグ情報を表示
            let currentCharacter = characterManager.characters.first(where: { $0.id == character.id }) ?? character
            if let backgroundPath = currentCharacter.backgroundImagePath {
                print("[DEBUG] 背景画像パス: \(backgroundPath)")
                if UIImage(contentsOfFile: backgroundPath) != nil {
                    print("[DEBUG] 背景画像読み込み成功")
                } else {
                    print("[DEBUG] 背景画像読み込み失敗: \(backgroundPath)")
                }
            } else {
                print("[DEBUG] 背景画像パスがnil")
            }
        }
    }
}

// Helper functions
func saveImageToDocuments(_ image: UIImage, fileName: String) -> String? {
    guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
        return nil
    }
    
    let fileURL = documentsDirectory.appendingPathComponent(fileName)
    
    guard let data = image.pngData() else {
        return nil
    }
    
    do {
        try data.write(to: fileURL)
        return fileURL.path
    } catch {
        print("Error saving image: \(error)")
        return nil
    }
}

extension DateFormatter {
    static let monthDayEnglish: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "MMM d"
        return formatter
    }()
    
    static let monthDayJapanese: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateFormat = "M月d日"
        return formatter
    }()
}

struct AboutView: View {
    @Binding var characters: [Character]
    let characterId: UUID
    var onClose: () -> Void
    @State private var profileDescription: String = ""
    @State private var editedName: String = ""
    @State private var editedAge: String = ""
    @State private var editedFavoriteFood: String = ""
    @State private var editedVoiceActor: String = ""
    @State private var editedCupSize: String = ""
    @State private var editedBirthday: Date = Date()
    @State private var isEditingProfile: Bool = false
    @State private var isEditingDescription: Bool = false
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var characterManager: CharacterManager

    // characters配列から該当キャラを取得
    private var characterIndex: Int? {
        characters.firstIndex(where: { $0.id == characterId })
    }
    private var character: Character? {
        characterIndex.flatMap { characters[$0] }
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // プロフィールセクション
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("プロフィール")
                                .font(.system(size: 20, weight: .bold))
                            Button(action: { isEditingProfile.toggle() }) {
                                Image(systemName: isEditingProfile ? "checkmark.circle.fill" : "pencil")
                                    .font(.system(size: 16))
                                    .foregroundColor(.blue)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 20)
                        .padding(.bottom, 16)
                        
                        // プロフィール項目
                        VStack(spacing: 0) {
                            if isEditingProfile {
                                editableProfileRow(label: "名前", text: $editedName)
                                Divider().padding(.leading, 20)
                                dateProfileRow(label: "誕生日", date: $editedBirthday)
                                Divider().padding(.leading, 20)
                                editableProfileRow(label: "年齢", text: $editedAge)
                                Divider().padding(.leading, 20)
                                editableProfileRow(label: "好きな食べ物", text: $editedFavoriteFood)
                                Divider().padding(.leading, 20)
                                editableProfileRow(label: "声優", text: $editedVoiceActor)
                                Divider().padding(.leading, 20)
                                editableProfileRow(label: "カップ数", text: $editedCupSize)
                            } else {
                                profileRow(label: "名前", value: character?.name ?? "")
                                Divider().padding(.leading, 20)
                                profileRow(label: "誕生日", value: DateFormatter.monthDayJapanese.string(from: character?.birthday ?? Date()))
                                Divider().padding(.leading, 20)
                                profileRow(label: "年齢", value: character?.age ?? "未設定")
                                Divider().padding(.leading, 20)
                                profileRow(label: "好きな食べ物", value: character?.favoriteFood ?? "未設定")
                                Divider().padding(.leading, 20)
                                profileRow(label: "声優", value: character?.voiceActor ?? "未設定")
                                if let cupSize = character?.cupSize, !cupSize.isEmpty {
                                    Divider().padding(.leading, 20)
                                    profileRow(label: "カップ数", value: cupSize)
                                }
                            }
                        }
                        .background(Color.white)
                    }
                    
                    // 概要セクション
                    VStack(alignment: .leading, spacing: 0) {
                        HStack {
                            Text("概要")
                                .font(.system(size: 20, weight: .bold))
                            Button(action: { 
                                isEditingDescription.toggle()
                            }) {
                                Image(systemName: isEditingDescription ? "checkmark.circle.fill" : "pencil")
                                    .font(.system(size: 16))
                                    .foregroundColor(.blue)
                            }
                            Spacer()
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 32)
                        .padding(.bottom, 16)
                        
                        // 概要テキスト
                        if isEditingDescription {
                            ZStack(alignment: .topLeading) {
                                if profileDescription.isEmpty {
                                    Text("概要を入力してください...")
                                        .font(.system(size: 16))
                                        .foregroundColor(.gray)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 16)
                                }
                                
                                TextEditor(text: $profileDescription)
                                    .font(.system(size: 16))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .frame(minHeight: 200)
                                    .scrollContentBackground(.hidden)
                                    .background(Color.clear)
                            }
                            .background(Color.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .padding(.horizontal, 20)
                        } else {
                            if profileDescription.isEmpty {
                                Text("概要が未設定です")
                                    .font(.system(size: 16))
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 16)
                            } else {
                                Text(profileDescription)
                                    .font(.system(size: 16))
                                    .foregroundColor(.primary)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 16)
                            }
                        }
                    }
                    
                    Spacer(minLength: 50)
                }
            }
            .background(Color(.systemGray6))
            .navigationBarTitle("About", displayMode: .inline)
            .navigationBarItems(
                leading: Button("閉じる") {
                    saveCharacter()
                    onClose()
                }
            )
        }
        .onAppear {
            loadCharacterDescription()
            if let character = character {
                editedName = character.name
                editedAge = character.age
                editedFavoriteFood = character.favoriteFood
                editedVoiceActor = character.voiceActor
                editedCupSize = character.cupSize
                editedBirthday = character.birthday
            }
        }
        .onDisappear {
            saveCharacter()
        }
    }
    
    // MARK: - Helper Views
    private func profileRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
            Text(value)
                .font(.system(size: 16))
                .foregroundColor(.primary)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    private func editableProfileRow(label: String, text: Binding<String>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
            TextField("未設定", text: text)
                .font(.system(size: 16))
                .foregroundColor(.primary)
                .textFieldStyle(RoundedBorderTextFieldStyle())
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
    
    private func dateProfileRow(label: String, date: Binding<Date>) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 16))
                .foregroundColor(.secondary)
                .frame(width: 120, alignment: .leading)
            
            // 月と日のみ選択できるPicker
            HStack {
                Picker("月", selection: Binding(
                    get: { Calendar.current.component(.month, from: date.wrappedValue) },
                    set: { newMonth in
                        let components = Calendar.current.dateComponents([.year, .month, .day], from: date.wrappedValue)
                        if let newDate = Calendar.current.date(from: DateComponents(year: components.year, month: newMonth, day: components.day)) {
                            date.wrappedValue = newDate
                        }
                    }
                )) {
                    ForEach(1...12, id: \.self) { month in
                        Text("\(month)月").tag(month)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                Picker("日", selection: Binding(
                    get: { Calendar.current.component(.day, from: date.wrappedValue) },
                    set: { newDay in
                        let components = Calendar.current.dateComponents([.year, .month, .day], from: date.wrappedValue)
                        if let newDate = Calendar.current.date(from: DateComponents(year: components.year, month: components.month, day: newDay)) {
                            date.wrappedValue = newDate
                        }
                    }
                )) {
                    let month = Calendar.current.component(.month, from: date.wrappedValue)
                    let daysInMonth = Calendar.current.range(of: .day, in: .month, for: date.wrappedValue)?.count ?? 30
                    ForEach(1...daysInMonth, id: \.self) { day in
                        Text("\(day)日").tag(day)
                    }
                }
                .pickerStyle(MenuPickerStyle())
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
    
    // MARK: - Helper Methods
    private func loadCharacterDescription() {
        guard let character = character else { return }
        // カスタムフィールドから"概要"フィールドを探す
        if let customFields = character.customFields,
           let descriptionField = customFields.first(where: { $0.name == "概要" }) {
            profileDescription = descriptionField.value
        }
    }
    
    private func saveCharacter() {
        guard let idx = characters.firstIndex(where: { $0.id == characterId }) else { return }
        
        // 編集中の場合は編集内容を保存
        var updatedCharacter = characters[idx]
        
        if isEditingProfile {
            updatedCharacter.name = editedName
            updatedCharacter.age = editedAge
            updatedCharacter.favoriteFood = editedFavoriteFood
            updatedCharacter.voiceActor = editedVoiceActor
            updatedCharacter.cupSize = editedCupSize
            updatedCharacter.birthday = editedBirthday
        }
        
        // 概要をカスタムフィールドに保存
        if updatedCharacter.customFields == nil {
            updatedCharacter.customFields = []
        }
        
        // 既存の"概要"フィールドを更新または新規作成
        if let index = updatedCharacter.customFields?.firstIndex(where: { $0.name == "概要" }) {
            updatedCharacter.customFields?[index].value = profileDescription
        } else {
            updatedCharacter.customFields?.append(CustomField(name: "概要", value: profileDescription))
        }
        
        characters[idx] = updatedCharacter
        characterManager.updateCharacter(updatedCharacter)
    }
}

// --- 追加: 高さ自動調整＆空行削除付きTextEditor ---
struct AutoSizingTextEditor: UIViewRepresentable {
    @Binding var text: String
    var minHeight: CGFloat = 36
    var font: UIFont = .systemFont(ofSize: 17)
    var onEndEditing: (() -> Void)? = nil

    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.isScrollEnabled = false
        textView.font = font
        textView.delegate = context.coordinator
        textView.backgroundColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
        return textView
    }
    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
        }
        // 行数分だけ高さを強制（空行は含めない）
        let lines = text.components(separatedBy: "\n").filter { !$0.isEmpty }
        let lineCount = max(1, lines.count)
        let lineHeight = font.lineHeight
        let padding: CGFloat = 16 // 上下8ずつ
        let totalHeight = CGFloat(lineCount) * lineHeight + padding
        if uiView.constraints.first(where: { $0.identifier == "height" }) == nil {
            let heightConstraint = uiView.heightAnchor.constraint(equalToConstant: minHeight)
            heightConstraint.identifier = "height"
            heightConstraint.isActive = true
        }
        uiView.constraints.first(where: { $0.identifier == "height" })?.constant = max(minHeight, totalHeight)
        uiView.textContainerInset = UIEdgeInsets(top: 8, left: 4, bottom: 8, right: 4)
    }
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: AutoSizingTextEditor
        init(_ parent: AutoSizingTextEditor) { self.parent = parent }
        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text ?? ""
        }
        func textViewDidEndEditing(_ textView: UITextView) {
            // 空行を削除
            let lines = (textView.text ?? "").components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
            parent.text = lines.joined(separator: "\n")
            parent.onEndEditing?()
        }
    }
}
// --- ここまで追加 ---

// 文字列をn文字ごとに分割するchunked拡張を追加
extension String {
    func chunked(_ length: Int) -> [String] {
        var result: [String] = []
        var start = startIndex
        while start < endIndex {
            let end = index(start, offsetBy: length, limitedBy: endIndex) ?? endIndex
            result.append(String(self[start..<end]))
            start = end
        }
        return result
    }
}

struct NavigationBarItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            if icon == "visit_event_icon" {
                Image(icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 22, height: 22)
                    .foregroundColor(isSelected ? .blue : .gray)
            } else {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(isSelected ? .blue : .gray)
            }
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(isSelected ? .blue : .gray)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 75)
    }
}

struct EditBackgroundView: View {
    @Binding var character: Character
    @ObservedObject var characterManager: CharacterManager
    @State private var backgroundPickerItem: PhotosPickerItem? = nil
    @State private var backgroundImage: UIImage? = nil
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("背景画像を選択")
                    .font(.headline)
                
                PhotosPicker(selection: $backgroundPickerItem, matching: .images) {
                    VStack {
                        if let backgroundImage = backgroundImage {
                            Image(uiImage: backgroundImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 200)
                                .clipped()
                                .cornerRadius(12)
                        } else if let imagePath = character.backgroundImagePath,
                                  let uiImage = UIImage(contentsOfFile: imagePath) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 200)
                                .clipped()
                                .cornerRadius(12)
                        } else {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color.gray.opacity(0.3))
                                .frame(height: 200)
                                .overlay(
                                    VStack {
                                        Image(systemName: "photo.fill")
                                            .font(.system(size: 50))
                                            .foregroundColor(.gray)
                                        Text("背景画像を選択")
                                            .foregroundColor(.gray)
                                    }
                                )
                        }
                    }
                }
                .onChange(of: backgroundPickerItem) { newValue in
                    if let newItem = newValue {
                        Task {
                            if let data = try? await newItem.loadTransferable(type: Data.self),
                               let uiImage = UIImage(data: data) {
                                backgroundImage = uiImage
                            }
                        }
                    }
                }
                
                Spacer()
                
                HStack(spacing: 20) {
                    Button("キャンセル") {
                        dismiss()
                    }
                    .foregroundColor(.red)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(Color(.systemGray6))
                    .cornerRadius(10)
                    
                    Button("保存") {
                        if let image = backgroundImage {
                            let fileName = "bg_\(UUID().uuidString).png"
                            if let imagePath = saveImageToDocuments(image, fileName: fileName) {
                                // 古い画像を削除
                                if let oldPath = character.backgroundImagePath {
                                    try? FileManager.default.removeItem(atPath: oldPath)
                                }
                                
                                // 新しいCharacterオブジェクトを作成して更新
                                var updatedCharacter = character
                                updatedCharacter.backgroundImagePath = imagePath
                                
                                // Bindingを通じて更新
                                character = updatedCharacter
                                
                                dismiss()
                            }
                        }
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 30)
                    .padding(.vertical, 12)
                    .background(backgroundImage != nil ? Color.blue : Color.gray)
                    .cornerRadius(10)
                    .disabled(backgroundImage == nil)
                }
                .padding(.bottom, 30)
            }
            .padding()
            .navigationBarTitle("背景画像を変更", displayMode: .inline)
            .navigationBarItems(
                trailing: Button(action: { dismiss() }) {
                    Image(systemName: "xmark")
                        .foregroundColor(.gray)
                }
            )
        }
    }
}

#Preview {
    CharaScreen()
}
