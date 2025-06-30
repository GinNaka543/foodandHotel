import SwiftUI
import PhotosUI
import UIKit

struct Character: Identifiable, Hashable, Equatable, Codable {
    let id: UUID
    var image: UIImage?
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
        case id, imageData, name, tag, birthday, favoriteFood, age, voiceActor, cupSize, seichi, height
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
        if let image = image, let data = image.pngData() {
            try container.encode(data, forKey: .imageData)
        } else {
            try container.encodeNil(forKey: .imageData)
        }
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
        if let data = try? container.decodeIfPresent(Data.self, forKey: .imageData) {
            image = UIImage(data: data)
        } else {
            image = nil
        }
    }
    init(id: UUID, image: UIImage?, name: String, tag: String, birthday: Date, favoriteFood: String = "", age: String, voiceActor: String, cupSize: String, seichi: String, height: String) {
        self.id = id
        self.image = image
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
    @State private var characters: [Character] = []
    @State private var showAddSheet = false
    @State private var searchText = ""
    @State private var selectedCharacter: Character? = nil
    @State private var showDetail = false
    @State private var showSearchBar = true
    @State private var customFields: [(name: String, value: String)] = []
    @State private var showAddFieldPopup = false
    @State private var newFieldName = ""
    @State private var newFieldValue = ""
    @State private var showEditFieldPopup = false
    @State private var editFieldIndex: Int? = nil // デフォルト列: 0,1,2 カスタム列: 3以降
    @State private var editFieldName = ""
    @State private var editFieldValue = ""
    @State private var showEditNameModal = false
    @State private var showEditBirthdayModal = false
    @State private var showEditIconModal = false
    @State private var showBackgroundModal = false
    @State private var backgroundPickerItem: PhotosPickerItem? = nil
    @State private var newName: String = ""
    @State private var editBirthday: Date = Date()

    var filteredCharacters: [Character] {
        if searchText.isEmpty { return characters }
        return characters.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.tag.localizedCaseInsensitiveContains(searchText) ||
            $0.birthday.formatted(.dateTime.year().month().day()).contains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HeaderView(showAddSheet: $showAddSheet, showSearchBar: $showSearchBar)
            if showSearchBar {
                SearchBar(text: $searchText)
            }
            AdBannerView()
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredCharacters) { character in
                        Button(action: {
                            selectedCharacter = character
                            showDetail = true
                        }) {
                            CharacterRow(character: character)
                                .padding(.horizontal, 16)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .fullScreenCover(item: $selectedCharacter) { character in
            CharacterDetailView(character: character, characters: $characters, onDismiss: { selectedCharacter = nil })
        }
        .sheet(isPresented: $showAddSheet, onDismiss: saveCharacters) {
            AddCharacterSheet(characters: $characters)
        }
        .onAppear {
            loadCharacters()
        }
        .onChange(of: characters) { _ in
            saveCharacters()
        }
    }
    // UserDefaults保存・読込
    private func saveCharacters() {
        if let data = try? JSONEncoder().encode(characters) {
            UserDefaults.standard.set(data, forKey: "characters")
        }
    }
    private func loadCharacters() {
        if let data = UserDefaults.standard.data(forKey: "characters"),
           let decoded = try? JSONDecoder().decode([Character].self, from: data) {
            characters = decoded
        }
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
    var body: some View {
        HStack(alignment: .center, spacing: 14) {
            if let image = character.image {
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
        .padding(.vertical, 6)
        .background(Color.clear)
        .contentShape(Rectangle())
    }
}

struct AddCharacterSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var characters: [Character]
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
                .onChange(of: selectedItem) { newItem in
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
                        let newChar = Character(id: UUID(), image: image, name: name, tag: tag, birthday: date, favoriteFood: "", age: "", voiceActor: "", cupSize: "", seichi: "", height: "")
                        characters.append(newChar)
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
    let character: Character
    @Binding var characters: [Character]
    var onDismiss: (() -> Void)? = nil
    @Environment(\.presentationMode) var presentationMode
    @State private var showArtwork = false
    @State private var showVideo = false
    @State private var showAbout = false

    var body: some View {
        GeometryReader { geometry in
            let nameText = character.name
            let birthdayText = DateFormatter.monthDayEnglish.string(from: character.birthday)
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
                    if let image = character.image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 107, height: 107)
                            .clipShape(Circle())
                            .shadow(radius: 8)
                    } else {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 107, height: 107)
                            .shadow(radius: 8)
                            .overlay(
                                Image(systemName: "person")
                                    .font(.system(size: 50))
                                    .foregroundColor(.gray)
                            )
                    }
                    // 名前
                    Text(nameText)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.black)
                        .padding(.top, 20)
                        .frame(maxWidth: .infinity, alignment: .center)
                    // 誕生日
                    Text(birthdayText.uppercased())
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                        .padding(.top, 8)
                        .frame(maxWidth: .infinity, alignment: .center)
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
                        AboutView(character: character, characters: $characters, onClose: { showAbout = false })
                    }
                }
                .frame(width: geometry.size.width)
            }
        }
        .navigationBarHidden(true)
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
    @State var character: Character
    @Binding var characters: [Character]
    var onClose: () -> Void
    @State private var newName: String
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
    @State private var editBirthday: Date = Date()
    @Environment(\.presentationMode) var presentationMode
    // キャラ情報保存用
    @AppStorage("characters") var charactersData: Data = Data()
    init(character: Character, characters: Binding<[Character]>, onClose: @escaping () -> Void) {
        self._characters = characters
        self.character = character
        self.onClose = onClose
        _newName = State(initialValue: character.name)
        _favoriteFood = State(initialValue: character.favoriteFood)
        _animeName = State(initialValue: character.tag)
    }
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 0) {
                    // 上部：キャラ詳細ページ風
                    VStack(spacing: 0) {
                        Spacer().frame(height: 48)
                        ZStack {
                            if let image = character.image {
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
                        HStack {
                            Spacer()
                            Text(newName)
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
                // characters配列も更新
                if let idx = characters.firstIndex(where: { $0.id == character.id }) {
                    var updatedCharacter = character
                    updatedCharacter.name = newName
                    updatedCharacter.favoriteFood = favoriteFood
                    updatedCharacter.tag = animeName
                    characters[idx] = updatedCharacter
                }
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
                            TextField("名前", text: $newName)
                                .frame(width: 250)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                            Spacer()
                        }
                        Button("保存") { showEditNameModal = false }
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
                                ForEach(1...12, id: \ .self) { month in
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
                                ForEach(1...31, id: \ .self) { day in
                                    Text("\(day)日").tag(day)
                                }
                            }
                        }
                        Button("保存") {
                            character.birthday = editBirthday
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
                VStack(spacing: 20) {
                    Text("アイコン画像を変更")
                        .font(.headline)
                    PhotosPicker(selection: $backgroundPickerItem, matching: .images) {
                        Text("画像を選択")
                    }
                    Button("保存") { showEditIconModal = false }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .padding(40)
            }
            // --- 背景画像選択モーダル ---
            .sheet(isPresented: $showBackgroundModal) {
                VStack(spacing: 20) {
                    Text("背景画像を選択")
                        .font(.headline)
                    PhotosPicker(selection: $backgroundPickerItem, matching: .images) {
                        Text("写真を選択")
                    }
                    Button("保存") { showBackgroundModal = false }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(16)
                .padding(40)
            }
        }
    }
    // 保存処理
    func saveCharacter() {
        // キャラ情報を更新
        var updatedCharacter = character
        updatedCharacter.name = newName
        updatedCharacter.favoriteFood = favoriteFood
        updatedCharacter.tag = animeName
        // charactersDataから配列をデコード
        var characters: [Character] = []
        if let decoded = try? JSONDecoder().decode([Character].self, from: charactersData) {
            characters = decoded
        }
        // id一致で置き換え
        if let idx = characters.firstIndex(where: { $0.id == updatedCharacter.id }) {
            characters[idx] = updatedCharacter
        }
        // エンコードして保存
        if let encoded = try? JSONEncoder().encode(characters) {
            charactersData = encoded
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

#Preview {
    CharaScreen()
} 