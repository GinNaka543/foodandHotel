import SwiftUI

struct AnimeListScreen: View {
    let animes: [Anime]
    let onClose: () -> Void
    @State private var searchText = ""
    
    var filteredAnimes: [Anime] {
        if searchText.isEmpty { return animes }
        return animes.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }
    
    var body: some View {
        ZStack {
            // ヘッダー
            HStack {
                Button(action: { onClose() }) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.black)
                }
                Spacer()
                Text("アニメリスト")
                    .font(.system(size: 20, weight: .bold))
                    .frame(maxWidth: .infinity)
                    .multilineTextAlignment(.center)
                Spacer()
                Color.clear.frame(width: 32)
            }
            .padding(.horizontal, 16)
            .padding(.top, 24)
            .offset(y: -350)
            // サーチバー
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search", text: $searchText)
                    .font(.system(size: 16))
                    .padding(.vertical, 9)
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: UIScreen.main.bounds.width - 50)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            .offset(y: -360)
            // アニメリスト
            VStack(alignment: .leading, spacing: 24) {
                ForEach(filteredAnimes, id: \.id) { anime in
                    HStack(spacing: 16) {
                        Circle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 48, height: 48)
                            .overlay(
                                Image(systemName: "tv")
                                    .font(.system(size: 24))
                                    .foregroundColor(.gray)
                            )
                        Text(anime.title)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.black)
                    }
                }
            }
            .offset(x: -20, y: -265)
        }
        .background(Color.white)
    }
} 