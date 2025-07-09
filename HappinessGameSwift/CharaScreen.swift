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
        case id, imageIdentifier, name, tag, birthday, favoriteFood, age, voiceActor, cupSize, seichi, height, customFields
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
        customFields = try? container.decodeIfPresent([CustomField].self, forKey: .customFields)
    }
    init(id: UUID, imageIdentifier: String?, name: String, tag: String, birthday: Date, favoriteFood: String = "", age: String, voiceActor: String, cupSize: String, seichi: String, height: String, customFields: [CustomField]? = nil) {
        self.id = id
        self.imageIdentifier = imageIdentifier
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
                                    if let imagePath = saveImageToDocuments(uiImage, fileName: fileName) {
                                        // CharacterのimageIdentifierにパスを保存
                                        // 追加時に利用するため、必要ならここで変数にセット
                                    }
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
    // 編集用の状態変数
    @State private var showEditNameModal = false
    @State private var showEditBirthdayModal = false
    @State private var showEditIconModal = false
    @State private var editName: String = ""
    @State private var editTag: String = ""
    @State private var editBirthday: Date = Date()
    @State private var iconPickerItem: PhotosPickerItem? = nil
    @State private var iconImage: UIImage? = nil
    @State private var tempIconImage: UIImage? = nil // モーダル内の一時的な画像表示用

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
                    Spacer().frame(height: 180 + 50)
                    ZStack {
                        if let imageIdentifier = currentCharacter.imageIdentifier, let image = UIImage(contentsOfFile: imageIdentifier) {
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
                    // 名前
                    HStack {
                        Spacer()
                        Text(nameText)
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.top, 20)
                            .frame(maxWidth: .infinity)
                            .multilineTextAlignment(.center)
                        Spacer()
                    }
                    // 誕生日
                    Text(birthdayText.uppercased())
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                        .padding(.top, 4)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
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
                            Text("Event").font(.caption2)
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
                        AboutView(characters: $characters, characterId: character.id, onClose: { showAbout = false })
                            .environmentObject(characterManager)
                    }
                }
                .frame(width: geometry.size.width)
            }
        }
        .navigationBarHidden(true)
        // 名前編集モーダル
        .sheet(isPresented: $showEditNameModal) {
            VStack(spacing: 20) {
                Text("名前とタグを編集")
                    .font(.headline)
                VStack(spacing: 12) {
                    TextField("名前", text: $editName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                    TextField("タグ", text: $editTag)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                HStack {
                    Button("キャンセル") {
                        showEditNameModal = false
                    }
                    Spacer()
                    Button("保存") {
                        guard let idx = characters.firstIndex(where: { $0.id == character.id }) else { return }
                        var updatedCharacter = characters[idx]
                        updatedCharacter.name = editName
                        updatedCharacter.tag = editTag
                        characters[idx] = updatedCharacter
                        characterManager.updateCharacter(updatedCharacter)
                        showEditNameModal = false
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .padding(40)
        }
        // 誕生日編集モーダル
        .sheet(isPresented: $showEditBirthdayModal) {
            VStack(spacing: 20) {
                Text("誕生日を編集")
                    .font(.headline)
                HStack(spacing: 16) {
                    Picker("月", selection: Binding(
                        get: { Calendar.current.component(.month, from: editBirthday) },
                        set: { newMonth in
                            let day = Calendar.current.component(.day, from: editBirthday)
                            let year = Calendar.current.component(.year, from: editBirthday)
                            let newDate = Calendar.current.date(from: DateComponents(year: year, month: newMonth, day: day)) ?? editBirthday
                            editBirthday = newDate
                        })) {
                        ForEach(1...12, id: \.self) { month in
                            Text("\(month)月").tag(month)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                    Picker("日", selection: Binding(
                        get: { Calendar.current.component(.day, from: editBirthday) },
                        set: { newDay in
                            let month = Calendar.current.component(.month, from: editBirthday)
                            let year = Calendar.current.component(.year, from: editBirthday)
                            let newDate = Calendar.current.date(from: DateComponents(year: year, month: month, day: newDay)) ?? editBirthday
                            editBirthday = newDate
                        })) {
                        ForEach(1...31, id: \.self) { day in
                            Text("\(day)日").tag(day)
                        }
                    }
                    .pickerStyle(WheelPickerStyle())
                }
                HStack {
                    Button("キャンセル") {
                        showEditBirthdayModal = false
                    }
                    Spacer()
                    Button("保存") {
                        guard let idx = characters.firstIndex(where: { $0.id == character.id }) else { return }
                        var updatedCharacter = characters[idx]
                        updatedCharacter.birthday = editBirthday
                        characters[idx] = updatedCharacter
                        characterManager.updateCharacter(updatedCharacter)
                        showEditBirthdayModal = false
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .padding(40)
        }
        // アイコン画像編集モーダル
        .sheet(isPresented: $showEditIconModal) {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 24) {
                    Text("アイコンを編集")
                        .font(.headline)
                    if let tempIconImage = tempIconImage {
                        Image(uiImage: tempIconImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 120, height: 120)
                            .clipShape(Circle())
                            .shadow(radius: 8)
                    } else if let imageIdentifier = character.imageIdentifier, let image = UIImage(contentsOfFile: imageIdentifier) {
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
                .onChange(of: iconPickerItem) { newValue in
                    if let newItem = newValue {
                        Task {
                            if let data = try? await newItem.loadTransferable(type: Data.self), let uiImage = UIImage(data: data) {
                                // 即座にモーダル内の画像を更新
                                tempIconImage = uiImage
                                
                                // 画像をドキュメントディレクトリに保存
                                let fileName = "icon_\(UUID().uuidString).png"
                                if let imagePath = saveImageToDocuments(uiImage, fileName: fileName) {
                                    guard let idx = characters.firstIndex(where: { $0.id == character.id }) else { return }
                                    var updatedCharacter = characters[idx]
                                    updatedCharacter.imageIdentifier = imagePath
                                    characters[idx] = updatedCharacter
                                    characterManager.updateCharacter(updatedCharacter)
                                    characterManager.refreshUI()
                                }
                            }
                        }
                    }
                }
                Button(action: { 
                    showEditIconModal = false
                    tempIconImage = nil // モーダルを閉じる時にクリア
                }) {
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
    @Binding var characters: [Character]
    let characterId: UUID
    var onClose: () -> Void
    @State private var favoriteFood: String = ""
    @State private var animeName: String = ""
    @State private var keyVisual: UIImage? = nil
    @State private var showImagePicker = false
    @State private var backgroundImage: UIImage? = nil
    @State private var showBackgroundImagePicker = false
    @State private var backgroundPickerItem: PhotosPickerItem? = nil
    @State private var isEditingName: Bool = false
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
    @State private var editTag: String = ""
    @State private var editBirthday: Date = Date()
    @State private var iconPickerItem: PhotosPickerItem? = nil
    @State private var iconImage: UIImage? = nil
    @State private var tempIconImage: UIImage? = nil // モーダル内の一時的な画像表示用
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
                    characterHeaderView
                    characterFieldsView
                }
            }
            .navigationBarItems(leading: Button("閉じる") { saveCharacter(); onClose() })
            .sheet(isPresented: $showAddFieldPopup) {
                addFieldPopupView
            }
            .sheet(isPresented: $showEditFieldPopup) {
                editFieldPopupView
            }
            .sheet(isPresented: $showEditNameModal) {
                editNameModalView
            }
            .sheet(isPresented: $showEditBirthdayModal) {
                editBirthdayModalView
            }
            .sheet(isPresented: $showEditIconModal) {
                editIconModalView
            }
            .sheet(isPresented: $showBackgroundModal) {
                backgroundModalView
            }
        }
        .onAppear {
            print("[DEBUG] AboutView onAppear: character.customFields=\(String(describing: character?.customFields))")
            editName = character?.name ?? ""
            editTag = character?.tag ?? ""
        }
        .onDisappear {
            saveCharacter()
        }
    }
    
    // MARK: - Subviews
    private var characterHeaderView: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 48)
            ZStack {
                if let imageIdentifier = character?.imageIdentifier, let image = UIImage(contentsOfFile: imageIdentifier) {
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
                Text(character?.name ?? "")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.black)
                    .padding(.top, 20)
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                    .onTapGesture { showEditNameModal = true }
                Spacer()
            }
            Text(DateFormatter.monthDayEnglish.string(from: character?.birthday ?? Date()))
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .padding(.top, 4)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .onTapGesture { editBirthday = character?.birthday ?? Date(); showEditBirthdayModal = true }
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }
    
    private var characterFieldsView: some View {
        VStack(spacing: 20) {
            HStack {
                Spacer()
                Button(action: { showAddFieldPopup = true }) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 20, weight: .bold))
                }
            }
            ForEach(Array((character?.customFields ?? []).enumerated()), id: \.element.name) { index, field in
                HStack {
                    Text(field.name)
                        .font(.system(size: 16, weight: .medium))
                    Spacer()
                    Text(field.value.isEmpty ? "入力" : field.value)
                        .foregroundColor(field.value.isEmpty ? .gray : .primary)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 200, alignment: .trailing)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .onTapGesture {
                    editFieldIndex = index + 3 // カスタムフィールドは3から始まる
                    editFieldName = field.name
                    editFieldValue = field.value
                    showEditFieldPopup = true
                }
            }
        }
        .padding(.horizontal, 24)
    }
    
    private var addFieldPopupView: some View {
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
                    print("[DEBUG] 追加ボタンタップ")
                    guard let idx = characters.firstIndex(where: { $0.id == characterId }) else { return }
                    var updatedCharacter = characters[idx]
                    if updatedCharacter.customFields == nil { updatedCharacter.customFields = [] }
                    updatedCharacter.customFields?.append(CustomField(name: newFieldName, value: newFieldValue))
                    characters[idx] = updatedCharacter
                    print("[DEBUG] addFieldPopupView: 追加後characters[idx].customFields=\(String(describing: characters[idx].customFields))")
                    saveCharacter()
                    showAddFieldPopup = false
                    newFieldName = ""
                    newFieldValue = ""
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
    
    private var editFieldPopupView: some View {
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
                Button("保存") {
                    guard let idx = characters.firstIndex(where: { $0.id == characterId }) else { return }
                    var updatedCharacter = characters[idx]
                    if let index = editFieldIndex {
                        if index >= 3 {
                            let fieldIndex = index - 3
                            if let fields = updatedCharacter.customFields, fieldIndex < fields.count {
                                var newFields = fields
                                newFields[fieldIndex] = CustomField(name: editFieldName, value: editFieldValue)
                                updatedCharacter.customFields = newFields
                                print("[DEBUG] editFieldPopupView: 編集後customFields=\(newFields)")
                            }
                        }
                    }
                    characters[idx] = updatedCharacter
                    saveCharacter()
                    showEditFieldPopup = false
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
    
    private var editNameModalView: some View {
        VStack(spacing: 20) {
            Text("名前を編集")
                .font(.headline)
            VStack(spacing: 12) {
                TextField("名前", text: $editName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                TextField("タグ", text: $editTag)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            HStack {
                Button("キャンセル") {
                    showEditNameModal = false
                }
                Spacer()
                Button("保存") {
                    guard let idx = characters.firstIndex(where: { $0.id == characterId }) else { return }
                    var updatedCharacter = characters[idx]
                    updatedCharacter.name = editName
                    updatedCharacter.tag = editTag
                    characters[idx] = updatedCharacter
                    characterManager.updateCharacter(updatedCharacter)
                    showEditNameModal = false
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .padding(40)
    }
    
    private var editBirthdayModalView: some View {
        VStack(spacing: 20) {
            Text("誕生日を編集")
                .font(.headline)
            HStack(spacing: 16) {
                Picker("月", selection: Binding(
                    get: { Calendar.current.component(.month, from: editBirthday) },
                    set: { newMonth in
                        let day = Calendar.current.component(.day, from: editBirthday)
                        let year = Calendar.current.component(.year, from: editBirthday)
                        let newDate = Calendar.current.date(from: DateComponents(year: year, month: newMonth, day: day)) ?? editBirthday
                        editBirthday = newDate
                    })) {
                    ForEach(1...12, id: \.self) { month in
                        Text("\(month)月").tag(month)
                    }
                }
                .pickerStyle(WheelPickerStyle())
                Picker("日", selection: Binding(
                    get: { Calendar.current.component(.day, from: editBirthday) },
                    set: { newDay in
                        let month = Calendar.current.component(.month, from: editBirthday)
                        let year = Calendar.current.component(.year, from: editBirthday)
                        let newDate = Calendar.current.date(from: DateComponents(year: year, month: month, day: newDay)) ?? editBirthday
                        editBirthday = newDate
                    })) {
                    ForEach(1...31, id: \.self) { day in
                        Text("\(day)日").tag(day)
                    }
                }
                .pickerStyle(WheelPickerStyle())
            }
            HStack {
                Button("キャンセル") {
                    showEditBirthdayModal = false
                }
                Spacer()
                Button("保存") {
                    guard let idx = characters.firstIndex(where: { $0.id == characterId }) else { return }
                    var updatedCharacter = characters[idx]
                    updatedCharacter.birthday = editBirthday
                    characters[idx] = updatedCharacter
                    characterManager.updateCharacter(updatedCharacter)
                    showEditBirthdayModal = false
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .padding(40)
    }
    
    private var editIconModalView: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 24) {
                Text("アイコンを編集")
                    .font(.headline)
                if let tempIconImage = tempIconImage {
                    Image(uiImage: tempIconImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .shadow(radius: 8)
                } else if let imageIdentifier = character?.imageIdentifier, let image = UIImage(contentsOfFile: imageIdentifier) {
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
            .onChange(of: iconPickerItem) { newValue in
                if let newItem = newValue {
                    Task {
                        if let data = try? await newItem.loadTransferable(type: Data.self), let uiImage = UIImage(data: data) {
                            // 即座にモーダル内の画像を更新
                            tempIconImage = uiImage
                            
                            // 画像をドキュメントディレクトリに保存
                            let fileName = "icon_\(UUID().uuidString).png"
                            if let imagePath = saveImageToDocuments(uiImage, fileName: fileName) {
                                guard let idx = characters.firstIndex(where: { $0.id == characterId }) else { return }
                                var updatedCharacter = characters[idx]
                                updatedCharacter.imageIdentifier = imagePath
                                characters[idx] = updatedCharacter
                                characterManager.updateCharacter(updatedCharacter)
                                characterManager.refreshUI()
                            }
                        }
                    }
                }
            }
            Button(action: { 
                showEditIconModal = false
                tempIconImage = nil // モーダルを閉じる時にクリア
            }) {
                Text("閉じる")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundColor(.blue)
                    .padding(.trailing, 16)
                    .padding(.top, 16)
            }
        }
        .ignoresSafeArea(.container, edges: .top)
    }
    
    private var backgroundModalView: some View {
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
    
    // MARK: - Helper Methods
    private func saveCharacter() {
        guard let idx = characters.firstIndex(where: { $0.id == characterId }) else { return }
        print("[DEBUG] saveCharacter: characters[idx].customFields=\(String(describing: characters[idx].customFields))")
        characterManager.updateCharacter(characters[idx])
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

#Preview {
    CharaScreen()
} 
