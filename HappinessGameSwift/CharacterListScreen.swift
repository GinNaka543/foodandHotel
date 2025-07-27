import SwiftUI

struct CharacterListScreen: View {
    let characters: [Character]
    let onClose: () -> Void
    @State private var searchText = ""
    
    var filteredCharacters: [Character] {
        if searchText.isEmpty { return characters }
        return characters.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: 0) {
                // ヘッダー
                HStack {
                    Button(action: { onClose() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(.black)
                    }
                    Spacer()
                    Text(NSLocalizedString("character_list", comment: "Character List"))
                        .font(.system(size: 20, weight: .bold))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                    Spacer()
                    Color.clear.frame(width: 32)
                }
                .padding(.horizontal, 16)
                .padding(.top, 24)
                .padding(.bottom, 0)
                // サーチバー
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search", text: $searchText)
                        .font(.system(size: 16))
                }
                .padding(.vertical, 4)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                // キャラクター数
                HStack {
                    Text("キャラクターズ \(characters.count)")
                        .font(.system(size: 16, weight: .semibold))
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                // リスト
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(filteredCharacters, id: \.id) { character in
                            HStack(spacing: 12) {
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
                                    .font(.system(size: 17, weight: .semibold))
                                Spacer()
                            }
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                        }
                    }
                }
                Spacer(minLength: 0)
            }
            // 下部ナビゲーションバー
            VStack(spacing: 0) {
                Divider()
                HStack(spacing: 0) {
                    NavigationBarItem(icon: "house.fill", title: "Home", isSelected: false, onTap: { onClose() })
                    NavigationBarItem(icon: "person.2", title: "Chara", isSelected: true, onTap: { })
                    NavigationBarItem(icon: "tv", title: "Anime", isSelected: false, onTap: { })
                    NavigationBarItem(icon: "map", title: "Visit", isSelected: false, onTap: { })
                    NavigationBarItem(icon: "creditcard", title: "Card", isSelected: false, onTap: { })
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
    }
} 