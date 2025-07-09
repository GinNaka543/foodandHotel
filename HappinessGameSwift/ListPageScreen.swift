import SwiftUI

public struct ListPageScreen: View {
    @Environment(\.presentationMode) var presentationMode
    @State var selectedTab: ListTab
    @State private var searchText = ""
    @State private var selectedCharacter: Character? = nil
    @State private var selectedAnime: Anime? = nil

    let characters: [Character]
    let animes: [Anime]
    let birthdays: [Character]

    var headerTitle: String {
        switch selectedTab {
        case .chara: return "キャラクターリスト"
        case .anime: return "アニメリスト"
        case .birthday: return "バースデーリスト"
        }
    }

    var headerTitlePadding: CGFloat {
        switch selectedTab {
        case .chara:
            return 81 // 88 - 7
        case .anime:
            return 103 // 88 + 15
        case .birthday:
            return 88
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // ヘッダー
            HStack {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.black)
                }
                Text(headerTitle)
                    .font(.system(size: 20, weight: .bold))
                    .padding(.leading, headerTitlePadding)
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.top, 19)
            .padding(.bottom, 8)
            .offset(y: -10)
            // サーチバー
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search", text: $searchText)
                    .font(.system(size: 16))
                    .padding(.vertical, 5.5)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: UIScreen.main.bounds.width - 35)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .padding(.bottom, 8)
            .offset(y: -5)
            // タブ
            HStack(spacing: 0) {
                tabButton(title: "Characters", tab: .chara)
                tabButton(title: "Animes", tab: .anime)
                tabButton(title: "Birthdays", tab: .birthday)
            }
            .background(Color.white)
            .offset(y: -5)
            // リスト切り替え
            if selectedTab == .chara {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(filteredCharacters, id: \ .id) { character in
                            Button(action: { selectedCharacter = character }) {
                                HStack(spacing: 16) {
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
                                    Text(character.name)
                                        .font(.system(size: 18, weight: .regular))
                                    Spacer()
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 16)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            } else if selectedTab == .anime {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(filteredAnimes, id: \ .id) { anime in
                            Button(action: { selectedAnime = anime }) {
                                HStack(spacing: 16) {
                                    if let imageIdentifier = anime.imageIdentifier, let image = UIImage(contentsOfFile: imageIdentifier) {
                                        Image(uiImage: image)
                                            .resizable()
                                            .aspectRatio(contentMode: .fill)
                                            .frame(width: 48, height: 48)
                                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    } else {
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 48, height: 48)
                                            .overlay(
                                                Image(systemName: "film")
                                                    .font(.system(size: 24))
                                                    .foregroundColor(.gray)
                                            )
                                    }
                                    Text(anime.title)
                                        .font(.system(size: 18, weight: .regular))
                                    Spacer()
                                }
                                .padding(.vertical, 6)
                                .padding(.horizontal, 16)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(filteredBirthdays, id: \ .id) { character in
                            HStack(spacing: 16) {
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
                                        .font(.system(size: 18, weight: .regular))
                                    Text("誕生日: \(DateFormatter.monthDayJapanese.string(from: character.birthday))")
                                        .font(.system(size: 14))
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 16)
                        }
                    }
                }
            }
        }
        .fullScreenCover(item: $selectedCharacter) { character in
            CharacterDetailView(character: Binding(
                get: { character },
                set: { _ in }
            ), characters: .constant(characters))
            .environmentObject(CharacterManager())
        }
        .fullScreenCover(item: $selectedAnime) { anime in
            AnimeDetailView(anime: Binding(
                get: { anime },
                set: { _ in }
            ), animes: .constant(animes))
            .environmentObject(AnimeManager())
        }
    }

    // タブボタンのカスタムView
    @ViewBuilder
    private func tabButton(title: String, tab: ListTab) -> some View {
        Button(action: { selectedTab = tab }) {
            VStack(spacing: 2) {
                Text(title)
                    .fontWeight(selectedTab == tab ? .bold : .regular)
                    .foregroundColor(selectedTab == tab ? .black : Color(.systemGray3))
                Rectangle()
                    .frame(width: (UIScreen.main.bounds.width / 3) - 25, height: 2)
                    .foregroundColor(selectedTab == tab ? .black : .clear)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }

    // 検索フィルタ用プロパティ
    private var filteredCharacters: [Character] {
        if searchText.isEmpty { return characters }
        return characters.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    private var filteredAnimes: [Anime] {
        if searchText.isEmpty { return animes }
        return animes.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
    private var filteredBirthdays: [Character] {
        if searchText.isEmpty { return birthdays }
        return birthdays.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
} 