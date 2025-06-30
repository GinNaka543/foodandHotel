import SwiftUI
import PhotosUI
import UIKit
import Foundation

// キャラクターデータ管理用のObservableObject
class CharacterManager: ObservableObject {
    @Published var characters: [Character] = []
    
    init() {
        loadCharacters()
    }
    
    func loadCharacters() {
        if let data = UserDefaults.standard.data(forKey: "characters"),
           let decoded = try? JSONDecoder().decode([Character].self, from: data) {
            characters = decoded
        }
    }
    
    func saveCharacters() {
        if let data = try? JSONEncoder().encode(characters) {
            UserDefaults.standard.set(data, forKey: "characters")
        }
    }
    
    func updateCharacter(_ updatedCharacter: Character) {
        if let idx = characters.firstIndex(where: { $0.id == updatedCharacter.id }) {
            characters[idx] = updatedCharacter
            saveCharacters()
            // UIを強制的に更新
            DispatchQueue.main.async {
                self.objectWillChange.send()
            }
        }
    }
    
    func addCharacter(_ character: Character) {
        // 重複チェックを追加
        let exists = characters.contains { $0.id == character.id }
        if !exists {
            characters.append(character)
            saveCharacters()
            // UIを強制的に更新
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

struct Character: Identifiable, Hashable, Equatable, Codable {
    let id: UUID
    var imagePath: String? // 画像ファイルのパス
    var name: String
    var tag: String
    var birthday: Date
    var favoriteFood: String
    var age: String // 年齢
    var voiceActor: String // 声優
    var cupSize: String // カップ数
    var seichi: String // 聖地
    var height: String // 身長

    static func == (lhs: Character, rhs: Character) -> Bool {
        lhs.id == rhs.id
    }
    // Codable対応
    enum CodingKeys: String, CodingKey {
        case id, imagePath, name, tag, birthday, favoriteFood, age, voiceActor, cupSize, seichi, height
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
        try container.encodeIfPresent(imagePath, forKey: .imagePath)
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
        imagePath = try? container.decodeIfPresent(String.self, forKey: .imagePath)
    }
    init(id: UUID, imagePath: String?, name: String, tag: String, birthday: Date, favoriteFood: String = "", age: String, voiceActor: String, cupSize: String, seichi: String, height: String) {
        self.id = id
        self.imagePath = imagePath
        self.name = name
        self.tag = tag
        self.birthday = birthday
        self.favoriteFood = favoriteFood
        self.age = age
        self.voiceActor = voiceActor
        self.cupSize = cupSize
        self.seichi = seichi
        self.height = height
    }
}

struct CharaScreen: View {
    @StateObject private var characterManager = CharacterManager()
    @State private var showAddSheet = false
    @State private var searchText = ""
    @State private var selectedCharacter: Character? = nil
    @State private var showMenu = false
    
    var filteredCharacters: [Character] {
        if searchText.isEmpty { return characterManager.characters }
        return characterManager.characters.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.tag.localizedCaseInsensitiveContains(searchText) ||
            $0.birthday.formatted(.dateTime.year().month().day()).contains(searchText)
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
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
                AdBannerView()
                    .padding(.vertical, 2)
                // キャラリストのみスクロール
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(filteredCharacters, id: \ .id) { character in
                            Button(action: {
                                selectedCharacter = character
                            }) {
                                CharacterRow(character: character, characterManager: characterManager)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                            }
                            .buttonStyle(PlainButtonStyle())
                            Divider()
                        }
                    }
                    .padding(.bottom, 75) // ナビゲーションバーの高さ分のパディング
                }
            }
            
            // 下部ナビゲーションバー
            VStack(spacing: 0) {
                Spacer()
                HStack(spacing: 0) {
                    NavigationBarItem(icon: "house", title: "Home", isSelected: true)
                    NavigationBarItem(icon: "person.2", title: "Chara", isSelected: false)
                    NavigationBarItem(icon: "tv", title: "Anime", isSelected: false)
                    NavigationBarItem(icon: "map", title: "Visit", isSelected: false)
                    NavigationBarItem(icon: "creditcard", title: "Card", isSelected: false)
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
        }
        .sheet(isPresented: $showAddSheet, onDismiss: {
            // キャラクター追加後にリストを更新
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
            if let imagePath = character.imagePath, let image = loadImageFromPath(imagePath) {
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
                .onChange(of: selectedItem) { _, newItem in
                    if let newItem = newItem {
                        Task {
                            if let data = try? await newItem.loadTransferable(type: Data.self),
                               let uiImage = UIImage(data: data) {
                                image = uiImage
                            }
                        }
                    }
                }
                TextField("名前", text: $name)
                TextField("タグ", text: $tag)
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
            .navigationTitle("キャラ追加")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        // 年は固定値（例：2000年）でDateを生成
                        let components = DateComponents(year: 2000, month: selectedMonth, day: selectedDay)
                        let calendar = Calendar.current
                        let date = calendar.date(from: components) ?? Date()
                        var imagePath: String? = nil
                        if let image = image {
                            let fileName = "icon_\(UUID().uuidString).png"
                            imagePath = saveImageToDocuments(image, fileName: fileName)
                        }
                        let newChar = Character(id: UUID(), imagePath: imagePath, name: name, tag: tag, birthday: date, favoriteFood: "", age: "", voiceActor: "", cupSize: "", seichi: "", height: "")
                        // CharacterManagerのみを使用して追加（重複を防ぐ）
                        characterManager.addCharacter(newChar)
                        dismiss()
                    }.disabled(name.isEmpty || tag.isEmpty)
                }
            }
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

struct AdBannerView: View {
    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("【スタバ新作✨】")
                    .font(.system(size: 16, weight: .bold))
                Text("飲んでみた正直な感想😄")
                    .font(.system(size: 15, weight: .regular))
                Text("Trending on LINE VOOM")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }
            .padding(.leading, 9)
            Spacer()
            Image("かのかり")
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 63, height: 63)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .padding(12)
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
    // 編集用の状態変数
    @State private var showEditNameModal = false
    @State private var showEditBirthdayModal = false
    @State private var showEditIconModal = false
    @State private var editName: String = ""
    @State private var editBirthday: Date = Date()
    @State private var iconPickerItem: PhotosPickerItem? = nil
    @State private var iconImage: UIImage? = nil

    var body: some View {
        GeometryReader { geometry in
            // characterManagerから最新のキャラクター情報を取得
            let currentCharacter = characterManager.characters.first(where: { $0.id == character.id }) ?? character
            let nameText = currentCharacter.name
            let birthdayText = DateFormatter.monthDayEnglish.string(from: currentCharacter.birthday)
            ZStack(alignment: .topLeading) {
                Color(.systemBackground).ignoresSafeArea()
                Button(action: {
                    if let onDismiss = onDismiss {
                        onDismiss()
                    } else {
                        presentationMode.wrappedValue.dismiss()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.black)
                            .font(.system(size: 18, weight: .medium))
                        Text("Back")
                            .foregroundColor(.black)
                            .font(.system(size: 17, weight: .medium))
                    }
                }
                .padding(.top, 24)
                .padding(.leading, 16)
                // アイコン
                VStack {
                    Spacer().frame(height: 180 + 50) // 50px下げる
                    if let imagePath = currentCharacter.imagePath, let image = loadImageFromPath(imagePath) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .shadow(radius: 8)
                            .contentShape(Rectangle())
                            .onTapGesture { 
                                showEditIconModal = true 
                                if iconImage == nil, let imagePath = currentCharacter.imagePath, let current = UIImage(contentsOfFile: imagePath) {
                                    iconImage = current
                                }
                            }
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 120, height: 120)
                            .shadow(radius: 8)
                            .overlay(
                                Image(systemName: "person")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture { 
                                showEditIconModal = true 
                                if iconImage == nil, let imagePath = currentCharacter.imagePath, let current = UIImage(contentsOfFile: imagePath) {
                                    iconImage = current
                                }
                            }
                    }
                    // 名前
                    Text(nameText)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.top, 20)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .onTapGesture { 
                            editName = currentCharacter.name
                            showEditNameModal = true 
                        }
                    // 誕生日
                    Text(birthdayText.uppercased())
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                        .padding(.top, 8)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .onTapGesture { 
                            editBirthday = currentCharacter.birthday
                            showEditBirthdayModal = true 
                        }
                    // ナビゲーションバー（誕生日の直下、背景なし）
                    HStack {
                        Spacer()
                        Button(action: { showArtwork = true }) {
                            VStack {
                                Image(systemName: "photo.on.rectangle")
                                Text("ArtWork").font(.caption2)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        Spacer()
                        Button(action: { showVideo = true }) {
                            VStack {
                                Image(systemName: "video")
                                Text("Video").font(.caption2)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        Spacer()
                        Button(action: { showAbout = true }) {
                            VStack {
                                Image(systemName: "info.circle")
                                Text("About").font(.caption2)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        Spacer()
                        VStack {
                            Image(systemName: "link")
                            Text("Visit").font(.caption2)
                        }
                        Spacer()
                    }
                    .padding(.top, 60)
                    .fullScreenCover(isPresented: $showArtwork) {
                        ArtworkScreen(character: character)
                    }
                    .fullScreenCover(isPresented: $showVideo) {
                        VideoGalleryScreen(character: character)
                    }
                    .fullScreenCover(isPresented: $showAbout) {
                        AboutView(character: $character, characters: $characters, onClose: { showAbout = false })
                            .environmentObject(characterManager)
                    }
                }
                .frame(width: geometry.size.width)
            }
        }
        .navigationBarHidden(true)
        // 名前編集モーダル
        .sheet(isPresented: $showEditNameModal) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 20) {
                    Spacer()
                    Text("名前を編集")
                        .font(.headline)
                    HStack {
                        Spacer()
                        TextField("名前", text: $editName)
                            .frame(width: 250)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        Spacer()
                    }
                    Button("保存") { 
                        var updatedCharacter = character
                        updatedCharacter.name = editName
                        character = updatedCharacter
                        characterManager.updateCharacter(updatedCharacter)
                        if let idx = characters.firstIndex(where: { $0.id == character.id }) {
                            characters[idx] = updatedCharacter
                        }
                        // 親のselectedCharacterも更新
                        if let parentIdx = characterManager.characters.firstIndex(where: { $0.id == character.id }) {
                            characterManager.characters[parentIdx] = updatedCharacter
                        }
                        characterManager.refreshUI()
                        showEditNameModal = false 
                    }
                    Spacer()
                }
                Button(action: { showEditNameModal = false }) {
                    Text("閉じる")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(.blue)
                        .padding(.top, 16)
                        .padding(.trailing, 16)
                }
            }
            .ignoresSafeArea(.container, edges: .top)
            .onAppear {
                editName = character.name
            }
        }
        // 誕生日編集モーダル
        .sheet(isPresented: $showEditBirthdayModal) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 20) {
                    Text("誕生日を編集")
                        .font(.headline)
                    HStack(spacing: 16) {
                        Picker("月", selection: Binding(get: {
                            Calendar.current.component(.month, from: editBirthday)
                        }, set: { newMonth in
                            let day = Calendar.current.component(.day, from: editBirthday)
                            let year = 2000 // 年は固定
                            let newDate = Calendar.current.date(from: DateComponents(year: year, month: newMonth, day: day)) ?? editBirthday
                            editBirthday = newDate
                        })) {
                            ForEach(1...12, id: \.self) { month in
                                Text("\(month)月").tag(month)
                            }
                        }
                        Picker("日", selection: Binding(get: {
                            Calendar.current.component(.day, from: editBirthday)
                        }, set: { newDay in
                            let month = Calendar.current.component(.month, from: editBirthday)
                            let year = 2000 // 年は固定
                            let newDate = Calendar.current.date(from: DateComponents(year: year, month: month, day: newDay)) ?? editBirthday
                            editBirthday = newDate
                        })) {
                            ForEach(1...31, id: \.self) { day in
                                Text("\(day)日").tag(day)
                            }
                        }
                    }
                    Button("保存") {
                        var updatedCharacter = character
                        updatedCharacter.birthday = editBirthday
                        character = updatedCharacter
                        characterManager.updateCharacter(updatedCharacter)
                        if let idx = characters.firstIndex(where: { $0.id == character.id }) {
                            characters[idx] = updatedCharacter
                        }
                        // 親のselectedCharacterも更新
                        if let parentIdx = characterManager.characters.firstIndex(where: { $0.id == character.id }) {
                            characterManager.characters[parentIdx] = updatedCharacter
                        }
                        characterManager.refreshUI()
                        showEditBirthdayModal = false
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                Button(action: { showEditBirthdayModal = false }) {
                    Text("閉じる")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(.blue)
                        .padding(.trailing, 16)
                        .padding(.top, 16)
                }
            }
            .ignoresSafeArea(.container, edges: .top)
        }
        // アイコン画像編集モーダル
        .sheet(isPresented: $showEditIconModal) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 20) {
                    Text("アイコン画像を変更")
                        .font(.headline)
                    if let iconImage = iconImage {
                        Image(uiImage: iconImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .shadow(radius: 8)
                    }
                    PhotosPicker(selection: $iconPickerItem, matching: .images) {
                        Text("画像を選択")
                            .foregroundColor(.blue)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .padding(40)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .onAppear {
                    if iconImage == nil, let imagePath = character.imagePath, let current = UIImage(contentsOfFile: imagePath) {
                        iconImage = current
                    }
                }
                .onChange(of: iconPickerItem) { _, newItem in
                    if let newItem = newItem {
                        Task {
                            if let data = try? await newItem.loadTransferable(type: Data.self),
                               let uiImage = UIImage(data: data) {
                                iconImage = uiImage
                                // 画像を保存し、パスをセット
                                let fileName = "icon_\(character.id.uuidString).png"
                                let path = saveImageToDocuments(uiImage, fileName: fileName)
                                // キャラクターを更新
                                var updatedCharacter = character
                                updatedCharacter.imagePath = path
                                character = updatedCharacter
                                // CharacterManagerを使用して保存
                                characterManager.updateCharacter(updatedCharacter)
                                // characters配列も更新
                                if let idx = characters.firstIndex(where: { $0.id == character.id }) {
                                    characters[idx] = updatedCharacter
                                }
                                // UIを強制的に更新
                                characterManager.refreshUI()
                                // デバッグ用：保存確認
                                print("アイコンが更新されました: \(character.name)")
                                print("CharacterManagerのキャラクター数: \(characterManager.characters.count)")
                            }
                        }
                    }
                }
                Button(action: { showEditIconModal = false }) {
                    Text("閉じる")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundColor(.blue)
                        .padding(.trailing, 16)
                        .padding(.top, 16)
                }
            }
            .ignoresSafeArea(.container, edges: .top)
        }
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
    @Binding var character: Character
    @Binding var characters: [Character]
    var onClose: () -> Void
    @State private var favoriteFood: String = ""
    @State private var animeName: String = ""
    @State private var keyVisual: UIImage? = nil
    @State private var showImagePicker = false
    @State private var backgroundImage: UIImage? = nil
    @State private var showBackgroundImagePicker = false
    @State private var backgroundPickerItem: PhotosPickerItem? = nil
    @State private var isEditingName: Bool = false
    @State private var customFields: [(name: String, value: String)] = []
    @State private var showAddFieldPopup = false
    @State private var newFieldName = ""
    @State private var newFieldValue = ""
    @State private var showEditFieldPopup = false
    @State private var editFieldIndex: Int? = nil
    @State private var editFieldName = ""
    @State private var editFieldValue = ""
    @State private var showEditNameModal = false
    @State private var showEditBirthdayModal = false
    @State private var showEditIconModal = false
    @State private var showBackgroundModal = false
    @State private var editName: String = ""
    @State private var editBirthday: Date = Date()
    @State private var iconPickerItem: PhotosPickerItem? = nil
    @State private var iconImage: UIImage? = nil
    @Environment(\.presentationMode) var presentationMode
    @EnvironmentObject private var characterManager: CharacterManager
    
    init(character: Binding<Character>, characters: Binding<[Character]>, onClose: @escaping () -> Void) {
        self._character = character
        self._characters = characters
        self.onClose = onClose
        _favoriteFood = State(initialValue: character.wrappedValue.favoriteFood)
        _animeName = State(initialValue: character.wrappedValue.tag)
    }
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // 上部：キャラ詳細ページ風
                    VStack(spacing: 0) {
                        Spacer().frame(height: 48)
                        ZStack {
                            if let imagePath = character.imagePath, let image = loadImageFromPath(imagePath) {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 120, height: 120)
                                    .clipShape(Circle())
                                    .shadow(radius: 8)
                            } else {
                                Circle()
                                    .fill(Color.gray.opacity(0.3))
                                    .frame(width: 120, height: 120)
                                    .shadow(radius: 8)
                                    .overlay(
                                        Image(systemName: "person")
                                            .font(.system(size: 50))
                                            .foregroundColor(.gray)
                                    )
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { showEditIconModal = true }
                        HStack {
                            Spacer()
                            Text(character.name)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundColor(.black)
                                .padding(.top, 20)
                                .frame(maxWidth: .infinity)
                                .multilineTextAlignment(.center)
                                .onTapGesture { showEditNameModal = true }
                            Spacer()
                        }
                        Text(DateFormatter.monthDayEnglish.string(from: character.birthday))
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                            .padding(.top, 4)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                            .onTapGesture { editBirthday = character.birthday; showEditBirthdayModal = true }
                        // 誕生日（月日だけ）
                        VStack(spacing: 20) {
                            HStack {
                                Spacer()
                                Button(action: { showAddFieldPopup = true }) {
                                    Image(systemName: "plus.circle")
                                        .font(.system(size: 20, weight: .bold))
                                }
                            }
                            HStack {
                                Text("出演作品")
                                    .font(.system(size: 16, weight: .medium))
                                    .onTapGesture {
                                        editFieldIndex = 0
                                        editFieldName = "出演作品"
                                        editFieldValue = animeName
                                        showEditFieldPopup = true
                                    }
                                Spacer()
                                Text(animeName.isEmpty ? "未設定" : animeName.chunked(14).joined(separator: "\n"))
                                    .font(.system(size: 16))
                                    .foregroundColor(animeName.isEmpty ? .gray : .primary)
                                    .multilineTextAlignment(.trailing)
                                    .frame(maxWidth: 140, alignment: .trailing)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .onTapGesture {
                                        editFieldIndex = 0
                                        editFieldName = "出演作品"
                                        editFieldValue = animeName
                                        showEditFieldPopup = true
                                    }
                            }
                            HStack {
                                Text("年齢")
                                    .font(.system(size: 16, weight: .medium))
                                    .onTapGesture {
                                        editFieldIndex = 1
                                        editFieldName = "年齢"
                                        editFieldValue = newFieldName
                                        showEditFieldPopup = true
                                    }
                                Spacer()
                                Text(newFieldName.isEmpty ? "未設定" : newFieldName)
                                    .font(.system(size: 16))
                                    .foregroundColor(newFieldName.isEmpty ? .gray : .primary)
                                    .multilineTextAlignment(.trailing)
                                    .frame(maxWidth: 200, alignment: .trailing)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .onTapGesture {
                                        editFieldIndex = 1
                                        editFieldName = "年齢"
                                        editFieldValue = newFieldName
                                        showEditFieldPopup = true
                                    }
                            }
                            HStack {
                                Text("聖地")
                                    .font(.system(size: 16, weight: .medium))
                                    .onTapGesture {
                                        editFieldIndex = 2
                                        editFieldName = "聖地"
                                        editFieldValue = newFieldValue
                                        showEditFieldPopup = true
                                    }
                                Spacer()
                                Text(newFieldValue.isEmpty ? "未設定" : newFieldValue)
                                    .font(.system(size: 16))
                                    .foregroundColor(newFieldValue.isEmpty ? .gray : .primary)
                                    .multilineTextAlignment(.trailing)
                                    .frame(maxWidth: 200, alignment: .trailing)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                                    .onTapGesture {
                                        editFieldIndex = 2
                                        editFieldName = "聖地"
                                        editFieldValue = newFieldValue
                                        showEditFieldPopup = true
                                    }
                            }
                            ForEach(Array(customFields.enumerated()), id: \.offset) { idx, field in
                                HStack {
                                    Text(field.name)
                                        .font(.system(size: 16, weight: .medium))
                                        .onTapGesture {
                                            editFieldIndex = idx + 3
                                            editFieldName = field.name
                                            editFieldValue = field.value
                                            showEditFieldPopup = true
                                        }
                                    Spacer()
                                    Text(field.value.isEmpty ? "入力" : field.value)
                                        .foregroundColor(field.value.isEmpty ? .gray : .primary)
                                        .multilineTextAlignment(.trailing)
                                        .frame(maxWidth: 200, alignment: .trailing)
                                        .lineLimit(nil)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                }
            }
            .navigationBarItems(leading: Button("閉じる") { onClose() }, trailing: Button("保存") {
                // 保存処理
                saveCharacter()
                onClose()
            })
            .sheet(isPresented: $showAddFieldPopup) {
                VStack(spacing: 20) {
                    Text("新しい項目を追加")
                        .font(.headline)
                    TextField("列名", text: $newFieldName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    TextField("詳細", text: $newFieldValue)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    HStack {
                        Button("キャンセル") {
                            showAddFieldPopup = false
                            newFieldName = ""
                            newFieldValue = ""
                        }
                        Spacer()
                        Button("追加") {
                            if !newFieldName.isEmpty {
                                customFields.append((name: newFieldName, value: newFieldValue))
                                showAddFieldPopup = false
                                newFieldName = ""
                                newFieldValue = ""
                                // UIを強制的に更新
                                DispatchQueue.main.async {
                                    characterManager.objectWillChange.send()
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .padding(40)
            }
            .sheet(isPresented: $showEditFieldPopup) {
                VStack(spacing: 20) {
                    Text("項目を編集")
                        .font(.headline)
                    TextField("列名", text: $editFieldName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    TextField("詳細", text: $editFieldValue)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    HStack {
                        Button("キャンセル") {
                            showEditFieldPopup = false
                        }
                        Spacer()
                        if let idx = editFieldIndex, idx >= 3 {
                            Button("削除") {
                                customFields.remove(at: idx - 3)
                                showEditFieldPopup = false
                                // UIを強制的に更新
                                DispatchQueue.main.async {
                                    characterManager.objectWillChange.send()
                                }
                            }
                        }
                        Button("保存") {
                            if let idx = editFieldIndex {
                                if idx == 0 {
                                    animeName = editFieldValue
                                } else if idx == 1 {
                                    newFieldName = editFieldValue
                                } else if idx == 2 {
                                    newFieldValue = editFieldValue
                                } else if idx >= 3 {
                                    customFields[idx - 3].name = editFieldName
                                    customFields[idx - 3].value = editFieldValue
                                }
                            }
                            showEditFieldPopup = false
                            // UIを強制的に更新
                            DispatchQueue.main.async {
                                characterManager.objectWillChange.send()
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .padding(40)
            }
            // --- 名前編集モーダル ---
            .sheet(isPresented: $showEditNameModal) {
                ZStack(alignment: .topTrailing) {
                    VStack(spacing: 20) {
                        Spacer()
                        Text("名前を編集")
                            .font(.headline)
                        HStack {
                            Spacer()
                            TextField("名前", text: $editName)
                                .frame(width: 250)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            Spacer()
                        }
                        Button("保存") { 
                            var updatedCharacter = character
                            updatedCharacter.name = editName
                            character = updatedCharacter
                            characterManager.updateCharacter(updatedCharacter)
                            if let idx = characters.firstIndex(where: { $0.id == character.id }) {
                                characters[idx] = updatedCharacter
                            }
                            // 親のselectedCharacterも更新
                            if let parentIdx = characterManager.characters.firstIndex(where: { $0.id == character.id }) {
                                characterManager.characters[parentIdx] = updatedCharacter
                            }
                            characterManager.refreshUI()
                            showEditNameModal = false 
                        }
                        Spacer()
                    }
                    Button(action: { showEditNameModal = false }) {
                        Text("閉じる")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(.blue)
                            .padding(.top, 16)
                            .padding(.trailing, 16)
                    }
                }
                .ignoresSafeArea(.container, edges: .top)
                .onAppear {
                    editName = character.name
                }
            }
            // --- 誕生日編集モーダル ---
            .sheet(isPresented: $showEditBirthdayModal) {
                ZStack(alignment: .topTrailing) {
                    VStack(spacing: 20) {
                        Text("誕生日を編集")
                            .font(.headline)
                        HStack(spacing: 16) {
                            Picker("月", selection: Binding(get: {
                                Calendar.current.component(.month, from: editBirthday)
                            }, set: { newMonth in
                                let day = Calendar.current.component(.day, from: editBirthday)
                                let year = 2000 // 年は固定
                                let newDate = Calendar.current.date(from: DateComponents(year: year, month: newMonth, day: day)) ?? editBirthday
                                editBirthday = newDate
                            })) {
                                ForEach(1...12, id: \.self) { month in
                                    Text("\(month)月").tag(month)
                                }
                            }
                            Picker("日", selection: Binding(get: {
                                Calendar.current.component(.day, from: editBirthday)
                            }, set: { newDay in
                                let month = Calendar.current.component(.month, from: editBirthday)
                                let year = 2000 // 年は固定
                                let newDate = Calendar.current.date(from: DateComponents(year: year, month: month, day: newDay)) ?? editBirthday
                                editBirthday = newDate
                            })) {
                                ForEach(1...31, id: \.self) { day in
                                    Text("\(day)日").tag(day)
                                }
                            }
                        }
                        Button("保存") {
                            var updatedCharacter = character
                            updatedCharacter.birthday = editBirthday
                            character = updatedCharacter
                            characterManager.updateCharacter(updatedCharacter)
                            if let idx = characters.firstIndex(where: { $0.id == character.id }) {
                                characters[idx] = updatedCharacter
                            }
                            // 親のselectedCharacterも更新
                            if let parentIdx = characterManager.characters.firstIndex(where: { $0.id == character.id }) {
                                characterManager.characters[parentIdx] = updatedCharacter
                            }
                            characterManager.refreshUI()
                            showEditBirthdayModal = false
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    Button(action: { showEditBirthdayModal = false }) {
                        Text("閉じる")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(.blue)
                            .padding(.trailing, 16)
                            .padding(.top, 16)
                    }
                }
                .ignoresSafeArea(.container, edges: .top)
            }
            // --- アイコン画像編集モーダル ---
            .sheet(isPresented: $showEditIconModal) {
                ZStack(alignment: .topTrailing) {
                    VStack(spacing: 20) {
                        Text("アイコン画像を変更")
                            .font(.headline)
                        if let iconImage = iconImage {
                            Image(uiImage: iconImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                                .shadow(radius: 8)
                        }
                        PhotosPicker(selection: $iconPickerItem, matching: .images) {
                            Text("画像を選択")
                                .foregroundColor(.blue)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .padding(40)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .onAppear {
                        if iconImage == nil, let imagePath = character.imagePath, let current = UIImage(contentsOfFile: imagePath) {
                            iconImage = current
                        }
                    }
                    .onChange(of: iconPickerItem) { _, newItem in
                        if let newItem = newItem {
                            Task {
                                if let data = try? await newItem.loadTransferable(type: Data.self),
                                   let uiImage = UIImage(data: data) {
                                    iconImage = uiImage
                                    // 画像を保存し、パスをセット
                                    let fileName = "icon_\(character.id.uuidString).png"
                                    let path = saveImageToDocuments(uiImage, fileName: fileName)
                                    // キャラクターを更新
                                    var updatedCharacter = character
                                    updatedCharacter.imagePath = path
                                    character = updatedCharacter
                                    // CharacterManagerを使用して保存
                                    characterManager.updateCharacter(updatedCharacter)
                                    // characters配列も更新
                                    if let idx = characters.firstIndex(where: { $0.id == character.id }) {
                                        characters[idx] = updatedCharacter
                                    }
                                    // UIを強制的に更新
                                    characterManager.refreshUI()
                                    // デバッグ用：保存確認
                                    print("アイコンが更新されました: \(character.name)")
                                    print("CharacterManagerのキャラクター数: \(characterManager.characters.count)")
                                }
                            }
                        }
                    }
                    Button(action: { showEditIconModal = false }) {
                        Text("閉じる")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(.blue)
                            .padding(.trailing, 16)
                            .padding(.top, 16)
                    }
                }
                .ignoresSafeArea(.container, edges: .top)
            }
            // --- 背景画像選択モーダル ---
            .sheet(isPresented: $showBackgroundModal) {
                ZStack(alignment: .topTrailing) {
                    VStack(spacing: 24) {
                        Text("背景画像を選択")
                            .font(.headline)
                        if let bgImage = backgroundImage {
                            Image(uiImage: bgImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(height: 180)
                                .clipped()
                        } else {
                            Rectangle()
                                .fill(Color.gray.opacity(0.18))
                                .frame(height: 180)
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.system(size: 48))
                                        .foregroundColor(.gray.opacity(0.5))
                                )
                        }
                        PhotosPicker(selection: $backgroundPickerItem, matching: .images) {
                            Text("写真を選択")
                                .foregroundColor(.blue)
                        }
                        Button("保存") {
                            // 画像保存処理（必要ならここでbackgroundImageを更新）
                            showBackgroundModal = false
                        }
                    }
                    .padding(.top, 32)
                    .padding(.horizontal, 24)
                    Button(action: { showBackgroundModal = false }) {
                        Text("閉じる")
                            .font(.system(size: 18, weight: .regular))
                            .foregroundColor(.blue)
                            .padding(.trailing, 16)
                            .padding(.top, 16)
                    }
                }
                .ignoresSafeArea(.container, edges: .top)
            }
        }
    }
    // 保存処理
    func saveCharacter() {
        // キャラ情報を更新
        var updatedCharacter = character
        updatedCharacter.name = character.name
        updatedCharacter.favoriteFood = favoriteFood
        updatedCharacter.tag = animeName
        updatedCharacter.imagePath = character.imagePath // 画像パスも含めて更新
        
        // CharacterManagerを使用して保存
        characterManager.updateCharacter(updatedCharacter)
        
        // characters配列も更新
        if let idx = characters.firstIndex(where: { $0.id == updatedCharacter.id }) {
            characters[idx] = updatedCharacter
        }
        
        // UIを強制的に更新
        DispatchQueue.main.async {
            characterManager.objectWillChange.send()
        }
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

func saveImageToDocuments(_ image: UIImage, fileName: String) -> String? {
    guard let data = image.pngData() else { return nil }
    let fileManager = FileManager.default
    let urls = fileManager.urls(for: .documentDirectory, in: .userDomainMask)
    guard let documentsURL = urls.first else { return nil }
    let fileURL = documentsURL.appendingPathComponent(fileName)
    do {
        try data.write(to: fileURL)
        return fileURL.path
    } catch {
        print("画像保存エラー: \(error)")
        return nil
    }
}

struct NavigationBarItem: View {
    let icon: String
    let title: String
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(isSelected ? .blue : .gray)
            Text(title)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(isSelected ? .blue : .gray)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 75)
    }
}

#Preview {
    CharaScreen()
} 