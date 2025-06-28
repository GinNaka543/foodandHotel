import SwiftUI
import PhotosUI

struct Character: Identifiable, Hashable, Equatable {
    let id: UUID
    var image: UIImage?
    var name: String
    var tag: String
    var birthday: Date

    static func == (lhs: Character, rhs: Character) -> Bool {
        lhs.id == rhs.id
    }
}

struct CharaScreen: View {
    @State private var characters: [Character] = []
    @State private var showAddSheet = false
    @State private var searchText = ""
    @State private var selectedCharacter: Character? = nil
    @State private var showDetail = false

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
            HeaderView(showAddSheet: $showAddSheet)
            SearchBar(text: $searchText)
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
            CharacterDetailView(character: character) {
                selectedCharacter = nil
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddCharacterSheet(characters: $characters)
        }
    }
}

struct HeaderView: View {
    @Binding var showAddSheet: Bool
    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center) {
                Text("Chara")
                    .font(.system(size: 32, weight: .bold))
                Spacer()
                HStack(spacing: 20) {
                    Image(systemName: "line.3.horizontal")
                        .font(.system(size: 22, weight: .medium))
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 22, weight: .medium))
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: "bubble.left")
                            .font(.system(size: 22, weight: .medium))
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                            .offset(x: 7, y: -7)
                    }
                    Button(action: { showAddSheet = true }) {
                        Image(systemName: "ellipsis.bubble")
                            .font(.system(size: 22, weight: .medium))
                            .overlay(
                                Image(systemName: "plus")
                                    .font(.system(size: 10, weight: .bold))
                                    .offset(x: 10, y: 10)
                            )
                    }
                }
                .foregroundColor(.black)
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
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
                .font(.system(size: 14))
            TextField("Search", text: $text)
                .autocapitalization(.none)
                .disableAutocorrection(true)
                .font(.system(size: 14))
            Spacer()
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 10)
        .background(Color(.systemGray6))
        .cornerRadius(10)
        .frame(height: 40)
        .frame(width: UIScreen.main.bounds.width - 50)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray, lineWidth: 5)
        )
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
            Text(birthdayString)
                .font(.system(size: 9))
                .foregroundColor(.gray)
                .padding(.vertical, 5)
                .offset(y: -5)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(Color.clear)
        .contentShape(Rectangle())
    }
    
    private var birthdayString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: character.birthday)
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
                DatePicker("誕生日", selection: $birthday, displayedComponents: .date)
            }
            .navigationTitle("キャラ追加")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        let newChar = Character(id: UUID(), image: image, name: name, tag: tag, birthday: birthday)
                        characters.append(newChar)
                        dismiss()
                    }.disabled(name.isEmpty || tag.isEmpty)
                }
            }
        }
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
    var onDismiss: (() -> Void)? = nil
    @Environment(\.presentationMode) var presentationMode
    @State private var showArtwork = false

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
                    Text(DateFormatter.monthDayEnglish.string(from: character.birthday).uppercased())
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
                        VStack {
                            Image(systemName: "video")
                            Text("Video").font(.caption2)
                        }
                        Spacer()
                        VStack {
                            Image(systemName: "info.circle")
                            Text("About").font(.caption2)
                        }
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

#Preview {
    CharaScreen()
} 