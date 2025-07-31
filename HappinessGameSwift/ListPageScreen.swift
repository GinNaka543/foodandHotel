import SwiftUI

public struct ListPageScreen: View {
    @Environment(\.presentationMode) var presentationMode
    @State var selectedTab: ListTab
    @State private var searchText = ""
    @State private var selectedCharacter: Character? = nil
    @State private var selectedAnime: Anime? = nil
    @EnvironmentObject var characterManager: CharacterManager
    @EnvironmentObject var animeManager: AnimeManager

    let characters: [Character]
    let animes: [Anime]
    let birthdays: [Character]

    var headerTitle: String {
        switch selectedTab {
        case .chara: return NSLocalizedString("character_list", comment: "Character List")
        case .anime: return NSLocalizedString("anime_list", comment: "Anime List")
        case .birthday: return NSLocalizedString("birthday_list", comment: "Birthday List")
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            headerView
            searchBarView
            tabBarView
            contentView
        }
        .onAppear {
        }
        .fullScreenCover(item: $selectedCharacter) { character in
            CharacterDetailView(character: Binding(
                get: { character },
                set: { _ in }
            ), characters: .constant(characterManager.characters))
            .environmentObject(characterManager)
        }
        .fullScreenCover(item: $selectedAnime) { anime in
            AnimeDetailView(anime: Binding(
                get: { anime },
                set: { _ in }
            ), animes: .constant(animeManager.animes))
            .environmentObject(animeManager)
        }
    }
    
    private var headerView: some View {
        ZStack {
            HStack {
                Button(action: { presentationMode.wrappedValue.dismiss() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.black)
                }
                Spacer()
            }
            
            Text(headerTitle)
                .font(.system(size: 20, weight: .bold))
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 16)
        .padding(.top, 19)
        .padding(.bottom, 8)
        .offset(y: -10)
    }
    
    private var searchBarView: some View {
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
    }
    
    private var tabBarView: some View {
        HStack(spacing: 0) {
            tabButton(title: "Characters", tab: .chara)
            tabButton(title: "Animes", tab: .anime)
            tabButton(title: "Birthdays", tab: .birthday)
        }
        .background(Color.white)
        .offset(y: -5)
    }
    
    @ViewBuilder
    private var contentView: some View {
        if selectedTab == .chara {
            characterListView
        } else if selectedTab == .anime {
            animeListView
        } else {
            birthdayListView
        }
    }
    
    private var characterListView: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(filteredCharacters.enumerated()), id: \.offset) { index, character in
                    characterRow(character: character)
                }
            }
        }
    }
    
    private func characterRow(character: Character) -> some View {
        Button(action: { selectedCharacter = character }) {
            HStack(spacing: 16) {
                characterImage(character: character)
                Text(character.name)
                    .font(.system(size: 18, weight: .regular))
                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 16)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func characterImage(character: Character) -> some View {
        Group {
            if let imageIdentifier = character.imageIdentifier, let image = loadImageFromPath(imageIdentifier) {
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
        }
    }
    
    private var animeListView: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(filteredAnimes.enumerated()), id: \.offset) { index, anime in
                    animeRow(anime: anime)
                }
            }
        }
    }
    
    private func animeRow(anime: Anime) -> some View {
        Button(action: { selectedAnime = anime }) {
            HStack(spacing: 16) {
                animeImage(anime: anime)
                Text(anime.title)
                    .font(.system(size: 18, weight: .regular))
                Spacer()
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 16)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func animeImage(anime: Anime) -> some View {
        Group {
            if let imageIdentifier = anime.imageIdentifier, let image = loadImageFromPath(imageIdentifier) {
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
        }
    }
    
    private var birthdayListView: some View {
        ScrollView {
            VStack(spacing: 0) {
                ForEach(Array(filteredBirthdays.enumerated()), id: \.offset) { index, character in
                    birthdayRow(character: character)
                }
            }
        }
    }
    
    private func birthdayRow(character: Character) -> some View {
        HStack(spacing: 16) {
            characterImage(character: character)
            VStack(alignment: .leading, spacing: 2) {
                Text(character.name)
                    .font(.system(size: 18, weight: .regular))
                Text("\(NSLocalizedString("birthday", comment: "Birthday")): \(DateFormatter.monthDayLocalized.string(from: character.birthday))")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }
            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 16)
    }

    // タブボタンのカスタムView
    @ViewBuilder
    private func tabButton(title: String, tab: ListTab) -> some View {
        Button(action: { 
            selectedTab = tab 
        }) {
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
        let charactersWithNames = characterManager.characters.filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if searchText.isEmpty { return charactersWithNames }
        return charactersWithNames.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    private var filteredAnimes: [Anime] {
        let animesWithTitles = animeManager.animes.filter { !$0.title.isEmpty }
        if searchText.isEmpty { return animesWithTitles }
        return animesWithTitles.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
    private var filteredBirthdays: [Character] {
        if searchText.isEmpty { return birthdays }
        return birthdays.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
} 